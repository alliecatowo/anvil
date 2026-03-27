import Foundation

public struct NotificationRule: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let pattern: String
    public let action: NotificationAction
    public let isEnabled: Bool

    public init(id: String = UUID().uuidString, name: String, pattern: String, action: NotificationAction, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.action = action
        self.isEnabled = isEnabled
    }
}

public enum NotificationAction: String, Sendable, Codable {
    case notify, mute, escalate, snooze
}
