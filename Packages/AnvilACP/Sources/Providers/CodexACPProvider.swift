import Foundation
import AnvilDomain

/// ACP provider wrapper for OpenAI Codex-compatible local agents.
///
/// This uses the same ACP transport adapter as other CLI-backed ACP providers,
/// but establishes a stable provider identity (`codex-acp`) and detection logic
/// so the app can surface Codex as a first-class provider option.
public final class CodexACPProvider: ACPPort, @unchecked Sendable {
    public let providerId: String
    public let providerName: String

    private let adapter: ZedACPProvider

    public init(
        providerId: String = "codex-acp",
        providerName: String = "Codex ACP",
        command: String = "codex",
        args: [String] = ["acp"]
    ) {
        self.providerId = providerId
        self.providerName = providerName
        self.adapter = ZedACPProvider(
            providerId: providerId,
            providerName: providerName,
            command: command,
            args: args
        )
    }

    public func complete(
        messages: [ACPMessage],
        model: ACPModel,
        tools: [ACPToolDefinition],
        stream: Bool
    ) -> AsyncThrowingStream<ACPStreamEvent, Error> {
        adapter.complete(messages: messages, model: model, tools: tools, stream: stream)
    }

    public func availableModels() async throws -> [ACPModel] {
        try await adapter.availableModels()
    }

    public func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        adapter.estimateCost(messages: messages, model: model)
    }

    public func supportsTools(_ tools: [ACPToolDefinition]) -> Bool {
        adapter.supportsTools(tools)
    }

    /// Returns `true` when a usable Codex ACP command is available.
    public static func isAvailable(command: String = "codex", args: [String] = ["acp", "--help"]) -> Bool {
        ZedACPProvider.isAvailable(command: command, args: args)
    }
}
