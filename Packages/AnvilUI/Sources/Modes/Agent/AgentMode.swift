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

            Text("Start an AI session")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            Text("Send a task to an AI agent and watch it work.")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: AnvilSpacing.sm) {
                AnvilButton("New Session", icon: "plus", style: .primary, action: onNewSession)

                SettingsLink {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                        Text("Configure Provider")
                            .font(AnvilFont.body)
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AnvilColor.borderMedium, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, AnvilSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
