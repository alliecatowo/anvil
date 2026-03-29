import Foundation

/// Canonical launch-time seeds for deterministic UI tests and visual regression screenshots.
public enum UITestScenario: String, CaseIterable, Sendable {
    case agentEmpty = "agent-empty"
    case agentConversation = "agent-conversation"
    case intentList = "intent-list"
    case intentBoard = "intent-board"
    case reviewInbox = "review-inbox"
    case reviewDiff = "review-diff"
    case shipDashboard = "ship-dashboard"
    case workspaceTerminal = "workspace-terminal"
    case workspaceNotifications = "workspace-notifications"
}
