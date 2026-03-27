import Foundation
import AnvilDomain

/// Adapts a Zed ACP agent to Anvil's ACPPort protocol.
///
/// Connects to an ACP-compatible agent process (e.g., `npx @agentclientprotocol/claude-agent-acp`)
/// and translates between Zed ACP's bidirectional JSON-RPC protocol and Anvil's streaming events.
public final class ZedACPProvider: ACPPort, @unchecked Sendable {
    public let providerId: String
    public let providerName: String

    private let command: String
    private let args: [String]
    private let env: [String: String]?

    /// Actor-isolated state for connection management
    private let state = ConnectionState()

    actor ConnectionState {
        var client: ZedACPClient?
        var isInitialized = false

        func getClient() -> ZedACPClient? { client }
        func setClient(_ c: ZedACPClient) { client = c }
        func markInitialized() { isInitialized = true }
        func checkInitialized() -> Bool { isInitialized }
    }

    public init(
        providerId: String = "zed-acp",
        providerName: String = "ACP Agent",
        command: String,
        args: [String] = [],
        env: [String: String]? = nil
    ) {
        self.providerId = providerId
        self.providerName = providerName
        self.command = command
        self.args = args
        self.env = env
    }

    public func complete(
        messages: [ACPMessage],
        model: ACPModel,
        tools: [ACPToolDefinition],
        stream: Bool
    ) -> AsyncThrowingStream<ACPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let acpClient = try await ensureConnected()

                    // Set up streaming callback to forward session updates
                    await acpClient.setStreamUpdate { @Sendable update in
                        switch update {
                        case .agentMessageChunk(let text):
                            continuation.yield(.textDelta(text))
                        case .toolCall(let id, let name, _):
                            continuation.yield(.toolCallStart(id: id, name: name))
                        case .toolCallUpdate(let id, _, let content):
                            if let content {
                                continuation.yield(.toolCallDelta(id: id, argumentsDelta: content))
                            }
                        case .plan(let content):
                            // Plans are surfaced as text deltas
                            continuation.yield(.textDelta(content))
                        case .availableCommands, .unknown:
                            break
                        }
                    }

                    // Extract prompt from messages
                    let userMessages = messages.filter { $0.role != .system }
                    let prompt = userMessages.map { $0.content }.joined(separator: "\n\n")

                    // Send the prompt and wait for the turn to complete
                    let result = try await acpClient.prompt(text: prompt)

                    // Emit completion
                    let fullText = "" // text was already streamed via deltas
                    let _ = result.stopReason
                    continuation.yield(.messageComplete(ACPMessage(role: .assistant, content: fullText)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ACPError.providerError("ZedACP error: \(error.localizedDescription)"))
                }
            }
        }
    }

    public func availableModels() async throws -> [ACPModel] {
        // ACP agents typically handle model selection internally.
        // Expose a default model for Anvil's routing.
        [
            ACPModel(
                id: "acp-agent",
                name: "ACP Agent (auto)",
                provider: providerId,
                contextWindow: 200_000,
                inputCostPer1kTokens: 0,
                outputCostPer1kTokens: 0,
                capabilities: [.codeGeneration, .codeReview, .reasoning, .toolUse]
            ),
        ]
    }

    public func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        // ACP agents manage their own cost; we can't estimate from the client side
        ACPCostEstimate(estimatedInputTokens: 0, estimatedOutputTokens: 0, estimatedCost: 0)
    }

    public func supportsTools(_ tools: [ACPToolDefinition]) -> Bool {
        // ACP agents have their own tool implementations
        true
    }

    // MARK: - Connection Management

    private func ensureConnected() async throws -> ZedACPClient {
        if let existing = await state.getClient(), await state.checkInitialized() {
            return existing
        }
        let newClient = ZedACPClient()
        await state.setClient(newClient)

        try await newClient.connect(command: command, args: args, env: env)
        let _ = try await newClient.initialize()

        let cwd = FileManager.default.currentDirectoryPath
        let _ = try await newClient.newSession(cwd: cwd)

        await state.markInitialized()
        return newClient
    }

    /// Check if the ACP adapter command is available on the system.
    public static func isAvailable(command: String = "npx", args: [String] = ["@agentclientprotocol/claude-agent-acp", "--help"]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.environment = ProcessInfo.processInfo.environment

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

// MARK: - ZedACPClient callback setter extension

extension ZedACPClient {
    /// Set the stream update callback.
    func setStreamUpdate(_ handler: @escaping @Sendable (ZedACPSessionUpdate) async -> Void) {
        self.onStreamUpdate = handler
    }
}
