import SwiftUI

struct OperateSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            SidebarTabBar(
                sections: Array(AppState.OperateSection.allCases),
                active: appState.operateActiveSection,
                icon: { $0.icon },
                label: { $0.rawValue },
                onSelect: { appState.operateActiveSection = $0 }
            )

            Divider()

            switch appState.operateActiveSection {
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
