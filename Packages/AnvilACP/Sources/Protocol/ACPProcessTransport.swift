import Foundation

/// Launches a provider process and communicates via JSON-RPC over stdin/stdout,
/// using the LSP-style Content-Length header framing.
///
/// This is the core transport for process-based ACP providers. The protocol is:
/// 1. Each message is preceded by `Content-Length: <N>\r\n\r\n`
/// 2. Followed by exactly N bytes of JSON-RPC message body
///
/// This matches the LSP wire format, making it familiar and well-tested.
public actor ACPProcessTransport {
    private let executablePath: String
    private let arguments: [String]
    private let environment: [String: String]?
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var isRunning = false

    /// The provider process exit code, available after the process terminates.
    public private(set) var exitCode: Int32?

    public init(executablePath: String, arguments: [String] = [], environment: [String: String]? = nil) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.environment = environment
    }

    /// Launch the provider process.
    public func start() async throws {
        guard !isRunning else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = arguments

        // Merge caller environment with process environment, caller wins on conflicts
        var env = ProcessInfo.processInfo.environment
        if let overrides = environment {
            for (key, value) in overrides {
                env[key] = value
            }
        }
        proc.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        proc.terminationHandler = { [weak self] process in
            Task { [weak self] in
                await self?.handleTermination(code: process.terminationStatus)
            }
        }

        try proc.run()

        self.process = proc
        self.stdinHandle = stdinPipe.fileHandleForWriting
        self.stdoutHandle = stdoutPipe.fileHandleForReading
        self.stderrHandle = stderrPipe.fileHandleForReading
        self.isRunning = true
    }

    /// Send a JSON-RPC message (raw Data) to the process stdin.
    public func send(_ data: Data) throws {
        guard let stdin = stdinHandle, isRunning else {
            throw ACPTransportError.notConnected
        }
        // Content-Length header, then blank line, then body -- same as LSP
        let header = "Content-Length: \(data.count)\r\n\r\n"
        stdin.write(Data(header.utf8))
        stdin.write(data)
    }

    /// Send a typed Codable message.
    public func send(_ message: ACPProtocolMessage) throws {
        let data = try JSONEncoder().encode(message)
        try send(data)
    }

    /// Returns an AsyncStream of raw JSON message Data read from the process stdout.
    /// Each yielded Data is one complete JSON-RPC message body.
    public func messages() -> AsyncStream<Data> {
        guard let stdout = stdoutHandle else {
            return AsyncStream { $0.finish() }
        }

        return AsyncStream { continuation in
            let handle = stdout
            let transport = self
            Task {
                while await transport.checkRunning() {
                    guard let headerLine = Self.readLine(from: handle) else {
                        break
                    }

                    // Expect "Content-Length: <N>"
                    guard headerLine.hasPrefix("Content-Length: ") else { continue }
                    let lengthStr = String(headerLine.dropFirst("Content-Length: ".count))
                    guard let length = Int(lengthStr), length > 0 else { continue }

                    // Read until empty line (end of headers)
                    while let line = Self.readLine(from: handle), !line.isEmpty {
                        // Skip any additional headers
                    }

                    // Read exactly `length` bytes of body
                    let body = handle.readData(ofLength: length)
                    if body.count == length {
                        continuation.yield(body)
                    } else {
                        break  // Incomplete read means process likely exited
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Read stderr output (useful for debugging provider issues).
    public func readStderr() -> String? {
        guard let stderr = stderrHandle else { return nil }
        let data = stderr.availableData
        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Gracefully stop the provider process.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        stdinHandle?.closeFile()
        process?.terminate()
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil
    }

    /// Check if the process is still alive.
    public var running: Bool { isRunning }

    // MARK: - Private

    func checkRunning() -> Bool {
        isRunning
    }

    private func handleTermination(code: Int32) {
        exitCode = code
        isRunning = false
    }

    /// Read a single line (terminated by \n) from a FileHandle.
    /// Returns nil if EOF is reached.
    private static func readLine(from handle: FileHandle) -> String? {
        var lineData = Data()
        while true {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty { return nil }  // EOF
            if byte[0] == 0x0A {  // newline
                return String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .init(charactersIn: "\r"))
            }
            lineData.append(byte)
        }
    }
}

// MARK: - Transport Errors

public enum ACPTransportError: Error, Sendable {
    case notConnected
    case processExited(code: Int32)
    case invalidMessage(String)
    case encodingError(String)
    case timeout
}
