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
        AnvilEmptyState(
            icon: "cpu",
            title: "Start an AI session",
            message: "Send a task to an AI agent and watch it work.",
            actions: [
                EmptyStateAction("New Session", icon: "plus", style: .primary, action: onNewSession),
                EmptyStateAction("Configure Provider", icon: "gearshape", style: .secondary) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            ]
        )
    }
}
