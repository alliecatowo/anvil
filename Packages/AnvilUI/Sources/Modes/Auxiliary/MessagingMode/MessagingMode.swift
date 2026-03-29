import SwiftUI

struct MessagingMode: View {
    @ObservedObject var viewModel: MessagingViewModel

    var body: some View {
        Group {
            if viewModel.selectedChannelId == nil {
                AnvilEmptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "No chat selected",
                    message: "Choose a channel from the sidebar to start chatting."
                )
            } else {
                ChatView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !viewModel.providerOptions.isEmpty {
                    Picker("Chat Provider", selection: Binding(
                        get: { viewModel.selectedProviderId ?? "" },
                        set: { viewModel.selectProvider($0) }
                    )) {
                        ForEach(viewModel.providerOptions) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .help("Select active chat provider")
                }
            }
        }
        .onAppear {
            if viewModel.selectedChannelId == nil {
                if let channel = viewModel.channels.first {
                    viewModel.selectChannel(channel.id)
                } else if let dm = viewModel.directMessages.first {
                    viewModel.selectChannel(dm.id)
                }
            }
        }
        .background(.background)
        .accessibilityLabel("Chat")
    }
}
