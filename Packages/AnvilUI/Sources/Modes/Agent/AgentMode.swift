import SwiftUI
import AnvilDomain

public struct AgentMode: View {
    @StateObject private var viewModel = AgentViewModel()
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        if let session = viewModel.selectedSession {
            ConversationView(
                session: session,
                inputText: $viewModel.inputText,
                onSend: {
                    viewModel.sendMessage(container: container, appState: appState)
                }
            )
        } else {
            AgentEmptyState(onNewSession: { viewModel.isLaunchSheetPresented = true })
        }
    }
}

struct AgentEmptyState: View {
    let onNewSession: () -> Void

    var body: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Image(systemName: "cpu")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AnvilColor.accentPurple.opacity(0.5))

            Text("Agent Mode")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            Text("Start an AI-powered development session")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)

            AnvilButton("New Session", icon: "plus", style: .primary, action: onNewSession)
                .padding(.top, AnvilSpacing.sm)

            Text("\u{2318}\u{21E7}A")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
    }
}
