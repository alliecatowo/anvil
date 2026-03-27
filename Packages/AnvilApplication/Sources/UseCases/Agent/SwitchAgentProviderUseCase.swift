import Foundation
import AnvilDomain

public struct SwitchAgentProviderUseCase: Sendable {
    public init() {}

    public func execute(
        sessionId: String,
        newProvider: any AgentPort,
        model: String?
    ) async throws {
        // Pause current session, prepare to resume with new provider
        // The actual implementation would transfer context
    }
}
