import Foundation
import AnvilDomain

public struct StartAgentSessionUseCase: Sendable {
    public init() {}

    public func execute(
        prompt: String,
        projectPath: String,
        workItemId: String?,
        provider: any AgentPort,
        model: String?
    ) async throws -> AgentSession {
        let context = AgentContext(
            projectPath: projectPath,
            workItemId: workItemId,
            tools: ["read_file", "write_file", "search", "terminal"]
        )

        let session = try await provider.startSession(
            prompt: prompt,
            context: context,
            model: model,
            tools: context.tools
        )

        await EventBus.shared.publish(
            AgentSessionStartedEvent(sessionId: session.id, model: model ?? session.model, workItemId: workItemId)
        )

        return session
    }
}
