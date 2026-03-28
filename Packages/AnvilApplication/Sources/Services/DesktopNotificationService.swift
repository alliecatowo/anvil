import Foundation
import UserNotifications
import AnvilDomain

/// Sends native macOS notifications via UNUserNotificationCenter.
/// Handles permission requests, notification delivery, and click actions.
public final class DesktopNotificationService: NSObject, Sendable {

    public static let shared = DesktopNotificationService()

    /// Category identifiers for actionable notifications.
    private enum Category {
        static let prReview = "PR_REVIEW"
        static let ciFailure = "CI_FAILURE"
        static let general = "GENERAL"
    }

    /// Action identifiers for notification buttons.
    private enum Action {
        static let viewItem = "VIEW_ITEM"
        static let markRead = "MARK_READ"
    }

    /// UserInfo keys embedded in each notification payload.
    public enum UserInfoKey {
        public static let notificationId = "anvil.notificationId"
        public static let targetMode = "anvil.targetMode"
        public static let targetItemId = "anvil.targetItemId"
        public static let url = "anvil.url"
    }

    /// Minimum urgency level required to show a desktop notification.
    /// Defaults to `.normal` — low-priority items are silent.
    public nonisolated(unsafe) var minimumUrgency: NotificationUrgency = .normal

    /// Whether desktop notifications are enabled at all.
    public nonisolated(unsafe) var isEnabled: Bool = true

    private override init() {
        super.init()
    }

    // MARK: - Permission

    /// Request notification permission from the user. Call once at app launch.
    public func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                registerCategories()
            }
            return granted
        } catch {
            return false
        }
    }

    /// Check current authorization status without prompting.
    public func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Send Notification

    /// Send a native macOS notification for an in-app notification item.
    ///
    /// - Parameters:
    ///   - notification: The domain notification model.
    ///   - source: Optional source hint (e.g., "pr", "deploy", "error") for categorization.
    ///   - targetMode: The AnvilSpace rawValue to navigate to on click.
    ///   - targetItemId: Optional item ID to select after navigating.
    public func send(
        notification: AnvilDomain.Notification,
        source: String? = nil,
        targetMode: String = "Notifications",
        targetItemId: String? = nil
    ) {
        guard isEnabled else { return }
        guard meetsUrgencyThreshold(notification.urgency) else { return }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = soundForUrgency(notification.urgency)
        content.threadIdentifier = notification.source

        // Categorize for action buttons
        content.categoryIdentifier = categoryForSource(source ?? notification.source)

        // Embed navigation info for click handling
        var userInfo: [String: String] = [
            UserInfoKey.notificationId: notification.id,
            UserInfoKey.targetMode: targetMode,
        ]
        if let itemId = targetItemId {
            userInfo[UserInfoKey.targetItemId] = itemId
        }
        if let url = notification.url {
            userInfo[UserInfoKey.url] = url
        }
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "anvil-\(notification.id)",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Categories & Actions

    private func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: Action.viewItem,
            title: "View",
            options: .foreground
        )
        let markReadAction = UNNotificationAction(
            identifier: Action.markRead,
            title: "Mark as Read",
            options: []
        )

        let prCategory = UNNotificationCategory(
            identifier: Category.prReview,
            actions: [viewAction, markReadAction],
            intentIdentifiers: []
        )
        let ciCategory = UNNotificationCategory(
            identifier: Category.ciFailure,
            actions: [viewAction, markReadAction],
            intentIdentifiers: []
        )
        let generalCategory = UNNotificationCategory(
            identifier: Category.general,
            actions: [viewAction, markReadAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            prCategory, ciCategory, generalCategory,
        ])
    }

    // MARK: - Helpers

    private func meetsUrgencyThreshold(_ urgency: NotificationUrgency) -> Bool {
        let order: [NotificationUrgency] = [.low, .normal, .high, .critical]
        guard let urgencyIndex = order.firstIndex(of: urgency),
              let thresholdIndex = order.firstIndex(of: minimumUrgency) else {
            return true
        }
        return urgencyIndex >= thresholdIndex
    }

    private func soundForUrgency(_ urgency: NotificationUrgency) -> UNNotificationSound {
        switch urgency {
        case .critical: .defaultCritical
        case .high, .normal: .default
        case .low: .default
        }
    }

    private func categoryForSource(_ source: String) -> String {
        switch source {
        case "github", "pr": Category.prReview
        case "ci", "deploy": Category.ciFailure
        default: Category.general
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension DesktopNotificationService: UNUserNotificationCenterDelegate {

    /// Called when a notification is delivered while the app is in the foreground.
    /// We show it as a banner even when the app is focused.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Called when the user clicks a notification or taps an action button.
    /// Posts a Notification to NotificationCenter so the UI layer can handle navigation.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        let payload: [String: Any] = [
            "action": response.actionIdentifier,
            "notificationId": userInfo[UserInfoKey.notificationId] as? String ?? "",
            "targetMode": userInfo[UserInfoKey.targetMode] as? String ?? "Notifications",
            "targetItemId": userInfo[UserInfoKey.targetItemId] as? String ?? "",
            "url": userInfo[UserInfoKey.url] as? String ?? "",
        ]

        await MainActor.run {
            NotificationCenter.default.post(
                name: .anvilDesktopNotificationTapped,
                object: nil,
                userInfo: payload
            )
        }
    }
}

// MARK: - Foundation.Notification.Name

public extension Foundation.Notification.Name {
    /// Posted when the user taps a native macOS notification.
    /// UserInfo contains: notificationId, targetMode, targetItemId, url, action.
    static let anvilDesktopNotificationTapped = Foundation.Notification.Name("anvilDesktopNotificationTapped")
}
