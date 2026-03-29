import SwiftUI

struct ChannelList: View {
    @ObservedObject var viewModel: MessagingViewModel

    var body: some View {
        VStack(spacing: 0) {
            AnvilSidebarHeaderRow(
                title: "Messaging",
                icon: "bubble.left.and.bubble.right",
                count: viewModel.channels.count + viewModel.directMessages.count
            ) {
                Button {
                    // Channel creation is intentionally unavailable until backend support exists.
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(true)
                .help("Create Channel (coming when provider API supports channel creation)")
            }

            Divider()

            List {
                AnvilSidebarSection(title: "Channels", icon: "number", count: viewModel.channels.count) {
                    ForEach(viewModel.channels) { channel in
                        channelRow(channel)
                    }
                }

                AnvilSidebarSection(title: "Direct Messages", icon: "person.2", count: viewModel.directMessages.count) {
                    ForEach(viewModel.directMessages) { channel in
                        channelRow(channel)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Channel Row

    private func channelRow(_ channel: Channel) -> some View {
        let isSelected = viewModel.selectedChannelId == channel.id
        let hasUnread = channel.unreadCount > 0

        return Button {
            viewModel.selectChannel(channel.id)
        } label: {
            AnvilListItem(
                icon: channel.icon,
                title: channel.name,
                subtitle: hasUnread ? "\(channel.unreadCount) unread messages" : nil,
                tag: hasUnread ? "\(channel.unreadCount)" : nil,
                tagColor: AnvilColor.accentBlue,
                isSelected: isSelected,
                isCompact: false
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hasUnread ? "Unread, " : "")\(channel.name)\(hasUnread ? ", \(channel.unreadCount) unread messages" : "")")
        .accessibilityAddTraits(.isButton)
    }
}
