import SwiftUI
import AnvilDomain

struct ShipMode: View {
    @StateObject private var viewModel = ShipViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            ShipSidebar(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Main content area
            Group {
                switch viewModel.selectedTab {
                case .dashboard:
                    DeployDashboardView(viewModel: viewModel)
                case .logs:
                    BuildLogView(viewModel: viewModel)
                case .envVars:
                    EnvVarManagerView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
    }
}
