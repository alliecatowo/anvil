import SwiftUI
import AnvilDomain
import AnvilGitHub

/// Polls GitHub Notifications API and maps results into the notifications ViewModel.
@MainActor
final class GitHubNotificationPoller: ObservableObject {
    @Published var isPolling = false
    @Published var lastFetchDate: Date?
    @Published var pollError: String?

    private var pollTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 60 // 1 minute

    func start(adapter: GitHubSourceControlCloudAdapter, viewModel: NotificationsViewModel) {
        guard pollTask == nil else { return }
        isPolling = true

        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.fetchOnce(adapter: adapter, viewModel: viewModel)
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval) * 1_000_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    func fetchOnce(adapter: GitHubSourceControlCloudAdapter, viewModel: NotificationsViewModel) async {
        do {
            let notifications = try await adapter.fetchNotifications(since: lastFetchDate)
            lastFetchDate = Date()
            pollError = nil

            let newItems = notifications.map { mapToInboxItem($0) }
            let existingIds = Set(viewModel.inboxItems.map(\.id))
            let fresh = newItems.filter { !existingIds.contains($0.id) }

            if !fresh.isEmpty {
                viewModel.inboxItems.insert(contentsOf: fresh, at: 0)
            }
        } catch {
            pollError = "GitHub notifications: \(error.localizedDescription)"
        }
    }

    private func mapToInboxItem(_ n: GitHubNotification) -> InboxItem {
        let source: NotificationSource
        switch n.type {
        case .pullRequest: source = .pr
        case .issue:       source = .mention
        case .ciCheck:     source = .deploy
        case .release:     source = .deploy
        case .other:       source = .message
        }

        let urgency: NotificationUrgency
        switch n.urgency {
        case .low:      urgency = .low
        case .normal:   urgency = .normal
        case .high:     urgency = .high
        case .critical: urgency = .critical
        }

        let body = "\(n.repoFullName): \(n.reason.replacingOccurrences(of: "_", with: " "))"

        let notification = AnvilDomain.Notification(
            id: "gh-\(n.id)",
            title: n.title,
            body: body,
            source: "github",
            urgency: urgency,
            isRead: !n.unread,
            url: n.url,
            createdAt: n.updatedAt
        )

        return InboxItem(
            id: "gh-\(n.id)",
            notification: notification,
            source: source
        )
    }
}
