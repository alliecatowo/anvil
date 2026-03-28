import Foundation
import AnvilDomain

/// Docker Engine API adapter implementing ContainerPort.
/// Communicates with the Docker daemon via Unix socket (/var/run/docker.sock)
/// using URLSession with a custom stream-socket URL protocol.
public final class DockerAdapter: ContainerPort, Sendable {
    public let providerId: String = "docker-local"
    public let providerName: String = "Docker"

    private let socketPath: String
    private let apiVersion: String

    public init(socketPath: String = "/var/run/docker.sock", apiVersion: String = "v1.43") {
        self.socketPath = socketPath
        self.apiVersion = apiVersion
    }

    // MARK: - AnvilProviderDefinition

    public func validateConnection() async throws -> Bool {
        // Ping the Docker daemon
        do {
            let _: DockerPingResponse = try await get("/_ping", decodable: false)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Containers

    public func containers() async throws -> [Container] {
        let response: [DockerContainerListEntry] = try await get("/\(apiVersion)/containers/json?all=true")
        return response.map { $0.toDomain() }
    }

    public func container(containerId: String) async throws -> Container {
        let response: DockerContainerInspect = try await get("/\(apiVersion)/containers/\(containerId)/json")
        return response.toDomain()
    }

    public func startContainer(containerId: String) async throws {
        try await post("/\(apiVersion)/containers/\(containerId)/start")
    }

    public func stopContainer(containerId: String) async throws {
        try await post("/\(apiVersion)/containers/\(containerId)/stop")
    }

    public func removeContainer(containerId: String, force: Bool) async throws {
        let forceParam = force ? "?force=true" : ""
        try await delete("/\(apiVersion)/containers/\(containerId)\(forceParam)")
    }

    public func containerLogs(containerId: String, tail: Int) async throws -> String {
        let data = try await getRaw("/\(apiVersion)/containers/\(containerId)/logs?stdout=true&stderr=true&tail=\(tail)")
        // Docker log stream has 8-byte header per frame: [stream_type(1), padding(3), size(4)]
        return stripDockerLogHeaders(data)
    }

    // MARK: - Images

    public func images() async throws -> [ContainerImage] {
        let response: [DockerImageListEntry] = try await get("/\(apiVersion)/images/json")
        return response.map { $0.toDomain() }
    }

    public func pullImage(name: String, tag: String) async throws -> ContainerImage {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        try await post("/\(apiVersion)/images/create?fromImage=\(encodedName)&tag=\(tag)")
        // After pull, fetch image details
        let allImages: [DockerImageListEntry] = try await get("/\(apiVersion)/images/json")
        let fullRef = "\(name):\(tag)"
        guard let pulled = allImages.first(where: { entry in
            entry.repoTags?.contains(fullRef) == true
        }) else {
            throw DockerAdapterError.imageNotFound(fullRef)
        }
        return pulled.toDomain()
    }

    // MARK: - Compose (via docker compose CLI)

    public func composeUp(stackPath: String) async throws -> ComposeStack {
        let output = try await runComposeCLI(args: ["-f", stackPath, "up", "-d"])
        // Return the stack state after bringing it up
        return try await composeStackFromPath(stackPath, cliHint: output)
    }

    public func composeDown(stackPath: String) async throws {
        _ = try await runComposeCLI(args: ["-f", stackPath, "down"])
    }

    public func composeStacks() async throws -> [ComposeStack] {
        // docker compose ls --format json
        let output = try await runComposeCLI(args: ["ls", "--format", "json"])
        guard let data = output.data(using: .utf8) else { return [] }
        let entries = (try? JSONDecoder().decode([DockerComposeLsEntry].self, from: data)) ?? []
        return entries.map { entry in
            ComposeStack(
                name: entry.Name,
                configPath: entry.ConfigFiles,
                services: [],
                status: entry.Status.contains("running") ? .running : .stopped
            )
        }
    }

    // MARK: - HTTP via Unix Socket

    private func get<T: Decodable>(_ path: String, decodable: Bool = true) async throws -> T {
        let data = try await performRequest(method: "GET", path: path)
        if !decodable, T.self == DockerPingResponse.self {
            return DockerPingResponse() as! T
        }
        return try JSONDecoder.docker.decode(T.self, from: data)
    }

    private func getRaw(_ path: String) async throws -> Data {
        try await performRequest(method: "GET", path: path)
    }

    @discardableResult
    private func post(_ path: String, body: Data? = nil) async throws -> Data {
        try await performRequest(method: "POST", path: path, body: body)
    }

    @discardableResult
    private func delete(_ path: String) async throws -> Data {
        try await performRequest(method: "DELETE", path: path)
    }

    private func performRequest(method: String, path: String, body: Data? = nil) async throws -> Data {
        // Build HTTP request bytes manually and send over Unix socket
        let host = "localhost"
        var requestLine = "\(method) \(path) HTTP/1.1\r\nHost: \(host)\r\nAccept: application/json\r\n"
        if let body {
            requestLine += "Content-Type: application/json\r\nContent-Length: \(body.count)\r\n"
        }
        requestLine += "Connection: close\r\n\r\n"

        var requestData = Data(requestLine.utf8)
        if let body { requestData.append(body) }

        return try await withCheckedThrowingContinuation { continuation in
            let thread = Thread {
                do {
                    let data = try self.sendOverSocket(requestData: requestData)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            thread.qualityOfService = .userInitiated
            thread.start()
        }
    }

    private func sendOverSocket(requestData: Data) throws -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw DockerAdapterError.socketError("Failed to create socket: \(String(cString: strerror(errno)))")
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw DockerAdapterError.socketError("Socket path too long")
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            throw DockerAdapterError.socketError("Failed to connect to \(socketPath): \(String(cString: strerror(errno)))")
        }

        // Send request
        try requestData.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress else { return }
            var sent = 0
            while sent < requestData.count {
                let n = Darwin.send(fd, ptr.advanced(by: sent), requestData.count - sent, 0)
                guard n > 0 else {
                    throw DockerAdapterError.socketError("Send failed: \(String(cString: strerror(errno)))")
                }
                sent += n
            }
        }

        // Read response
        var responseData = Data()
        let bufSize = 65536
        var buf = [UInt8](repeating: 0, count: bufSize)
        while true {
            let n = Darwin.recv(fd, &buf, bufSize, 0)
            if n <= 0 { break }
            responseData.append(contentsOf: buf[0..<n])
        }

        // Parse HTTP response — find body after \r\n\r\n
        guard let headerEnd = responseData.range(of: Data("\r\n\r\n".utf8)) else {
            throw DockerAdapterError.invalidResponse("No HTTP header terminator found")
        }

        let headerData = responseData[responseData.startIndex..<headerEnd.lowerBound]
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw DockerAdapterError.invalidResponse("Cannot decode HTTP headers")
        }

        // Extract status code
        let lines = headerString.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else {
            throw DockerAdapterError.invalidResponse("No status line")
        }
        let parts = statusLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2, let statusCode = Int(parts[1]) else {
            throw DockerAdapterError.invalidResponse("Cannot parse status code from: \(statusLine)")
        }

        let bodyData = responseData[headerEnd.upperBound...]

        // Check for chunked transfer encoding
        let isChunked = headerString.lowercased().contains("transfer-encoding: chunked")
        let finalBody: Data
        if isChunked {
            finalBody = decodeChunked(Data(bodyData))
        } else {
            finalBody = Data(bodyData)
        }

        guard (200..<300).contains(statusCode) || statusCode == 304 else {
            let errorBody = String(data: finalBody, encoding: .utf8) ?? ""
            throw DockerAdapterError.httpError(statusCode, errorBody)
        }

        return finalBody
    }

    /// Decode HTTP chunked transfer encoding.
    private func decodeChunked(_ data: Data) -> Data {
        var result = Data()
        var offset = 0
        let bytes = [UInt8](data)

        while offset < bytes.count {
            // Find end of chunk size line (\r\n)
            guard let crlfIndex = findCRLF(in: bytes, from: offset) else { break }
            let sizeStr = String(bytes: bytes[offset..<crlfIndex], encoding: .ascii) ?? ""
            guard let chunkSize = Int(sizeStr.trimmingCharacters(in: .whitespaces), radix: 16), chunkSize > 0 else {
                break
            }
            let chunkStart = crlfIndex + 2
            let chunkEnd = chunkStart + chunkSize
            guard chunkEnd <= bytes.count else { break }
            result.append(contentsOf: bytes[chunkStart..<chunkEnd])
            offset = chunkEnd + 2 // skip trailing \r\n
        }
        return result
    }

    private func findCRLF(in bytes: [UInt8], from start: Int) -> Int? {
        var i = start
        while i < bytes.count - 1 {
            if bytes[i] == 0x0D && bytes[i + 1] == 0x0A { return i }
            i += 1
        }
        return nil
    }

    /// Strip Docker multiplexed log stream headers.
    /// Each frame: [stream_type:1][0:3][size:4 big-endian][payload:size]
    private func stripDockerLogHeaders(_ data: Data) -> String {
        let bytes = [UInt8](data)
        var result = Data()
        var offset = 0
        while offset + 8 <= bytes.count {
            let size = Int(bytes[offset + 4]) << 24
                | Int(bytes[offset + 5]) << 16
                | Int(bytes[offset + 6]) << 8
                | Int(bytes[offset + 7])
            let payloadStart = offset + 8
            let payloadEnd = min(payloadStart + size, bytes.count)
            if payloadStart <= payloadEnd {
                result.append(contentsOf: bytes[payloadStart..<payloadEnd])
            }
            offset = payloadEnd
        }
        // If parsing fails (non-multiplexed), return raw string
        if result.isEmpty {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return String(data: result, encoding: .utf8) ?? ""
    }

    // MARK: - Compose CLI Helper

    private func runComposeCLI(args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        process.arguments = ["compose"] + args

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errOutput = String(data: errData, encoding: .utf8) ?? ""
            throw DockerAdapterError.composeError(errOutput.isEmpty ? "Exit code \(process.terminationStatus)" : errOutput)
        }

        return output
    }

    private func composeStackFromPath(_ path: String, cliHint: String) async throws -> ComposeStack {
        let name = URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
        // Get containers for this compose project
        let allContainers: [DockerContainerListEntry] = try await get(
            "/\(apiVersion)/containers/json?all=true&filters={\"label\":[\"com.docker.compose.project=\(name)\"]}"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        )
        let services = allContainers.map { entry in
            ComposeService(
                name: entry.labels?["com.docker.compose.service"] ?? entry.primaryName,
                image: entry.Image,
                status: ContainerStatus(dockerState: entry.State),
                ports: entry.Ports?.compactMap { $0.toDomain() } ?? []
            )
        }
        let allRunning = services.allSatisfy { $0.status == .running }
        let anyRunning = services.contains { $0.status == .running }
        let stackStatus: ComposeStackStatus = allRunning ? .running : (anyRunning ? .partial : .stopped)

        return ComposeStack(name: name, configPath: path, services: services, status: stackStatus)
    }
}

// MARK: - Docker API Response Types

private struct DockerPingResponse: Decodable {}

private struct DockerContainerListEntry: Decodable {
    let Id: String
    let Names: [String]?
    let Image: String
    let State: String
    let Created: TimeInterval
    let Ports: [DockerPortEntry]?
    let Labels: [String: String]?

    // Docker prepends "/" to container names
    var primaryName: String {
        let raw = Names?.first ?? Id.prefix(12).description
        return raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
    }

    var labels: [String: String]? { Labels }

    func toDomain() -> Container {
        Container(
            id: Id,
            name: primaryName,
            image: Image,
            status: ContainerStatus(dockerState: State),
            ports: Ports?.compactMap { $0.toDomain() } ?? [],
            createdAt: Date(timeIntervalSince1970: Created)
        )
    }
}

private struct DockerPortEntry: Decodable {
    let IP: String?
    let PrivatePort: Int
    let PublicPort: Int?
    let portType: String?

    enum CodingKeys: String, CodingKey {
        case IP, PrivatePort, PublicPort
        case portType = "Type"
    }

    func toDomain() -> PortMapping? {
        guard let pub = PublicPort else { return nil }
        return PortMapping(hostPort: pub, containerPort: PrivatePort, proto: portType ?? "tcp")
    }
}

private struct DockerContainerInspect: Decodable {
    let Id: String
    let Name: String
    let Created: String
    let State: DockerContainerState
    let Config: DockerContainerConfig?
    let NetworkSettings: DockerNetworkSettings?

    func toDomain() -> Container {
        let cleanName = Name.hasPrefix("/") ? String(Name.dropFirst()) : Name
        let imageName = Config?.Image ?? ""
        let ports = NetworkSettings?.Ports?.flatMap { (key, bindings) -> [PortMapping] in
            guard let bindings else { return [] }
            let parts = key.split(separator: "/")
            let containerPort = Int(parts.first ?? "0") ?? 0
            let proto = parts.count > 1 ? String(parts[1]) : "tcp"
            return bindings.compactMap { binding in
                guard let hostPort = Int(binding.HostPort ?? "") else { return nil }
                return PortMapping(hostPort: hostPort, containerPort: containerPort, proto: proto)
            }
        } ?? []

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdDate = dateFormatter.date(from: Created) ?? .now

        return Container(
            id: Id,
            name: cleanName,
            image: imageName,
            status: ContainerStatus(dockerState: State.Status),
            ports: ports,
            createdAt: createdDate
        )
    }
}

private struct DockerContainerState: Decodable {
    let Status: String
    let Running: Bool?
}

private struct DockerContainerConfig: Decodable {
    let Image: String?
}

private struct DockerNetworkSettings: Decodable {
    let Ports: [String: [DockerHostBinding]?]?
}

private struct DockerHostBinding: Decodable {
    let HostIp: String?
    let HostPort: String?
}

private struct DockerImageListEntry: Decodable {
    let Id: String
    let RepoTags: [String]?
    let Size: Int64
    let Created: TimeInterval

    var repoTags: [String]? { RepoTags }

    func toDomain() -> ContainerImage {
        let firstTag = RepoTags?.first ?? ""
        let parts = firstTag.split(separator: ":", maxSplits: 1)
        let repo = parts.first.map(String.init) ?? Id.prefix(12).description
        let tag = parts.count > 1 ? String(parts[1]) : "latest"

        return ContainerImage(
            id: Id,
            repository: repo,
            tag: tag,
            sizeBytes: Size,
            createdAt: Date(timeIntervalSince1970: Created)
        )
    }
}

private struct DockerComposeLsEntry: Decodable {
    let Name: String
    let Status: String
    let ConfigFiles: String
}

// MARK: - ContainerStatus Extension

extension ContainerStatus {
    init(dockerState: String) {
        switch dockerState.lowercased() {
        case "running": self = .running
        case "paused": self = .paused
        case "restarting": self = .restarting
        case "exited", "removing": self = .exited
        case "dead": self = .dead
        default: self = .created
        }
    }
}

// MARK: - JSON Decoder

extension JSONDecoder {
    fileprivate static let docker: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}

// MARK: - Errors

public enum DockerAdapterError: LocalizedError {
    case socketError(String)
    case httpError(Int, String)
    case invalidResponse(String)
    case imageNotFound(String)
    case composeError(String)

    public var errorDescription: String? {
        switch self {
        case .socketError(let msg): return "Docker socket error: \(msg)"
        case .httpError(let code, let body): return "Docker API error (\(code)): \(body)"
        case .invalidResponse(let msg): return "Invalid Docker response: \(msg)"
        case .imageNotFound(let name): return "Image not found after pull: \(name)"
        case .composeError(let msg): return "Docker Compose error: \(msg)"
        }
    }
}
