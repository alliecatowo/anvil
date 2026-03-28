import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: MessagingViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let channel = viewModel.selectedChannel {
                channelHeader(channel)
                Divider()

                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .id(message.id)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }

                Divider()

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

                if !channel.topic.isEmpty {
                    Text(channel.topic)
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(.bar)
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

                    Text(message.formattedTime)
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .font(AnvilFont.body)
                    .foregroundStyle(.secondary)
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
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button("Send", systemImage: "paperplane.fill") {
                viewModel.sendMessage()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(viewModel.inputText.isEmpty)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(.bar)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))

            Text("Select a channel to start chatting")
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
