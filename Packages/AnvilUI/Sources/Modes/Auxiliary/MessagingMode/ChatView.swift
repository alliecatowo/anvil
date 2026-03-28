import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: MessagingViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let channel = viewModel.selectedChannel {
                // Channel header
                channelHeader(channel)

                Divider().overlay(AnvilColor.borderSubtle)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: AnvilSpacing.md) {
                            ForEach(viewModel.messages) { message in
                                messageRow(message)
                                    .id(message.id)
                            }
                        }
                        .padding(AnvilSpacing.md)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }

                Divider().overlay(AnvilColor.borderSubtle)

                // Message input
                messageInput(channel)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Channel Header

    private func channelHeader(_ channel: Channel) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: channel.icon)
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.textTertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(channel.name)
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)

                if !channel.topic.isEmpty {
                    Text(channel.topic)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if channel.memberCount > 0 {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "person.2")
                        .font(.system(size: 11))
                    Text("\(channel.memberCount)")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Message Row

    private func messageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: AnvilSpacing.sm) {
            // Avatar
            Circle()
                .fill(message.avatarColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(message.author.prefix(1)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AnvilColor.textPrimary)
                )

            VStack(alignment: .leading, spacing: AnvilSpacing.xxxs) {
                HStack(spacing: AnvilSpacing.sm) {
                    Text(message.author)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AnvilColor.textPrimary)

                    Text(message.formattedTime)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                Text(message.content)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .textSelection(.enabled)
            }

            Spacer()
        }
    }

    // MARK: - Message Input

    private func messageInput(_ channel: Channel) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            TextField("Message #\(channel.name)", text: $viewModel.inputText)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
                .textFieldStyle(.plain)
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        viewModel.inputText.isEmpty
                            ? AnvilColor.textTertiary
                            : AnvilColor.accentBlue
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.inputText.isEmpty)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))

            Text("Select a channel to start chatting")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnvilColor.backgroundPrimary)
    }
}
