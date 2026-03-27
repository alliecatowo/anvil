import SwiftUI

public struct Sidebar: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if appState.isSidebarCollapsed {
                CollapsedSidebar()
            } else {
                // Delegate to mode-specific sidebar
                switch appState.currentMode {
                case .agent:
                    AgentSidebar(viewModel: appState.agentViewModel)
                case .intent:
                    IntentSidebar(viewModel: appState.intentViewModel)
                case .review:
                    ReviewSidebar(viewModel: appState.reviewViewModel)
                case .ship:
                    ShipSidebar(viewModel: appState.shipViewModel)
                default:
                    GenericSidebar(mode: appState.currentMode)
                }
            }
        }
        .background(AnvilColor.backgroundSecondary)
    }
}

struct CollapsedSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: AnvilSpacing.sm) {
            // Show mode icon as expand button
            Button {
                appState.isSidebarCollapsed = false
            } label: {
                Image(systemName: appState.currentMode.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AnvilColor.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help(appState.currentMode.rawValue)

            Spacer()
        }
        .padding(.top, AnvilSpacing.sm)
    }
}

struct GenericSidebar: View {
    let mode: AnvilMode

    var body: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Spacer()
            Image(systemName: mode.icon)
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)
            Text(mode.rawValue)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
