import Foundation

public protocol AgentPort: AnvilProviderDefinition {
    func startSession(prompt: String, context: AgentContext, model: String?, tools: [String]) async throws -> AgentSession
    func sendMessage(sessionId: String, content: String) async throws -> AsyncThrowingStream<AgentStreamEvent, Error>
    func approveToolCall(sessionId: String, toolCallId: String) async throws
    func rejectToolCall(sessionId: String, toolCallId: String, reason: String?) async throws
    func pauseSession(sessionId: String) async throws
    func resumeSession(sessionId: String) async throws
    func cancelSession(sessionId: String) async throws
    func availableModels() async throws -> [AgentModel]
    func estimateCost(prompt: String, model: String) async throws -> CostEstimate
}
