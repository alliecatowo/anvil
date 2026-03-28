import Foundation
import UserNotifications
import AppKit

/// Wraps UNUserNotificationCenter for real macOS desktop notifications.
/// Handles authorization, scheduling local notifications, badge count,
/// and delegate callbacks for notification tap actions.
///
/// Thread-safe: all UNUserNotificationCenter APIs are internally serialized.
/// The singleton is safe to call from any actor/thread.
public final class MacNotificationService: NSObject, Sendable {

    public static let shared = MacNotificationService()

    // Category identifiers for actionable notifications
    public enum Category {
        public static let agentCompleted = "AGENT_COMPLETED"
        public static let ticketAssigned = "TICKET_ASSIGNED"
        public static let prReviewRequested = "PR_REVIEW_REQUESTED"
        public static let deployStatus = "DEPLOY_STATUS"
    }

    // Action identifiers for notification buttons
    public enum Action {
        public static let view = "VIEW_ACTION"
        public static let dismiss = "DISMISS_ACTION"
    }

    // nonisolated(unsafe): UNUserNotificationCenter is not Sendable but .current()
    // returns a process-wide singleton with internally serialized state.
    nonisolated(unsafe) private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    /// Request notification authorization. Call once at app launch.
    /// Returns true if the user granted permission.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await registerCategories()
            }
            return granted
        } catch {
            return false
        }
    }

    /// Register actionable notification categories so the system shows action buttons.
    private func registerCategories() async {
        let viewAction = UNNotificationAction(
            identifier: Action.view,
            title: "View",
            options: .foreground
        )
        let dismissAction = UNNotificationAction(
            identifier: Action.dismiss,
            title: "Dismiss",
            options: .destructive
        )

        let categories: [UNNotificationCategory] = [
            UNNotificationCategory(
                identifier: Category.agentCompleted,
                actions: [viewAction, dismissAction],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.ticketAssigned,
                actions: [viewAction, dismissAction],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.prReviewRequested,
                actions: [viewAction, dismissAction],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.deployStatus,
                actions: [viewAction, dismissAction],
                intentIdentifiers: []
            ),
        ]

        center.setNotificationCategories(Set(categories))
    }

    // MARK: - Install Delegate

    /// Install a delegate to handle notification tap actions.
    /// Must be called from the main thread (typically in AppDelegate).
    @MainActor
    public func installDelegate(_ delegate: UNUserNotificationCenterDelegate) {
        center.delegate = delegate
    }

    // MARK: - Schedule Notifications

    /// Schedule a local notification immediately (fires in 1 second).
    public func send(
        title: String,
        body: String,
        category: String,
        identifier: String = UUID().uuidString,
        userInfo: [String: String] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = userInfo

        // Fire in 1 second (UNTimeIntervalNotificationTrigger requires > 0)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Convenience Senders

    /// Notify that an agent session completed.
    public func notifyAgentCompleted(sessionId: String, workItemId: String?, branchName: String?) {
        let branch = branchName.map { " on \($0)" } ?? ""
        let item = workItemId.map { " (\($0))" } ?? ""
        send(
            title: "Agent session completed",
            body: "Session\(item) finished\(branch). Ready for review.",
            category: Category.agentCompleted,
            userInfo: ["sessionId": sessionId]
        )
    }

    /// Notify that a ticket was assigned to the user.
    public func notifyTicketAssigned(ticketId: String, title: String, assignee: String) {
        send(
            title: "Ticket assigned to you",
            body: title,
            category: Category.ticketAssigned,
            userInfo: ["ticketId": ticketId]
        )
    }

    /// Notify that a PR review was requested.
    public func notifyPRReviewRequested(prId: String, repo: String, title: String) {
        send(
            title: "Review requested",
            body: "\(repo): \(title)",
            category: Category.prReviewRequested,
            userInfo: ["prId": prId, "repo": repo]
        )
    }

    /// Notify about deploy status (succeeded or failed).
    public func notifyDeployStatus(deployId: String, name: String, succeeded: Bool) {
        send(
            title: succeeded ? "Deploy succeeded" : "Deploy failed",
            body: name,
            category: Category.deployStatus,
            userInfo: ["deployId": deployId, "succeeded": succeeded ? "true" : "false"]
        )
    }

    // MARK: - Badge Count

    /// Update the app dock badge to reflect unread notification count.
    @MainActor
    public func setBadgeCount(_ count: Int) {
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    // MARK: - Pending Notifications

    /// Remove all delivered notifications from Notification Center.
    public func removeAllDelivered() {
        center.removeAllDeliveredNotifications()
    }

    /// Remove a specific delivered notification.
    public func removeDelivered(identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
