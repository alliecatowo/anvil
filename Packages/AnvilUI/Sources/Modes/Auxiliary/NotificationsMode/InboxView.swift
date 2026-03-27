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
            // Toolbar
            toolbar

            Divider().overlay(AnvilColor.borderSubtle)

            // Items
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.inboxItems) { item in
                        inboxRow(item)
                        Divider().overlay(AnvilColor.borderSubtle)
                    }
                }
            }

            // Keyboard hints
            keyboardHints
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Inbox")
                .font(AnvilFont.subheading)
                .foregroundStyle(AnvilColor.textPrimary)

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
        .background(viewModel.selectedItemID == item.id ? AnvilColor.selectionBackground : .clear)
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
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.textSecondary)
                .frame(width: 24, height: 24)
                .background(AnvilColor.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(label)
    }

    // MARK: - Keyboard Hints

    private var keyboardHints: some View {
        HStack(spacing: AnvilSpacing.lg) {
            keyHint(key: "j", label: "next")
            keyHint(key: "k", label: "prev")
            keyHint(key: "e", label: "archive")
            keyHint(key: "enter", label: "open")
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary)
    }

    private func keyHint(key: String, label: String) -> some View {
        HStack(spacing: AnvilSpacing.xxs) {
            Text(key)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .padding(.horizontal, AnvilSpacing.xxs)
                .padding(.vertical, 1)
                .background(AnvilColor.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(AnvilColor.borderMedium, lineWidth: 1)
                )

            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
    }
}
