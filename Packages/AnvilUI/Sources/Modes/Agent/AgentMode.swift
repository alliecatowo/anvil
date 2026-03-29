import SwiftUI
import AnvilDomain

public struct AgentMode: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    public init() {}

    public var body: some View {
        AgentModeContent(viewModel: appState.agentViewModel)
    }
}

struct AgentEmptyState: View {
    let onNewSession: @MainActor @Sendable () -> Void

    var body: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Image(systemName: "cpu")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)
                .accessibilityHidden(true)

            Text("Start an AI session")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            Text("Send a task to an AI agent and watch it work.")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: AnvilSpacing.sm) {
                Button(action: onNewSession) {
                    Label("New Session", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel("New Session")
                .accessibilityIdentifier("agent.empty.new-session")
                .accessibilityAddTraits(.isButton)

                SettingsLink {
                    Label("Configure Provider", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel("Configure Provider")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.top, AnvilSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
