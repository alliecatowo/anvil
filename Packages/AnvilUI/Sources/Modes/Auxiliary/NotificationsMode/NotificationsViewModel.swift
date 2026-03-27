import SwiftUI
import AnvilDomain

// MARK: - Notifications Tab

enum NotificationsTab: String, CaseIterable {
    case inbox = "Inbox"
    case activity = "Activity"
}

// MARK: - Notification Source (UI-level)

enum NotificationSource: String {
    case pr, deploy, error, message, mention

    var icon: String {
        switch self {
        case .pr: "arrow.triangle.pull"
        case .deploy: "shippingbox"
        case .error: "exclamationmark.triangle.fill"
        case .message: "message"
        case .mention: "at"
        }
    }

    var color: Color {
        switch self {
        case .pr: AnvilColor.accentPurple
        case .deploy: AnvilColor.accentGreen
        case .error: AnvilColor.accentRed
        case .message: AnvilColor.accentBlue
        case .mention: AnvilColor.accentAmber
        }
    }
}

// MARK: - Display Models

struct InboxItem: Identifiable {
    let id: String
    let notification: AnvilDomain.Notification
    let source: NotificationSource
}

struct ActivityEvent: Identifiable {
    let id: String
    let icon: String
    let iconColor: Color
    let description: String
    let timestamp: Date
}

// MARK: - View Model

@MainActor
final class NotificationsViewModel: ObservableObject {

    // MARK: Navigation

    @Published var selectedTab: NotificationsTab = .inbox
    @Published var selectedItemID: String?

    // MARK: Data

    @Published var inboxItems: [InboxItem] = []
    @Published var activityEvents: [ActivityEvent] = []

    // MARK: Computed

    var unreadCount: Int {
        inboxItems.filter { !$0.notification.isRead }.count
    }

    // MARK: Init

    init() {
        let (items, events) = Self.makeSampleData()
        self.inboxItems = items
        self.activityEvents = events
    }

    // MARK: Actions

    func markAsRead(_ id: String) {
        // Stub: would call NotificationPort
    }

    func markAllAsRead() {
        // Stub: would call NotificationPort
    }

    // MARK: - Sample Data

    static func makeSampleData() -> ([InboxItem], [ActivityEvent]) {
        let now = Date()

        let inboxItems: [InboxItem] = [
            InboxItem(
                id: "n-1",
                notification: AnvilDomain.Notification(
                    id: "n-1",
                    title: "PR Review Requested",
                    body: "@marcus requested your review on #482: Refactor exercise session config",
                    source: "github",
                    urgency: .high,
                    isRead: false,
                    url: "https://github.com/hinge-health/exercise-service/pull/482",
                    createdAt: now.addingTimeInterval(-300)
                ),
                source: .pr
            ),
            InboxItem(
                id: "n-2",
                notification: AnvilDomain.Notification(
                    id: "n-2",
                    title: "Deploy Succeeded",
                    body: "exercise-service v2.14.0 deployed to production successfully",
                    source: "deploy",
                    urgency: .normal,
                    isRead: false,
                    url: nil,
                    createdAt: now.addingTimeInterval(-1800)
                ),
                source: .deploy
            ),
            InboxItem(
                id: "n-3",
                notification: AnvilDomain.Notification(
                    id: "n-3",
                    title: "Error Spike Detected",
                    body: "TypeError in ExerciseListController.getAll spiked to 247 occurrences in the last hour",
                    source: "observability",
                    urgency: .critical,
                    isRead: false,
                    url: nil,
                    createdAt: now.addingTimeInterval(-600)
                ),
                source: .error
            ),
            InboxItem(
                id: "n-4",
                notification: AnvilDomain.Notification(
                    id: "n-4",
                    title: "Slack Mention",
                    body: "@allie can you check the session config changes before EOD? - Sarah in #eng-exercise",
                    source: "slack",
                    urgency: .normal,
                    isRead: true,
                    url: nil,
                    createdAt: now.addingTimeInterval(-3600)
                ),
                source: .mention
            ),
            InboxItem(
                id: "n-5",
                notification: AnvilDomain.Notification(
                    id: "n-5",
                    title: "PR Approved",
                    body: "Sarah approved #479: Add daily ET session metrics endpoint",
                    source: "github",
                    urgency: .low,
                    isRead: true,
                    url: "https://github.com/hinge-health/exercise-service/pull/479",
                    createdAt: now.addingTimeInterval(-7200)
                ),
                source: .pr
            ),
        ]

        let activityEvents: [ActivityEvent] = [
            ActivityEvent(id: "a-1", icon: "arrow.triangle.pull", iconColor: AnvilColor.accentPurple, description: "PR #482 opened: Refactor exercise session config", timestamp: now.addingTimeInterval(-300)),
            ActivityEvent(id: "a-2", icon: "shippingbox", iconColor: AnvilColor.accentGreen, description: "exercise-service v2.14.0 deployed to production", timestamp: now.addingTimeInterval(-1800)),
            ActivityEvent(id: "a-3", icon: "exclamationmark.triangle.fill", iconColor: AnvilColor.accentRed, description: "Error spike: TypeError in ExerciseListController (247 occurrences)", timestamp: now.addingTimeInterval(-600)),
            ActivityEvent(id: "a-4", icon: "checkmark.circle.fill", iconColor: AnvilColor.accentGreen, description: "All CI checks passed on PR #482", timestamp: now.addingTimeInterval(-900)),
            ActivityEvent(id: "a-5", icon: "person.fill", iconColor: AnvilColor.accentBlue, description: "Marcus assigned you as reviewer on PR #482", timestamp: now.addingTimeInterval(-360)),
            ActivityEvent(id: "a-6", icon: "arrow.triangle.merge", iconColor: AnvilColor.accentPurple, description: "PR #479 merged: Add daily ET session metrics endpoint", timestamp: now.addingTimeInterval(-5400)),
            ActivityEvent(id: "a-7", icon: "tag", iconColor: AnvilColor.accentAmber, description: "Release v2.14.0 tagged from main (abc123d)", timestamp: now.addingTimeInterval(-2400)),
            ActivityEvent(id: "a-8", icon: "message", iconColor: AnvilColor.accentBlue, description: "New comment on PR #479 from Sarah: 'LGTM, nice work!'", timestamp: now.addingTimeInterval(-7200)),
        ]

        return (inboxItems, activityEvents)
    }
}
