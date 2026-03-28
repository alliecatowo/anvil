import SwiftUI
import AnvilDomain
import AnvilApplication

struct NotificationsMode: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @StateObject private var preferences = NotificationPreferences.shared
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        HStack(spacing: 0) {
            // Left panel: tab selector + list
            VStack(spacing: 0) {
                tabSelector
                Divider().overlay(AnvilColor.borderSubtle)

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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
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

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(NotificationsTab.allCases, id: \.rawValue) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    HStack(spacing: AnvilSpacing.xs) {
                        if tab == .preferences {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11))
                        }

                        Text(tab.rawValue)
                            .font(AnvilFont.label)
                            .foregroundStyle(
                                viewModel.selectedTab == tab
                                    ? AnvilColor.textPrimary
                                    : AnvilColor.textTertiary
                            )

                        if tab == .inbox && viewModel.unreadCount > 0 {
                            AnvilBadge(
                                text: "\(viewModel.unreadCount)",
                                color: AnvilColor.accentBlue
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AnvilSpacing.sm)
                    .background(
                        viewModel.selectedTab == tab
                            ? AnvilColor.backgroundTertiary
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xs)
    }
}
