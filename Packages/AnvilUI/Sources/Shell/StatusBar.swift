import SwiftUI

public struct StatusBar: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        HStack(spacing: AnvilSpacing.md) {
            // Left: Branch + source control
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                Text(appState.currentBranch)
                    .font(AnvilFont.statusBar)
            }
            .foregroundStyle(AnvilColor.textSecondary)

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
