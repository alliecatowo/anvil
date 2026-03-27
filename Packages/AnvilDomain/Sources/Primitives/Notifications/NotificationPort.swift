import Foundation

public protocol NotificationPort: AnvilProviderDefinition {
    func notifications(unreadOnly: Bool) async throws -> [Notification]
    func markAsRead(notificationId: String) async throws
    func markAllAsRead() async throws
    func rules() async throws -> [NotificationRule]
    func createRule(name: String, pattern: String, action: NotificationAction) async throws -> NotificationRule
    func deleteRule(ruleId: String) async throws
    func send(title: String, body: String, urgency: NotificationUrgency) async throws
}
