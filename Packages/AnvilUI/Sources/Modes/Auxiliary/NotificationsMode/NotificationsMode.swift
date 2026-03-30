import SwiftUI
import AnvilDomain
import AnvilApplication

struct NotificationsMode: View {
    @StateObject private var preferences = NotificationPreferences.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    private var viewModel: NotificationsViewModel {
        appState.notificationsViewModel
    }

    var body: some View {
        Group {
            switch viewModel.selectedTab {
            case .inbox:
                InboxView(viewModel: viewModel)
            case .activity:
                ActivityFeedView(viewModel: viewModel)
            case .preferences:
                NotificationPreferencesView(preferences: preferences)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .accessibilityLabel("Notifications")
        .onAppear {
            if let adapter = container.getOrCreateGitHubAdapter() {
                viewModel.startGitHubPolling(adapter: adapter)
            }
            // Load sample data so the inbox isn't empty when no GitHub token is configured
            if viewModel.inboxItems.isEmpty {
                viewModel.loadSampleData()
            }
        }
        .onDisappear {
            viewModel.stopGitHubPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .anvilMarkNotificationRead)) { notification in
            if let notifId = notification.userInfo?["notificationId"] as? String {
                viewModel.markAsRead(notifId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .anvilNavigateToItem)) { notification in
            if let itemId = notification.userInfo?["itemId"] as? String {
                viewModel.selectedTab = .inbox
                viewModel.selectedItemID = itemId
            }
        }
    }
}
