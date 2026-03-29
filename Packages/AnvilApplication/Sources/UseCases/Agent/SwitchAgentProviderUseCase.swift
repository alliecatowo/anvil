import Foundation
import AnvilDomain

public struct SwitchAgentProviderResult: Sendable {
    public let sessionId: String
    public let previousProvider: String
    public let newProvider: String
    public let model: String?
    public let switchedAt: Date

    public init(sessionId: String, previousProvider: String, newProvider: String, model: String?, switchedAt: Date = .now) {
        self.sessionId = sessionId
        self.previousProvider = previousProvider
        self.newProvider = newProvider
        self.model = model
        self.switchedAt = switchedAt
    }
}

public struct SwitchAgentProviderUseCase: Sendable {
    public init() {}

    public func execute(
        sessionId: String,
        previousProviderName: String,
        newProviderName: String,
        model: String?
    ) async throws -> SwitchAgentProviderResult {
        guard previousProviderName != newProviderName else {
            throw SwitchAgentProviderError.sameProvider
        }

        // Context transfer between providers is not yet possible without a real
        // AgentPort handoff mechanism. For now, log the switch via the EventBus
        // and return a result so callers can track that the switch was requested.

        let result = SwitchAgentProviderResult(
            sessionId: sessionId,
            previousProvider: previousProviderName,
            newProvider: newProviderName,
            model: model
        )

        await EventBus.shared.publish(
            AgentProviderSwitchedEvent(
                sessionId: sessionId,
                previousProvider: result.previousProvider,
                newProvider: result.newProvider
            )
        )

        return result
    }
}

public enum SwitchAgentProviderError: Error, Sendable {
    case sameProvider
    case noActiveSession
}
