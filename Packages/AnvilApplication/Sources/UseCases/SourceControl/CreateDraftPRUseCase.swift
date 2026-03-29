import AnvilDomain
import Foundation

/// Automatically creates a draft GitHub PR when an agent session completes
/// with file changes in an isolated worktree.
public struct CreateDraftPRUseCase: Sendable {
    private let eventBus: EventBus

    public init(eventBus: EventBus) {
        self.eventBus = eventBus
    }

    /// Result of a draft PR creation attempt.
    public struct DraftPRResult: Sendable {
        public let prNumber: Int
        public let url: String
        public let title: String
    }

    /// Execute the use case: create a draft PR from the session's worktree branch.
    /// - Parameters:
    ///   - session: The completed agent session (must have a worktreePath and branch).
    ///   - repo: The GitHub repo in "owner/repo" format.
    ///   - sourceBranch: The branch the session worked on.
    ///   - targetBranch: The branch to merge into (default: "main").
    ///   - cloudPort: The source control cloud adapter for GitHub API calls.
    /// - Returns: The created PR info, or nil if creation was skipped.
    public func execute(
        session: AgentSession,
        repo: String,
        sourceBranch: String,
        targetBranch: String = "main",
        cloudPort: any SourceControlCloudPort
    ) async throws -> DraftPRResult {
        let title = buildPRTitle(session: session)
        let body = buildPRBody(session: session)

        let pr = try await cloudPort.createPullRequest(
            repo: repo,
            title: title,
            body: body,
            source: sourceBranch,
            target: targetBranch,
            isDraft: true
        )

        let url = "https://github.com/\(repo)/pull/\(pr.number)"

        await eventBus.publish(DraftPRCreatedEvent(
            sessionId: session.id, prNumber: pr.number, url: url
        ))

        return DraftPRResult(prNumber: pr.number, url: url, title: title)
    }

    // MARK: - Helpers

    private func buildPRTitle(session: AgentSession) -> String {
        let name = session.displayName
        if name.count <= 72 { return name }
        return String(name.prefix(69)) + "..."
    }

    private func buildPRBody(session: AgentSession) -> String {
        var parts: [String] = []
        parts.append("## Summary")
        parts.append("")
        parts.append("Auto-generated draft PR from agent session `\(session.id)`.")
        parts.append("")

        if let workItem = session.workItemId {
            parts.append("**Work item:** \(workItem)")
            parts.append("")
        }

        // Build a brief conversation summary from the first few messages
        let messages = session.messages.prefix(20)
        let userMessages = messages.filter { $0.role == .user }
        if !userMessages.isEmpty {
            parts.append("## Context")
            parts.append("")
            for msg in userMessages.prefix(3) {
                let content = String(msg.content.prefix(200))
                if !content.isEmpty {
                    parts.append("> \(content)")
                    parts.append("")
                }
            }
        }

        let toolNames = Set(session.messages.flatMap { $0.toolCalls.map(\.name) })
        if !toolNames.isEmpty {
            parts.append("## Tools Used")
            parts.append("")
            for tool in toolNames.sorted().prefix(10) {
                parts.append("- `\(tool)`")
            }
            parts.append("")
        }

        parts.append("---")
        parts.append("*Created automatically by Anvil agent session.*")

        return parts.joined(separator: "\n")
    }
}
