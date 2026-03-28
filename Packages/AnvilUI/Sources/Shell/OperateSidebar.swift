import SwiftUI

struct OperateSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $appState.operateActiveSection) {
                ForEach(AppState.OperateSection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Operate Sidebar Section")
            .accessibilityAddTraits(.isButton)
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)

            Divider()

            switch appState.operateActiveSection {
            case .deploy:
                ShipSidebar(viewModel: appState.shipViewModel)
            case .monitor:
                Text("No monitors configured")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
