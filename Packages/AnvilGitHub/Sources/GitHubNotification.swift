import Foundation

/// A mapped GitHub notification for consumption by the UI layer.
public struct GitHubNotification: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let reason: String
    public let type: NotificationType
    public let repoFullName: String
    public let url: String?
    public let unread: Bool
    public let urgency: Urgency
    public let updatedAt: Date

    public enum NotificationType: String, Sendable {
        case pullRequest, issue, ciCheck, release, other
    }

    public enum Urgency: String, Sendable {
        case low, normal, high, critical
    }
}
