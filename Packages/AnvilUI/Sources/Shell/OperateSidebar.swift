import SwiftUI

struct OperateSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.operateActiveSource {
            case .deploy:
                ShipSidebar(viewModel: appState.shipViewModel)
            case .monitor:
                monitorEmptyState
            }
        }
    }

    private var monitorEmptyState: some View {
        AnvilSidebarEmptyState(
            icon: "chart.line.uptrend.xyaxis",
            title: "No monitors configured",
            message: "Observability monitors will appear here when configured."
        )
    }
}
