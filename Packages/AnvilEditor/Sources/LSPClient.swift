import Foundation

// MARK: - JSON-RPC Transport

/// A JSON-RPC 2.0 client that communicates with sourcekit-lsp over stdin/stdout.
public final class LSPClient: Sendable {

    private let transport: LSPTransport

    public init() {
        self.transport = LSPTransport()
    }

    // MARK: - Lifecycle

    /// Launch sourcekit-lsp and send the initialize + initialized handshake.
    public func initialize(workspacePath: String) async throws {
        try await transport.launch()

        let initParams: [String: Any] = [
            "processId": ProcessInfo.processInfo.processIdentifier,
            "rootUri": "file://\(workspacePath)",
            "capabilities": [
                "textDocument": [
                    "completion": [
                        "completionItem": ["snippetSupport": false]
                    ],
                    "publishDiagnostics": [
                        "relatedInformation": true
                    ]
                ]
            ] as [String: Any]
        ]
        let paramsData = try JSONSerialization.data(withJSONObject: initParams)

        _ = try await transport.sendRequest(method: "initialize", paramsData: paramsData)

        let emptyData = Data("{}".utf8)
        try await transport.sendNotification(method: "initialized", paramsData: emptyData)
    }

    /// Shut down the LSP server gracefully.
    public func shutdown() async {
        _ = try? await transport.sendRequest(method: "shutdown", paramsData: nil)
        await transport.sendNotificationFireAndForget(method: "exit", paramsData: nil)
        await transport.terminate()
    }

    // MARK: - Text Synchronization

    /// Notify the server that a document was opened.
    public func didOpen(uri: String, languageId: String, text: String) async {
        let params: [String: Any] = [
            "textDocument": [
                "uri": uri,
                "languageId": languageId,
                "version": 1,
                "text": text
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: params) else { return }
        try? await transport.sendNotification(method: "textDocument/didOpen", paramsData: data)
    }

    /// Notify the server that a document changed (full-text sync).
    public func didChange(uri: String, text: String, version: Int = 2) async {
        let params: [String: Any] = [
            "textDocument": [
                "uri": uri,
                "version": version
            ] as [String: Any],
            "contentChanges": [
                ["text": text]
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: params) else { return }
        try? await transport.sendNotification(method: "textDocument/didChange", paramsData: data)
    }

    /// Notify the server that a document was closed.
    public func didClose(uri: String) async {
        let params: [String: Any] = [
            "textDocument": ["uri": uri]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: params) else { return }
        try? await transport.sendNotification(method: "textDocument/didClose", paramsData: data)
    }

    // MARK: - Completion

    /// Request completions at a given position.
    public func completion(uri: String, line: Int, character: Int) async -> [CompletionItem] {
        let params: [String: Any] = [
            "textDocument": ["uri": uri],
            "position": ["line": line, "character": character]
        ]
        guard let paramsData = try? JSONSerialization.data(withJSONObject: params) else { return [] }
        do {
            let data = try await transport.sendRequest(method: "textDocument/completion", paramsData: paramsData)
            return Self.parseCompletionResponse(data)
        } catch {
            return []
        }
    }

    /// Request go-to-definition at a given position.
    public func definition(uri: String, line: Int, character: Int) async -> LSPLocation? {
        let params: [String: Any] = [
            "textDocument": ["uri": uri],
            "position": ["line": line, "character": character]
        ]
        guard let paramsData = try? JSONSerialization.data(withJSONObject: params) else { return nil }
        do {
            let data = try await transport.sendRequest(method: "textDocument/definition", paramsData: paramsData)
            return Self.parseDefinitionResponse(data)
        } catch {
            return nil
        }
    }

    // MARK: - Hover

    /// Request hover documentation at a given position.
    public func hover(uri: String, line: Int, character: Int) async -> LSPHoverResult? {
        let params: [String: Any] = [
            "textDocument": ["uri": uri],
            "position": ["line": line, "character": character]
        ]
        guard let paramsData = try? JSONSerialization.data(withJSONObject: params) else { return nil }
        do {
            let data = try await transport.sendRequest(method: "textDocument/hover", paramsData: paramsData)
            return Self.parseHoverResponse(data)
        } catch {
            return nil
        }
    }

    // MARK: - Diagnostics Stream

    /// Returns an `AsyncStream` of diagnostic batches published by the server.
    public func diagnosticsStream() -> AsyncStream<[LSPDiagnostic]> {
        AsyncStream { continuation in
            Task {
                await transport.setDiagnosticsHandler { diagnostics in
                    continuation.yield(diagnostics)
                }
                continuation.onTermination = { @Sendable _ in
                    Task {
                        await self.transport.setDiagnosticsHandler(nil)
                    }
                }
            }
        }
    }

    // MARK: - Parsing Helpers

    private static func parseCompletionResponse(_ data: Data) -> [CompletionItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }

        let items: [[String: Any]]
        if let dict = json as? [String: Any], let list = dict["items"] as? [[String: Any]] {
            items = list
        } else if let array = json as? [[String: Any]] {
            items = array
        } else {
            return []
        }

        return items.compactMap { item -> CompletionItem? in
            guard let label = item["label"] as? String else { return nil }
            let kindRaw = item["kind"] as? Int ?? 1
            let kind = CompletionItem.CompletionKind(rawValue: kindRaw) ?? .text
            let detail = item["detail"] as? String
            let insertText = item["insertText"] as? String
            return CompletionItem(label: label, kind: kind, detail: detail, insertText: insertText)
        }
    }

    private static func parseDefinitionResponse(_ data: Data) -> LSPLocation? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        if let loc = json as? [String: Any] {
            return parseLocation(loc)
        }
        if let array = json as? [[String: Any]], let first = array.first {
            if first["targetUri"] != nil {
                return parseLocationLink(first)
            }
            return parseLocation(first)
        }
        return nil
    }

    private static func parseLocation(_ dict: [String: Any]) -> LSPLocation? {
        guard let uri = dict["uri"] as? String,
              let range = dict["range"] as? [String: Any],
              let start = range["start"] as? [String: Any],
              let line = start["line"] as? Int,
              let character = start["character"] as? Int else { return nil }
        return LSPLocation(uri: uri, line: line, character: character)
    }

    private static func parseLocationLink(_ dict: [String: Any]) -> LSPLocation? {
        guard let uri = dict["targetUri"] as? String,
              let range = dict["targetSelectionRange"] as? [String: Any] ?? dict["targetRange"] as? [String: Any],
              let start = range["start"] as? [String: Any],
              let line = start["line"] as? Int,
              let character = start["character"] as? Int else { return nil }
        return LSPLocation(uri: uri, line: line, character: character)
    }

    private static func parseHoverResponse(_ data: Data) -> LSPHoverResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["contents"] else { return nil }

        // contents can be: MarkedString (string), MarkupContent ({kind, value}), or array
        if let markup = contents as? [String: Any],
           let value = markup["value"] as? String {
            let kind = markup["kind"] as? String ?? "plaintext"
            return LSPHoverResult(contents: value, isMarkdown: kind == "markdown")
        }

        if let str = contents as? String {
            return LSPHoverResult(contents: str, isMarkdown: false)
        }

        // Array of MarkedString
        if let arr = contents as? [Any] {
            let parts: [String] = arr.compactMap { item in
                if let s = item as? String { return s }
                if let dict = item as? [String: Any], let v = dict["value"] as? String { return v }
                return nil
            }
            guard !parts.isEmpty else { return nil }
            return LSPHoverResult(contents: parts.joined(separator: "\n\n"), isMarkdown: true)
        }

        return nil
    }
}

// MARK: - LSP Transport Actor

/// Actor that owns the Process and manages JSON-RPC request/response matching.
/// All data crossing the actor boundary is `Data` (Sendable).
actor LSPTransport {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var nextRequestId: Int = 1
    private var pendingRequests: [Int: CheckedContinuation<Data, Error>] = [:]
    private var readTask: Task<Void, Never>?
    private var diagnosticsHandler: (@Sendable ([LSPDiagnostic]) -> Void)?

    enum TransportError: Error, Sendable {
        case notRunning
        case processLaunchFailed(String)
        case invalidResponse
        case serverError(code: Int, message: String)
    }

    // MARK: - Launch

    func launch() throws {
        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        proc.arguments = ["sourcekit-lsp"]
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        do {
            try proc.run()
        } catch {
            throw TransportError.processLaunchFailed(error.localizedDescription)
        }

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout

        let handle = stdout.fileHandleForReading
        readTask = Task.detached { [weak self] in
            await self?.readLoop(handle: handle)
        }
    }

    func terminate() {
        readTask?.cancel()
        readTask = nil
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: TransportError.notRunning)
        }
        pendingRequests.removeAll()
    }

    // MARK: - Diagnostics Handler

    func setDiagnosticsHandler(_ handler: (@Sendable ([LSPDiagnostic]) -> Void)?) {
        self.diagnosticsHandler = handler
    }

    // MARK: - Send Request

    /// Send a JSON-RPC request. `paramsData` is pre-serialized JSON for the "params" field.
    /// Returns the raw JSON Data of the "result" field.
    @discardableResult
    func sendRequest(method: String, paramsData: Data?) async throws -> Data {
        guard let pipe = stdinPipe, process?.isRunning == true else {
            throw TransportError.notRunning
        }

        let requestId = nextRequestId
        nextRequestId += 1

        let messageData = buildRequestMessage(id: requestId, method: method, paramsData: paramsData)

        let header = "Content-Length: \(messageData.count)\r\n\r\n"
        let headerData = Data(header.utf8)

        let fileHandle = pipe.fileHandleForWriting
        try fileHandle.write(contentsOf: headerData)
        try fileHandle.write(contentsOf: messageData)

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation
        }
    }

    // MARK: - Send Notification

    func sendNotification(method: String, paramsData: Data?) throws {
        guard let pipe = stdinPipe, process?.isRunning == true else {
            throw TransportError.notRunning
        }

        let messageData = buildNotificationMessage(method: method, paramsData: paramsData)

        let header = "Content-Length: \(messageData.count)\r\n\r\n"
        let headerData = Data(header.utf8)

        let fileHandle = pipe.fileHandleForWriting
        try fileHandle.write(contentsOf: headerData)
        try fileHandle.write(contentsOf: messageData)
    }

    func sendNotificationFireAndForget(method: String, paramsData: Data?) {
        try? sendNotification(method: method, paramsData: paramsData)
    }

    // MARK: - Message Building

    /// Build a JSON-RPC request message by embedding pre-serialized params data.
    private nonisolated func buildRequestMessage(id: Int, method: String, paramsData: Data?) -> Data {
        var json = "{\"jsonrpc\":\"2.0\",\"id\":\(id),\"method\":\"\(method)\""
        if let paramsData, let paramsString = String(data: paramsData, encoding: .utf8) {
            json += ",\"params\":\(paramsString)"
        }
        json += "}"
        return Data(json.utf8)
    }

    /// Build a JSON-RPC notification message by embedding pre-serialized params data.
    private nonisolated func buildNotificationMessage(method: String, paramsData: Data?) -> Data {
        var json = "{\"jsonrpc\":\"2.0\",\"method\":\"\(method)\""
        if let paramsData, let paramsString = String(data: paramsData, encoding: .utf8) {
            json += ",\"params\":\(paramsString)"
        }
        json += "}"
        return Data(json.utf8)
    }

    // MARK: - Read Loop

    private func readLoop(handle: FileHandle) async {
        var buffer = Data()

        while !Task.isCancelled {
            let chunk: Data
            do {
                chunk = try await readAvailable(from: handle)
            } catch {
                break
            }

            guard !chunk.isEmpty else { break }
            buffer.append(chunk)

            while let (bodyData, resultData, consumedBytes) = extractMessage(from: buffer) {
                buffer = Data(buffer.dropFirst(consumedBytes))
                await handleMessage(bodyData: bodyData, resultData: resultData)
            }
        }
    }

    private nonisolated func readAvailable(from handle: FileHandle) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let data = handle.availableData
            continuation.resume(returning: data)
        }
    }

    /// Extract a single LSP message from the buffer.
    /// Returns (full body data, result field as Data or nil, bytes consumed).
    private nonisolated func extractMessage(from buffer: Data) -> (Data, Data?, Int)? {
        guard let headerEnd = findHeaderEnd(in: buffer) else { return nil }

        let headerData = buffer[buffer.startIndex..<headerEnd]
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }

        var contentLength: Int?
        for line in headerString.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                contentLength = Int(value)
            }
        }

        guard let length = contentLength else { return nil }

        let bodyStart = headerEnd + 2
        let bodyEnd = bodyStart + length

        guard buffer.count >= bodyEnd else { return nil }

        let bodyData = Data(buffer[bodyStart..<bodyEnd])

        // Extract "result" as separate Data for Sendable transport across actor boundary
        var resultData: Data?
        if let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
           let resultValue = json["result"] {
            if JSONSerialization.isValidJSONObject(resultValue) {
                resultData = try? JSONSerialization.data(withJSONObject: resultValue)
            } else {
                resultData = Data("null".utf8)
            }
        }

        return (bodyData, resultData, bodyEnd - buffer.startIndex)
    }

    /// Find the end of HTTP headers (double CRLF).
    private nonisolated func findHeaderEnd(in data: Data) -> Int? {
        let separator: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A]
        let bytes = Array(data)
        guard bytes.count >= 4 else { return nil }
        for i in 0...(bytes.count - 4) {
            if bytes[i] == separator[0] &&
               bytes[i+1] == separator[1] &&
               bytes[i+2] == separator[2] &&
               bytes[i+3] == separator[3] {
                return data.startIndex + i + 2
            }
        }
        return nil
    }

    // MARK: - Message Dispatch

    private func handleMessage(bodyData: Data, resultData: Data?) async {
        guard let dict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else { return }

        // Response to a request
        if let id = dict["id"] as? Int, let continuation = pendingRequests.removeValue(forKey: id) {
            if let error = dict["error"] as? [String: Any] {
                let code = error["code"] as? Int ?? -1
                let message = error["message"] as? String ?? "Unknown error"
                continuation.resume(throwing: TransportError.serverError(code: code, message: message))
            } else if let data = resultData {
                continuation.resume(returning: data)
            } else {
                continuation.resume(returning: Data("null".utf8))
            }
            return
        }

        // Server notification
        if let method = dict["method"] as? String {
            switch method {
            case "textDocument/publishDiagnostics":
                if let params = dict["params"] as? [String: Any] {
                    handlePublishDiagnostics(params)
                }
            default:
                break
            }
        }
    }

    private func handlePublishDiagnostics(_ params: [String: Any]) {
        guard let uri = params["uri"] as? String,
              let rawDiags = params["diagnostics"] as? [[String: Any]] else { return }

        let diagnostics: [LSPDiagnostic] = rawDiags.compactMap { diag in
            guard let range = diag["range"] as? [String: Any],
                  let start = range["start"] as? [String: Any],
                  let end = range["end"] as? [String: Any],
                  let startLine = start["line"] as? Int,
                  let startChar = start["character"] as? Int,
                  let endLine = end["line"] as? Int,
                  let endChar = end["character"] as? Int,
                  let message = diag["message"] as? String else { return nil }

            let severityRaw = diag["severity"] as? Int ?? 1
            let severity = LSPDiagnostic.DiagnosticSeverity(rawValue: severityRaw) ?? .error
            let source = diag["source"] as? String

            return LSPDiagnostic(
                uri: uri,
                line: startLine,
                character: startChar,
                endLine: endLine,
                endCharacter: endChar,
                severity: severity,
                message: message,
                source: source
            )
        }

        diagnosticsHandler?(diagnostics)
    }
}
