import Foundation
import AnvilDomain

public struct ContextBuilder: Sendable {
    public init() {}

    public func build(
        projectPath: String,
        workItemId: String?,
        additionalContext: String?
    ) -> AgentContext {
        AgentContext(
            projectPath: projectPath,
            workItemId: workItemId,
            additionalContext: additionalContext,
            tools: ["read_file", "write_file", "search_files", "terminal", "browser"]
        )
    }
}
