import Foundation

/// Zed ACP client that manages a bidirectional JSON-RPC connection with an ACP agent.
///
/// The agent process is spawned as a subprocess and communicates via newline-delimited
/// JSON-RPC on stdin/stdout. The agent can send requests BACK to the client
/// (permission requests, file reads/writes, terminal access), which this client
/// handles via callbacks.
public actor ZedACPClient {
    private let transport: ZedACPTransport
    private var pendingRequests: [ACPMessageId: CheckedContinuation<ACPJsonRpcMessage, Error>] = [:]
    private var nextId: Int = 0
    private var sessionId: String?
    private var dispatchTask: Task<Void, Never>?

    // MARK: - Terminal Sessions

    private let terminalSessionFactory: (any TerminalSessionFactory)?
    private var terminalSessions: [String: any TerminalSessionPort] = [:]
    private var terminalNextId: Int = 0

    // MARK: - Callbacks for bidirectional requests from agent

    /// Called when the agent requests permission to execute a tool.
    /// MUST respond or the agent will deadlock.
    public var onPermissionRequest: (@Sendable (ZedACPPermissionRequest) async -> ZedACPPermissionResponse)?

    /// Called when the agent requests to read a file through the client.
    public var onFileReadRequest: (@Sendable (String) async -> String?)?

    /// Called when the agent requests to write a file through the client.
    public var onFileWriteRequest: (@Sendable (String, String) async -> Bool)?

    /// Called for each streaming session update from the agent.
    public var onStreamUpdate: (@Sendable (ZedACPSessionUpdate) async -> Void)?

    public init(terminalSessionFactory: (any TerminalSessionFactory)? = nil) {
        self.transport = ZedACPTransport()
        self.terminalSessionFactory = terminalSessionFactory
    }

    // MARK: - Connection

    /// Connect to an ACP agent by launching its subprocess.
    public func connect(command: String, args: [String] = [], env: [String: String]? = nil) async throws {
        try await transport.launch(command: command, args: args, env: env)
        dispatchTask = Task {
            await self.dispatchLoop()
        }
    }

    /// Disconnect from the agent, cancelling any pending requests.
    public func disconnect() async {
        dispatchTask?.cancel()
        dispatchTask = nil
        // Fail all pending requests
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: ZedACPClientError.disconnected)
        }
        pendingRequests.removeAll()
        // Terminate all active terminal sessions
        for (_, session) in terminalSessions {
            session.terminate()
        }
        terminalSessions.removeAll()
        await transport.stop()
        sessionId = nil
    }

    // MARK: - ACP Methods (client -> agent)

    /// Perform the initialize handshake with the agent.
    public func initialize() async throws -> ZedACPInitializeResult {
        let params: ACPAnyCodable = .dictionary([
            "protocolVersion": .string("2025-01-01"),
            "clientInfo": .dictionary([
                "name": .string("Anvil"),
                "version": .string("0.1.0"),
            ]),
            "capabilities": .dictionary([
                "permissions": .bool(true),
                "fileSystem": .bool(true),
                "terminal": .bool(true),
            ]),
        ])

        let response = try await sendRequest(method: "initialize", params: params)

        if let error = response.error {
            throw ZedACPClientError.rpcError(code: error.code, message: error.message)
        }

        guard let resultValue = response.result else {
            return ZedACPInitializeResult()
        }

        // Parse the result
        let data = try JSONEncoder().encode(resultValue)
        let result = try JSONDecoder().decode(ZedACPInitializeResult.self, from: data)
        return result
    }

    /// Create a new agent session.
    public func newSession(cwd: String) async throws -> String {
        let params: ACPAnyCodable = .dictionary([
            "cwd": .string(cwd),
        ])

        let response = try await sendRequest(method: "session/new", params: params)

        if let error = response.error {
            throw ZedACPClientError.rpcError(code: error.code, message: error.message)
        }

        guard case .dictionary(let dict)? = response.result,
              case .string(let sid)? = dict["sessionId"] else {
            throw ZedACPClientError.unexpectedResponse("Missing sessionId in session/new result")
        }

        sessionId = sid
        return sid
    }

    /// Send a prompt to the agent. This call stays open while the agent streams back
    /// `session/update` notifications. It resolves when the agent finishes the turn.
    public func prompt(text: String, sessionId sid: String? = nil) async throws -> ZedACPPromptResult {
        let effectiveSessionId = sid ?? sessionId
        guard let effectiveSessionId else {
            throw ZedACPClientError.noSession
        }

        let params: ACPAnyCodable = .dictionary([
            "sessionId": .string(effectiveSessionId),
            "message": .dictionary([
                "role": .string("user"),
                "content": .string(text),
            ]),
        ])

        let response = try await sendRequest(method: "session/prompt", params: params)

        if let error = response.error {
            throw ZedACPClientError.rpcError(code: error.code, message: error.message)
        }

        // Parse stop reason from result
        let stopReason: String
        if case .dictionary(let dict)? = response.result,
           case .string(let reason)? = dict["stopReason"] {
            stopReason = reason
        } else {
            stopReason = "end_turn"
        }

        return ZedACPPromptResult(stopReason: stopReason)
    }

    /// Cancel the current prompt turn.
    public func cancel() async {
        guard let sid = sessionId else { return }
        let notification = ACPJsonRpcMessage.notification(
            method: "session/cancel",
            params: .dictionary(["sessionId": .string(sid)])
        )
        try? await transport.send(notification)
    }

    /// Get the current session ID.
    public func currentSessionId() -> String? {
        sessionId
    }

    // MARK: - Internal Request/Response

    private func sendRequest(method: String, params: ACPAnyCodable?) async throws -> ACPJsonRpcMessage {
        let id = ACPMessageId.int(nextId)
        nextId += 1

        let message = ACPJsonRpcMessage.request(id: id, method: method, params: params)
        try await transport.send(message)

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation
        }
    }

    // MARK: - Dispatch Loop

    private func dispatchLoop() async {
        for await message in await transport.messages() {
            if Task.isCancelled { break }

            if message.isRequest {
                // Inbound REQUEST from agent -- handle and respond
                await handleAgentRequest(message)
            } else if message.isResponse {
                // RESPONSE to one of our pending requests
                if let id = message.id, let continuation = pendingRequests.removeValue(forKey: id) {
                    continuation.resume(returning: message)
                }
            } else if message.isNotification {
                // NOTIFICATION from agent
                await handleNotification(message)
            }
        }

        // Stream ended -- agent process exited. Fail any pending requests.
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: ZedACPClientError.disconnected)
        }
        pendingRequests.removeAll()
    }

    // MARK: - Handle Agent Requests (bidirectional)

    private func handleAgentRequest(_ message: ACPJsonRpcMessage) async {
        guard let id = message.id, let method = message.method else { return }

        switch method {
        case "session/request_permission":
            await handlePermissionRequest(id: id, params: message.params)

        case "fs/read_text_file":
            await handleFileRead(id: id, params: message.params)

        case "fs/write_text_file":
            await handleFileWrite(id: id, params: message.params)

        case "terminal/create":
            await handleTerminalCreate(id: id, params: message.params)

        case "terminal/output":
            await handleTerminalOutput(id: id, params: message.params)

        case "terminal/kill":
            await handleTerminalKill(id: id, params: message.params)

        default:
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .methodNotFound
            )
            try? await transport.send(errorResp)
        }
    }

    private func handlePermissionRequest(id: ACPMessageId, params: ACPAnyCodable?) async {
        guard let handler = onPermissionRequest else {
            // Auto-approve if no handler is set (avoid deadlock)
            let response = ACPJsonRpcMessage.response(
                id: id,
                result: .dictionary(["approved": .bool(true)])
            )
            try? await transport.send(response)
            return
        }

        // Parse permission request
        let toolCallId: String
        let toolName: String
        var options: [ZedACPPermissionOption] = []

        if case .dictionary(let dict)? = params {
            toolCallId = dict["toolCallId"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
            toolName = dict["toolName"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""

            if case .array(let opts)? = dict["options"] {
                for opt in opts {
                    if case .dictionary(let o) = opt {
                        let oid = o["optionId"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
                        let name = o["name"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
                        let kind = o["kind"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
                        options.append(ZedACPPermissionOption(optionId: oid, name: name, kind: kind))
                    }
                }
            }
        } else {
            toolCallId = ""
            toolName = ""
        }

        let request = ZedACPPermissionRequest(toolCallId: toolCallId, toolName: toolName, options: options)
        let permResponse = await handler(request)

        let response = ACPJsonRpcMessage.response(
            id: id,
            result: .dictionary(["optionId": .string(permResponse.optionId)])
        )
        try? await transport.send(response)
    }

    private func handleFileRead(id: ACPMessageId, params: ACPAnyCodable?) async {
        guard case .dictionary(let dict)? = params,
              case .string(let path)? = dict["path"] else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32602, message: "Missing path parameter")
            )
            try? await transport.send(errorResp)
            return
        }

        let content: String?
        if let handler = onFileReadRequest {
            content = await handler(path)
        } else {
            // Default: read from disk
            content = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        }

        if let content {
            let response = ACPJsonRpcMessage.response(
                id: id,
                result: .dictionary(["content": .string(content)])
            )
            try? await transport.send(response)
        } else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -33010, message: "File not found or unreadable: \(path)")
            )
            try? await transport.send(errorResp)
        }
    }

    private func handleFileWrite(id: ACPMessageId, params: ACPAnyCodable?) async {
        guard case .dictionary(let dict)? = params,
              case .string(let path)? = dict["path"],
              case .string(let content)? = dict["content"] else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32602, message: "Missing path or content parameter")
            )
            try? await transport.send(errorResp)
            return
        }

        let success: Bool
        if let handler = onFileWriteRequest {
            success = await handler(path, content)
        } else {
            // Default: write to disk
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                success = true
            } catch {
                success = false
            }
        }

        if success {
            let response = ACPJsonRpcMessage.response(
                id: id,
                result: .dictionary(["success": .bool(true)])
            )
            try? await transport.send(response)
        } else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -33011, message: "Failed to write file: \(path)")
            )
            try? await transport.send(errorResp)
        }
    }

    // MARK: - Handle Terminal Requests

    private func handleTerminalCreate(id: ACPMessageId, params: ACPAnyCodable?) async {
        guard let factory = terminalSessionFactory else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32603, message: "Terminal sessions not available: no session factory configured")
            )
            try? await transport.send(errorResp)
            return
        }

        // Parse optional parameters with sensible defaults
        var shell: String?
        var columns: UInt16 = 80
        var rows: UInt16 = 24
        var workingDir: String?

        if case .dictionary(let dict)? = params {
            if case .string(let s)? = dict["shell"] { shell = s }
            if case .int(let c)? = dict["columns"] { columns = UInt16(clamping: c) }
            if case .int(let r)? = dict["rows"] { rows = UInt16(clamping: r) }
            if case .string(let d)? = dict["workingDir"] { workingDir = d }
        }

        let termSessionId = "term-\(terminalNextId)"
        terminalNextId += 1

        var session = factory.makeSession()

        // Wire output callback to send notifications back to the agent.
        // These closures are synchronous (@Sendable (Data) -> Void) so we
        // bridge into async context with a Task.
        let capturedTransport = transport
        let capturedSessionId = termSessionId
        session.onOutput = { data in
            let base64 = data.base64EncodedString()
            Task {
                let notification = ACPJsonRpcMessage.notification(
                    method: "terminal/data",
                    params: .dictionary([
                        "sessionId": .string(capturedSessionId),
                        "data": .string(base64),
                    ])
                )
                try? await capturedTransport.send(notification)
            }
        }

        session.onExit = { exitCode in
            Task {
                let notification = ACPJsonRpcMessage.notification(
                    method: "terminal/exit",
                    params: .dictionary([
                        "sessionId": .string(capturedSessionId),
                        "exitCode": .int(Int(exitCode)),
                    ])
                )
                try? await capturedTransport.send(notification)
            }
        }

        do {
            try session.spawn(shell: shell, columns: columns, rows: rows, workingDirectory: workingDir)
        } catch {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32603, message: "Failed to spawn terminal: \(error)")
            )
            try? await transport.send(errorResp)
            return
        }

        terminalSessions[termSessionId] = session

        let response = ACPJsonRpcMessage.response(
            id: id,
            result: .dictionary(["sessionId": .string(termSessionId)])
        )
        try? await transport.send(response)
    }

    private func handleTerminalOutput(id: ACPMessageId, params: ACPAnyCodable?) async {
        guard case .dictionary(let dict)? = params,
              case .string(let termSessionId)? = dict["sessionId"] else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32602, message: "Missing sessionId parameter")
            )
            try? await transport.send(errorResp)
            return
        }

        guard let session = terminalSessions[termSessionId] else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32602, message: "Terminal session not found: \(termSessionId)")
            )
            try? await transport.send(errorResp)
            return
        }

        // Accept base64-encoded data or plain UTF-8 string as fallback
        let data: Data
        if case .string(let dataStr)? = dict["data"] {
            if let decoded = Data(base64Encoded: dataStr) {
                data = decoded
            } else if let utf8 = dataStr.data(using: .utf8) {
                data = utf8
            } else {
                let errorResp = ACPJsonRpcMessage.errorResponse(
                    id: id,
                    error: .init(code: -32602, message: "Invalid data encoding")
                )
                try? await transport.send(errorResp)
                return
            }
        } else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32602, message: "Missing data parameter")
            )
            try? await transport.send(errorResp)
            return
        }

        session.write(data)

        let response = ACPJsonRpcMessage.response(
            id: id,
            result: .dictionary(["success": .bool(true)])
        )
        try? await transport.send(response)
    }

    private func handleTerminalKill(id: ACPMessageId, params: ACPAnyCodable?) async {
        guard case .dictionary(let dict)? = params,
              case .string(let termSessionId)? = dict["sessionId"] else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32602, message: "Missing sessionId parameter")
            )
            try? await transport.send(errorResp)
            return
        }

        guard let session = terminalSessions.removeValue(forKey: termSessionId) else {
            let errorResp = ACPJsonRpcMessage.errorResponse(
                id: id,
                error: .init(code: -32602, message: "Terminal session not found: \(termSessionId)")
            )
            try? await transport.send(errorResp)
            return
        }

        session.terminate()

        let response = ACPJsonRpcMessage.response(
            id: id,
            result: .dictionary(["success": .bool(true)])
        )
        try? await transport.send(response)
    }

    // MARK: - Handle Notifications

    private func handleNotification(_ message: ACPJsonRpcMessage) async {
        guard let method = message.method else { return }

        switch method {
        case "session/update":
            guard let params = message.params,
                  let update = ZedACPSessionUpdate.from(params: params) else { return }
            await onStreamUpdate?(update)

        default:
            break
        }
    }
}

// MARK: - Errors

public enum ZedACPClientError: Error, Sendable {
    case disconnected
    case noSession
    case rpcError(code: Int, message: String)
    case unexpectedResponse(String)
    case launchFailed(String)
}
