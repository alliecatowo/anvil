import SwiftUI

struct MessagingMode: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel = MessagingViewModel()

    var body: some View {
        NavigationSplitView {
            ChannelList(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            ChatView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !viewModel.providerOptions.isEmpty {
                    Picker("Messaging Provider", selection: Binding(
                        get: { viewModel.selectedProviderId ?? "" },
                        set: { viewModel.selectProvider($0) }
                    )) {
                        ForEach(viewModel.providerOptions) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .help("Select active messaging provider")
                }
            }
        }
        .task {
            let providers = container.availableMessagingProviderIds
                .compactMap { container.messagingAdapter(for: $0) }
            if providers.isEmpty {
                viewModel.configure(messagingPort: container.messagingService)
            } else {
                viewModel.configure(providers: providers, activeProviderId: container.activeMessagingProviderId)
            }
        }
        .onChange(of: container.activeMessagingProviderId) { _, newValue in
            guard let newValue else { return }
            viewModel.selectProvider(newValue)
        }
        .navigationSplitViewStyle(.balanced)
        .background(.background)
        .accessibilityLabel("Messaging")
    }
}
