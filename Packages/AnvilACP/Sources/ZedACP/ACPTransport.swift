import Foundation

/// Newline-delimited JSON transport over stdin/stdout of a subprocess.
///
/// Unlike the existing `ACPProcessTransport` which uses LSP Content-Length framing,
/// Zed ACP uses newline-delimited JSON: each message is a single JSON line terminated by `\n`.
public actor ZedACPTransport {
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var isRunning = false

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [] // compact, no pretty-print — single line
        return e
    }()

    public init() {}

    /// Launch the agent subprocess with the given command and arguments.
    public func launch(command: String, args: [String], env: [String: String]?) throws {
        guard !isRunning else { return }

        let proc = Process()

        // Use /usr/bin/env to resolve the command from PATH
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [command] + args

        var environment = ProcessInfo.processInfo.environment
        if let overrides = env {
            for (key, value) in overrides {
                environment[key] = value
            }
        }
        proc.environment = environment

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        proc.terminationHandler = { [weak self] _ in
            Task { [weak self] in
                await self?.handleTermination()
            }
        }

        try proc.run()

        self.process = proc
        self.stdinHandle = stdinPipe.fileHandleForWriting
        self.stdoutHandle = stdoutPipe.fileHandleForReading
        self.stderrHandle = stderrPipe.fileHandleForReading
        self.isRunning = true
    }

    /// Send a JSON-RPC message as a single newline-delimited JSON line.
    public func send(_ message: ACPJsonRpcMessage) throws {
        guard let stdin = stdinHandle, isRunning else {
            throw ACPTransportError.notConnected
        }
        let data = try encoder.encode(message)
        var lineData = data
        lineData.append(0x0A) // newline
        stdin.write(lineData)
    }

    /// Returns an AsyncStream of JSON-RPC messages read from stdout.
    /// Each line is parsed as a complete JSON-RPC message.
    public func messages() -> AsyncStream<ACPJsonRpcMessage> {
        guard let stdout = stdoutHandle else {
            return AsyncStream { $0.finish() }
        }

        let handle = stdout
        let transport = self
        return AsyncStream { continuation in
            Task.detached {
                let decoder = JSONDecoder()
                var buffer = Data()

                while true {
                    // Check if transport is still running
                    let running = await transport.checkRunning()
                    guard running else { break }

                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        // EOF — process exited
                        break
                    }
                    buffer.append(chunk)

                    // Process all complete lines in the buffer
                    while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                        let lineData = buffer[buffer.startIndex..<newlineIndex]
                        buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                        guard !lineData.isEmpty else { continue }
                        guard let message = try? decoder.decode(ACPJsonRpcMessage.self, from: Data(lineData)) else {
                            continue
                        }
                        continuation.yield(message)
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Read any available stderr output for debugging.
    public func readStderr() -> String? {
        guard let stderr = stderrHandle else { return nil }
        let data = stderr.availableData
        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Stop the subprocess.
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

    public var running: Bool { isRunning }

    func checkRunning() -> Bool { isRunning }

    private func handleTermination() {
        isRunning = false
    }
}
