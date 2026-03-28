import SwiftUI
import AppKit
import AnvilDomain

struct InboxView: View {
    @ObservedObject var viewModel: NotificationsViewModel
    @EnvironmentObject var appState: AppState
    @State private var hoveredItemID: String?

    private let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            List {
                ForEach(viewModel.filteredInboxItems) { item in
                    inboxRow(item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Inbox")
                    .font(AnvilFont.subheading)

                if viewModel.unreadCount > 0 {
                    AnvilBadge(
                        text: "\(viewModel.unreadCount) unread",
                        color: AnvilColor.accentBlue
                    )
                }

                Spacer()

                AnvilButton("Mark All Read", icon: "checkmark", style: .ghost) {
                    viewModel.markAllAsRead()
                }
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.vertical, AnvilSpacing.sm)
            HStack {
                Picker("Source", selection: $viewModel.sourceFilter) {
                    ForEach(NotificationsViewModel.NotificationSourceFilter.allCases, id: \.rawValue) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.bottom, AnvilSpacing.sm)
        }
        .background(.bar)
    }

    // MARK: - Inbox Row

    private func inboxRow(_ item: InboxItem) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Unread indicator
            Circle()
                .fill(item.notification.isRead ? Color.clear : AnvilColor.accentBlue)
                .frame(width: 8, height: 8)

            // Source icon
            Image(systemName: item.source.icon)
                .font(.system(size: 14))
                .foregroundStyle(item.source.color)
                .frame(width: 24, height: 24)
                .background(item.source.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Priority indicator
            if item.notification.urgency == .critical || item.notification.urgency == .high {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(
                        item.notification.urgency == .critical
                            ? AnvilColor.accentRed
                            : AnvilColor.accentAmber
                    )
            }

            // Content
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                Text(item.notification.title)
                    .font(AnvilFont.sidebarItem)
                    .fontWeight(item.notification.isRead ? .regular : .medium)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text(item.notification.body)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons (visible on hover) or timestamp
            if hoveredItemID == item.id {
                actionButtons(for: item)
            } else {
                Text(timeFormatter.localizedString(for: item.notification.createdAt, relativeTo: .now))
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.md)
        .background(viewModel.selectedItemID == item.id ? Color.accentColor.opacity(0.14) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered in
            hoveredItemID = isHovered ? item.id : nil
        }
        .onTapGesture {
            viewModel.selectedItemID = item.id
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(for item: InboxItem) -> some View {
        HStack(spacing: AnvilSpacing.xs) {
            // Source-specific actions
            switch item.source {
            case .pr:
                actionButton(icon: "eye", label: "View PR") {
                    viewModel.openNotificationItem(item, appState: appState)
                }
                actionButton(icon: "checkmark.circle", label: "Approve") {
                    viewModel.approvePR(for: item)
                }

            case .deploy:
                actionButton(icon: "doc.text.magnifyingglass", label: "View Logs") {
                    viewModel.openNotificationItem(item, appState: appState)
                }

            case .error:
                actionButton(icon: "exclamationmark.magnifyingglass", label: "View Error") {
                    viewModel.openNotificationItem(item, appState: appState)
                }

            case .message, .mention:
                actionButton(icon: "arrowshape.turn.up.left", label: "Reply") {
                    viewModel.openNotificationItem(item, appState: appState)
                }
            }

            // Mark as read (all types)
            if !item.notification.isRead {
                actionButton(icon: "checkmark", label: "Mark Read") {
                    viewModel.markAsRead(item.id)
                }
            }

            // Dismiss
            actionButton(icon: "xmark", label: "Dismiss") {
                viewModel.dismissNotification(item.id)
            }
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.textSecondary)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .help(label)
    }

}
