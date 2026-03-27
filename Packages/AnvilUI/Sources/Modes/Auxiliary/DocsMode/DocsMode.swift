import SwiftUI

struct DocsMode: View {
    @StateObject private var viewModel = DocsViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Left: Document browser
            DocBrowser(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Right: Document editor with split preview
            DocEditor(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
    }
}
