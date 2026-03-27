import SwiftUI
import AnvilDomain

// MARK: - Notification Preferences

/// Persisted notification preferences — per-source toggles, urgency threshold, and custom filter rules.
@MainActor
final class NotificationPreferences: ObservableObject {

    static let shared = NotificationPreferences()

    private let defaults = UserDefaults.standard

    // MARK: Global Toggle

    @Published var desktopNotificationsEnabled: Bool {
        didSet { defaults.set(desktopNotificationsEnabled, forKey: Keys.desktopEnabled) }
    }

    // MARK: Urgency Threshold

    /// Minimum urgency to show in the inbox and fire desktop notifications.
    @Published var minimumUrgency: NotificationUrgency {
        didSet { defaults.set(minimumUrgency.rawValue, forKey: Keys.minimumUrgency) }
    }

    // MARK: Per-Source Toggles

    @Published var prEnabled: Bool {
        didSet { defaults.set(prEnabled, forKey: Keys.prEnabled) }
    }
    @Published var deployEnabled: Bool {
        didSet { defaults.set(deployEnabled, forKey: Keys.deployEnabled) }
    }
    @Published var errorEnabled: Bool {
        didSet { defaults.set(errorEnabled, forKey: Keys.errorEnabled) }
    }
    @Published var messageEnabled: Bool {
        didSet { defaults.set(messageEnabled, forKey: Keys.messageEnabled) }
    }
    @Published var mentionEnabled: Bool {
        didSet { defaults.set(mentionEnabled, forKey: Keys.mentionEnabled) }
    }

    // MARK: Custom Filter Rules

    @Published var rules: [NotificationRule] {
        didSet { saveRules() }
    }

    // MARK: Init

    init() {
        let d = UserDefaults.standard
        self.desktopNotificationsEnabled = d.object(forKey: Keys.desktopEnabled) as? Bool ?? true
        if let raw = d.string(forKey: Keys.minimumUrgency),
           let urgency = NotificationUrgency(rawValue: raw) {
            self.minimumUrgency = urgency
        } else {
            self.minimumUrgency = .low
        }
        self.prEnabled = d.object(forKey: Keys.prEnabled) as? Bool ?? true
        self.deployEnabled = d.object(forKey: Keys.deployEnabled) as? Bool ?? true
        self.errorEnabled = d.object(forKey: Keys.errorEnabled) as? Bool ?? true
        self.messageEnabled = d.object(forKey: Keys.messageEnabled) as? Bool ?? true
        self.mentionEnabled = d.object(forKey: Keys.mentionEnabled) as? Bool ?? true
        self.rules = Self.loadRules()
    }

    // MARK: - Filtering

    /// Returns true if the given inbox item passes all preference filters.
    func shouldShow(_ item: InboxItem) -> Bool {
        // Source toggle
        guard isSourceEnabled(item.source) else { return false }

        // Urgency threshold
        guard meetsUrgency(item.notification.urgency) else { return false }

        // Custom rules — muted patterns suppress matching items
        for rule in rules where rule.isEnabled && rule.action == .mute {
            if matchesPattern(rule.pattern, title: item.notification.title, body: item.notification.body) {
                return false
            }
        }

        return true
    }

    /// Returns true if a desktop notification should fire for this item.
    func shouldSendDesktopNotification(_ item: InboxItem) -> Bool {
        guard desktopNotificationsEnabled else { return false }
        return shouldShow(item)
    }

    func isSourceEnabled(_ source: NotificationSource) -> Bool {
        switch source {
        case .pr:      prEnabled
        case .deploy:  deployEnabled
        case .error:   errorEnabled
        case .message: messageEnabled
        case .mention: mentionEnabled
        }
    }

    // MARK: - Rule Management

    func addRule(name: String, pattern: String, action: NotificationAction) {
        let rule = NotificationRule(name: name, pattern: pattern, action: action)
        rules.append(rule)
    }

    func removeRule(id: String) {
        rules.removeAll { $0.id == id }
    }

    func toggleRule(id: String) {
        if let index = rules.firstIndex(where: { $0.id == id }) {
            let old = rules[index]
            rules[index] = NotificationRule(id: old.id, name: old.name, pattern: old.pattern, action: old.action, isEnabled: !old.isEnabled)
        }
    }

    // MARK: - Private

    private func meetsUrgency(_ urgency: NotificationUrgency) -> Bool {
        let order: [NotificationUrgency] = [.low, .normal, .high, .critical]
        guard let urgencyIndex = order.firstIndex(of: urgency),
              let thresholdIndex = order.firstIndex(of: minimumUrgency) else {
            return true
        }
        return urgencyIndex >= thresholdIndex
    }

    private func matchesPattern(_ pattern: String, title: String, body: String) -> Bool {
        let lowered = pattern.lowercased()
        return title.lowercased().contains(lowered) || body.lowercased().contains(lowered)
    }

    // MARK: - Persistence

    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: Keys.rules)
        }
    }

    private static func loadRules() -> [NotificationRule] {
        guard let data = UserDefaults.standard.data(forKey: Keys.rules),
              let rules = try? JSONDecoder().decode([NotificationRule].self, from: data) else {
            return []
        }
        return rules
    }

    private enum Keys {
        static let desktopEnabled = "notification.desktopEnabled"
        static let minimumUrgency = "notification.minimumUrgency"
        static let prEnabled = "notification.source.pr"
        static let deployEnabled = "notification.source.deploy"
        static let errorEnabled = "notification.source.error"
        static let messageEnabled = "notification.source.message"
        static let mentionEnabled = "notification.source.mention"
        static let rules = "notification.rules"
    }
}
