import SwiftUI

struct MessagingMode: View {
    @StateObject private var viewModel = MessagingViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Left: Channel list
            ChannelList(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Right: Chat view
            ChatView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
    }
}
