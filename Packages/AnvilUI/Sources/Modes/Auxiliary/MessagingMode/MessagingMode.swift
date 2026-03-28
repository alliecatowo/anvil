import SwiftUI

struct MessagingMode: View {
    @StateObject private var viewModel = MessagingViewModel()

    var body: some View {
        NavigationSplitView {
            ChannelList(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            ChatView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .background(.background)
        .accessibilityLabel("Messaging")
    }
}
