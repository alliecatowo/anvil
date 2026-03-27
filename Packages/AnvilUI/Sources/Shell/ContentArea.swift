import SwiftUI

public struct ContentArea: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        ZStack {
            switch appState.currentMode {
            case .intent:
                IntentModeContent(viewModel: appState.intentViewModel)
            case .agent:
                AgentModeContent(viewModel: appState.agentViewModel)
            case .review:
                ReviewModeContent(viewModel: appState.reviewViewModel)
            case .ship:
                ShipModeContent(viewModel: appState.shipViewModel)
            case .editor:
                EditorMode()
            case .database:
                DatabaseMode()
            case .terminal:
                TerminalMode()
            case .docs:
                DocsMode()
            case .messaging:
                MessagingMode()
            case .notifications:
                NotificationsMode()
            default:
                PlaceholderModeContent(mode: appState.currentMode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnvilColor.backgroundPrimary)
    }
}

// MARK: - Mode Content Wrappers (using shared ViewModels)

struct IntentModeContent: View {
    @ObservedObject var viewModel: IntentViewModel

    var body: some View {
        if viewModel.selectedTicket != nil {
            TicketDetailView(viewModel: viewModel)
        } else if viewModel.viewMode == .board {
            BoardView(viewModel: viewModel)
        } else {
            TicketListView(viewModel: viewModel)
        }
    }
}

struct AgentModeContent: View {
    @ObservedObject var viewModel: AgentViewModel
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appState: AppState

    var body: some View {
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

struct ReviewModeContent: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        if viewModel.selectedReview != nil {
            DiffReviewView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ReviewInboxView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ShipModeContent: View {
    @ObservedObject var viewModel: ShipViewModel

    var body: some View {
        Group {
            switch viewModel.selectedTab {
            case .dashboard:
                DeployDashboardView(viewModel: viewModel)
            case .logs:
                BuildLogView(viewModel: viewModel)
            case .envVars:
                EnvVarManagerView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlaceholderModeContent: View {
    let mode: AnvilMode

    var body: some View {
        ModeWelcomeView(
            icon: mode.icon,
            title: mode.rawValue,
            subtitle: "Coming soon.",
            hint: ""
        )
    }
}

struct ModeWelcomeView: View {
    let icon: String
    let title: String
    let subtitle: String
    let hint: String

    var body: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)

            Text(title)
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            Text(subtitle)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)

            if !hint.isEmpty {
                Text(hint)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(.top, AnvilSpacing.sm)
            }
        }
    }
}
