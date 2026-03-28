import SwiftUI

struct ChannelList: View {
    @ObservedObject var viewModel: MessagingViewModel

    var body: some View {
        List {
            Section("Channels") {
                ForEach(viewModel.channels) { channel in
                    channelRow(channel)
                }
            }
            Section("Direct Messages") {
                ForEach(viewModel.directMessages) { channel in
                    channelRow(channel)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack {
                Text("Channels")
                    .font(AnvilFont.subheading)
                Spacer()
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
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(.bar)
        }
    }

    // MARK: - Channel Row

    private func channelRow(_ channel: Channel) -> some View {
        let isSelected = viewModel.selectedChannelId == channel.id
        let hasUnread = channel.unreadCount > 0

        return HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: channel.icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                .frame(width: 16)

            Text(channel.name)
                .font(AnvilFont.sidebarItem)
                .foregroundStyle(hasUnread ? .primary : .secondary)
                .fontWeight(hasUnread ? .medium : .regular)
                .lineLimit(1)

            Spacer()

            if hasUnread {
                Text("\(channel.unreadCount)")
                    .font(AnvilFont.label)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AnvilSpacing.xs)
                    .padding(.vertical, AnvilSpacing.xxxs)
                    .background(AnvilColor.accentBlue)
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectChannel(channel.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hasUnread ? "Unread, " : "")\(channel.name)\(hasUnread ? ", \(channel.unreadCount) unread messages" : "")")
        .accessibilityAddTraits(.isButton)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
    }
}
