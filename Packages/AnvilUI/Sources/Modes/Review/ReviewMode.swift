import SwiftUI
import AnvilDomain

struct ReviewMode: View {
    @StateObject private var viewModel = ReviewViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            ReviewSidebar(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Main content area
            if viewModel.selectedReview != nil {
                DiffReviewView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ReviewInboxView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }
}
