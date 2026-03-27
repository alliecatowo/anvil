import SwiftUI

struct ChannelList: View {
    @ObservedObject var viewModel: MessagingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CHANNELS")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .tracking(0.3)

                Spacer()

                Button {
                    // Add channel
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            ScrollView {
                LazyVStack(spacing: 0) {
                    // Channels section
                    sectionHeader("Channels")

                    ForEach(viewModel.channels) { channel in
                        channelRow(channel)
                    }

                    // DMs section
                    sectionHeader("Direct Messages")

                    ForEach(viewModel.directMessages) { channel in
                        channelRow(channel)
                    }
                }
                .padding(.vertical, AnvilSpacing.xxs)
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)
            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.top, AnvilSpacing.md)
        .padding(.bottom, AnvilSpacing.xxs)
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
                .foregroundStyle(hasUnread ? AnvilColor.textPrimary : (isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary))
                .fontWeight(hasUnread ? .medium : .regular)
                .lineLimit(1)

            Spacer()

            if hasUnread {
                Text("\(channel.unreadCount)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.backgroundPrimary)
                    .padding(.horizontal, AnvilSpacing.xs)
                    .padding(.vertical, AnvilSpacing.xxxs)
                    .background(AnvilColor.accentBlue)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: 28)
        .background(isSelected ? AnvilColor.selectionBackground : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectChannel(channel.id)
        }
    }
}
