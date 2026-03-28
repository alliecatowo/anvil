import AnvilDomain
import Foundation

/// In-memory notification store -- default implementation until a real backend is wired.
public actor InMemoryNotificationService: NotificationPort {
    private var notifications: [String: AnvilDomain.Notification] = [:]
    private var rules: [String: NotificationRule] = [:]

    public let providerId = "in-memory-notifications"
    public let providerName = "In-Memory Notifications"

    public init() {
        let n1 = AnvilDomain.Notification(
            title: "Welcome to Anvil",
            body: "Your development environment is ready.",
            source: "system",
            urgency: .normal
        )
        notifications[n1.id] = n1
    }

    public func validateConnection() async throws -> Bool { true }

    public func notifications(unreadOnly: Bool) async throws -> [AnvilDomain.Notification] {
        let all = Array(notifications.values)
        if unreadOnly {
            return all.filter { !$0.isRead }.sorted { $0.createdAt > $1.createdAt }
        }
        return all.sorted { $0.createdAt > $1.createdAt }
    }

    public func markAsRead(notificationId: String) async throws {
        guard let existing = notifications[notificationId] else { return }
        notifications[notificationId] = AnvilDomain.Notification(
            id: existing.id,
            title: existing.title,
            body: existing.body,
            source: existing.source,
            urgency: existing.urgency,
            isRead: true,
            url: existing.url,
            createdAt: existing.createdAt
        )
    }

    public func markAllAsRead() async throws {
        for (id, existing) in notifications {
            notifications[id] = AnvilDomain.Notification(
                id: existing.id,
                title: existing.title,
                body: existing.body,
                source: existing.source,
                urgency: existing.urgency,
                isRead: true,
                url: existing.url,
                createdAt: existing.createdAt
            )
        }
    }

    public func rules() async throws -> [NotificationRule] {
        Array(rules.values)
    }

    public func createRule(name: String, pattern: String, action: NotificationAction) async throws -> NotificationRule {
        let rule = NotificationRule(name: name, pattern: pattern, action: action)
        rules[rule.id] = rule
        return rule
    }

    public func deleteRule(ruleId: String) async throws {
        rules.removeValue(forKey: ruleId)
    }

    public func send(title: String, body: String, urgency: NotificationUrgency) async throws {
        let notification = AnvilDomain.Notification(title: title, body: body, source: "local", urgency: urgency)
        notifications[notification.id] = notification
    }
}
