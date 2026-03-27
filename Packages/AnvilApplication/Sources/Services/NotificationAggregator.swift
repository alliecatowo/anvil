import Foundation
import AnvilDomain

public actor NotificationAggregator {
    public struct AppNotification: Sendable, Identifiable {
        public let id: String
        public let sourcePrimitive: String
        public let title: String
        public let body: String
        public let priority: NotificationPriority
        public let timestamp: Date
        public var isRead: Bool

        public init(id: String = UUID().uuidString, sourcePrimitive: String, title: String, body: String, priority: NotificationPriority = .normal, timestamp: Date = .now, isRead: Bool = false) {
            self.id = id
            self.sourcePrimitive = sourcePrimitive
            self.title = title
            self.body = body
            self.priority = priority
            self.timestamp = timestamp
            self.isRead = isRead
        }
    }

    public enum NotificationPriority: Int, Sendable, Comparable {
        case critical = 0, high = 1, normal = 2, low = 3

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private var notifications: [AppNotification] = []

    public init() {}

    public func add(_ notification: AppNotification) {
        notifications.append(notification)
    }

    public func unread() -> [AppNotification] {
        notifications.filter { !$0.isRead }.sorted { $0.priority < $1.priority }
    }

    public func markRead(_ id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
        }
    }

    public func unreadCount() -> Int {
        notifications.filter { !$0.isRead }.count
    }
}
