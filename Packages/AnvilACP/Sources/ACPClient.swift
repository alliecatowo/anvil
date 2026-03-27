import Foundation
import AnvilDomain

/// Central ACP client that manages provider registration and request routing.
///
/// Supports two kinds of providers:
/// - **Direct providers**: Implement ACPPort directly (HTTP adapters like AnthropicProvider, OllamaProvider)
/// - **Process providers**: Launch a binary and communicate via ACP protocol over stdin/stdout
///
/// The client auto-selects the best available provider based on registration order
/// and explicit default settings.
public actor ACPClient {
    private var providers: [String: any ACPPort] = [:]
    private var processTransports: [String: ACPProcessTransport] = [:]
    private var defaultProviderId: String?
    private let costTracker = ACPCostTracker()

    public init() {}

    // MARK: - Provider Registration

    /// Register a provider that directly implements ACPPort (HTTP adapters, CLI wrappers, etc.)
    public func registerProvider(_ provider: any ACPPort) {
        providers[provider.providerId] = provider
        if defaultProviderId == nil {
            defaultProviderId = provider.providerId
        }
    }

    /// Register a process-based provider by executable path.
    /// This creates both a transport (for future persistent connections) and a
    /// ClaudeProcessProvider that adapts the CLI to ACPPort today.
    ///
    /// When providers gain native ACP JSON-RPC support, this method will use the
    /// transport for a persistent bidirectional connection instead of per-request processes.
    public func registerProcessProvider(
        id: String = "claude-process",
        path: String,
        args: [String] = []
    ) {
        // Store the transport for future use when native ACP protocol is supported
        let transport = ACPProcessTransport(executablePath: path, arguments: args)
        processTransports[id] = transport

        // For now, use the ClaudeProcessProvider which spawns per-request
        let provider = ClaudeProcessProvider(cliPath: path)
        providers[provider.providerId] = provider
        if defaultProviderId == nil {
            defaultProviderId = provider.providerId
        }
    }

    public func setDefaultProvider(_ id: String) {
        defaultProviderId = id
    }

    public func provider(_ id: String? = nil) -> (any ACPPort)? {
        if let id { return providers[id] }
        guard let defaultId = defaultProviderId else { return nil }
        return providers[defaultId]
    }

    public func allProviders() -> [any ACPPort] {
        Array(providers.values)
    }

    /// Get the process transport for a provider (if it was registered as a process provider).
    /// Useful for providers that support persistent ACP connections.
    public func transport(for providerId: String) -> ACPProcessTransport? {
        processTransports[providerId]
    }

    public func complete(
        prompt: String,
        systemPrompt: String? = nil,
        model: ACPModel? = nil,
        providerId: String? = nil,
        tools: [ACPToolDefinition] = []
    ) async throws -> String {
        guard let provider = provider(providerId) else {
            throw ACPError.providerError("No ACP provider configured")
        }

        var messages: [ACPMessage] = []
        if let systemPrompt {
            messages.append(ACPMessage(role: .system, content: systemPrompt))
        }
        messages.append(ACPMessage(role: .user, content: prompt))

        let resolvedModel: ACPModel
        if let model {
            resolvedModel = model
        } else {
            guard let firstModel = try await provider.availableModels().first else {
                throw ACPError.providerError("Provider has no available models")
            }
            resolvedModel = firstModel
        }

        var result = ""
        let stream = provider.complete(messages: messages, model: resolvedModel, tools: tools, stream: true)

        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                result += delta
            case .usage(let usage):
                let cost = Decimal(usage.inputTokens) * resolvedModel.inputCostPer1kTokens / 1000 +
                           Decimal(usage.outputTokens) * resolvedModel.outputCostPer1kTokens / 1000
                await costTracker.record(.init(
                    provider: provider.providerId,
                    model: resolvedModel.id,
                    inputTokens: usage.inputTokens,
                    outputTokens: usage.outputTokens,
                    cost: cost,
                    timestamp: .now
                ))
            default:
                break
            }
        }

        return result
    }

    public func todayCost() async -> Decimal {
        await costTracker.todayCost()
    }

    public func sessionCost(since: Date) async -> Decimal {
        await costTracker.sessionCost(since: since)
    }
}
