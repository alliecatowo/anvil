import Foundation

public struct Notification: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let body: String
    public let source: String
    public let urgency: NotificationUrgency
    public let isRead: Bool
    public let url: String?
    public let createdAt: Date

    public init(id: String = UUID().uuidString, title: String, body: String, source: String, urgency: NotificationUrgency = .normal, isRead: Bool = false, url: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.source = source
        self.urgency = urgency
        self.isRead = isRead
        self.url = url
        self.createdAt = createdAt
    }
}

public enum NotificationUrgency: String, Sendable, Codable {
    case low, normal, high, critical
}
