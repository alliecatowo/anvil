import SwiftUI
import AnvilApplication

public struct StatusBar: View {
    @EnvironmentObject var appState: AppState
    @State private var isBranchPickerVisible = false

    public init() {}

    public var body: some View {
        HStack(spacing: AnvilSpacing.md) {
            // Left: Project name (click to switch)
            Button {
                appState.toggleProjectSwitcher()
            } label: {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                    Text(appState.currentProject?.name ?? "No Project")
                        .font(AnvilFont.statusBar)
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Switch Project (\u{2318}\u{21E7}O)")

            Divider()
                .frame(height: 12)
                .overlay(AnvilColor.borderSubtle)

            // Branch + source control (clickable for branch picker)
            Button {
                isBranchPickerVisible.toggle()
            } label: {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text(appState.currentBranch)
                        .font(AnvilFont.statusBar)

                    if appState.uncommittedFileCount > 0 {
                        Text("\(appState.uncommittedFileCount)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .medium))
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Switch Branch")
            .popover(isPresented: $isBranchPickerVisible, arrowEdge: .top) {
                BranchPicker(isPresented: $isBranchPickerVisible)
            }

            Divider()
                .frame(height: 12)
                .overlay(AnvilColor.borderSubtle)

            Spacer()

            // Center: Agent status
            HStack(spacing: AnvilSpacing.xs) {
                Circle()
                    .fill(agentStatusColor)
                    .frame(width: 6, height: 6)
                Text(appState.agentStatus)
                    .font(AnvilFont.statusBar)
            }
            .foregroundStyle(AnvilColor.textSecondary)

            Spacer()

            Divider()
                .frame(height: 12)
                .overlay(AnvilColor.borderSubtle)

            // Right: Cost + time
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 10))
                Text(formatCost(appState.sessionCost))
                    .font(AnvilFont.statusBar)
                Text("/")
                    .foregroundStyle(AnvilColor.textTertiary)
                Text(formatCost(appState.todayCost))
                    .font(AnvilFont.statusBar)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .foregroundStyle(AnvilColor.textSecondary)

            Divider()
                .frame(height: 12)
                .overlay(AnvilColor.borderSubtle)

            // Settings gear
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: AnvilSpacing.statusBarHeight)
        .background(AnvilColor.backgroundSecondary)
    }

    private var agentStatusColor: Color {
        switch appState.agentStatus {
        case "Running": AnvilColor.accentGreen
        case "Error": AnvilColor.accentRed
        default: AnvilColor.textTertiary
        }
    }

    private func formatCost(_ cost: Decimal) -> String {
        "$\(NSDecimalNumber(decimal: cost).doubleValue.formatted(.number.precision(.fractionLength(2))))"
    }
}
