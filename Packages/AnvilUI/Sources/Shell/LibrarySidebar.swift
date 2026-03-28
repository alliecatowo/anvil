import SwiftUI

struct LibrarySidebar: View {
    @EnvironmentObject var appState: AppState

    enum LibrarySection: String, CaseIterable {
        case docs = "Docs"
        case extensions = "Extensions"
        case notifications = "Inbox"
    }

    @State private var activeSection: LibrarySection = .docs

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $activeSection) {
                ForEach(LibrarySection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)

            Divider()

            switch activeSection {
            case .docs:
                DocBrowser(viewModel: appState.libraryDocsViewModel)
            case .extensions:
                Text("No extensions installed")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notifications:
                notificationsList
            }
        }
    }

    // MARK: - Compact Notifications List

    private var notificationsList: some View {
        let viewModel = appState.notificationsViewModel
        return Group {
            if viewModel.inboxItems.isEmpty {
                Text("No notifications")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.inboxItems) { item in
                        HStack(spacing: AnvilSpacing.sm) {
                            Circle()
                                .fill(item.notification.isRead ? Color.clear : AnvilColor.accentBlue)
                                .frame(width: 6, height: 6)

                            Image(systemName: item.source.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(item.source.color)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.notification.title)
                                    .font(AnvilFont.sidebarItem)
                                    .foregroundStyle(AnvilColor.textPrimary)
                                    .lineLimit(1)

                                Text(item.notification.body)
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.vertical, AnvilSpacing.xxs)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedItemID = item.id
                            viewModel.markAsRead(item.id)
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 8))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}
