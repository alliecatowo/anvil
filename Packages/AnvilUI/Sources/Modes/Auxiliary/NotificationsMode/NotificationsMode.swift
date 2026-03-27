import SwiftUI
import AnvilDomain

struct NotificationsMode: View {
    @StateObject private var viewModel = NotificationsViewModel()

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
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(NotificationsTab.allCases, id: \.rawValue) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    HStack(spacing: AnvilSpacing.xs) {
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
