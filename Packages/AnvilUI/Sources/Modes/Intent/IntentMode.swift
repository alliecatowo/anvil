import SwiftUI
import AnvilDomain

struct IntentMode: View {
    @StateObject private var viewModel = IntentViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Mode-local sidebar
            IntentSidebar(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Main content
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.selectedTicket != nil {
            TicketDetailView(viewModel: viewModel)
        } else if viewModel.viewMode == .board {
            BoardView(viewModel: viewModel)
        } else {
            TicketListView(viewModel: viewModel)
        }
    }
}
