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
            case .testing:
                TestingMode()
            case .extensions:
                PluginMarketplaceMode()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnvilColor.backgroundPrimary)
    }
}

// MARK: - Mode Content Wrappers (using shared ViewModels)

struct IntentModeContent: View {
    @ObservedObject var viewModel: IntentViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if viewModel.tickets.isEmpty {
            AnvilEmptyState(
                icon: "target",
                title: "No tickets yet",
                message: "Create a ticket or connect a project tracker.",
                actions: [
                    EmptyStateAction("Create Ticket", icon: "plus", style: .primary) {
                        viewModel.isCreatingTicket = true
                    },
                    EmptyStateAction("Load Demo Data", icon: "tray.and.arrow.down", style: .secondary) {
                        appState.loadDemoData()
                    }
                ]
            )
        } else if viewModel.selectedTicket != nil {
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
        switch viewModel.viewMode {
        case .dashboard:
            SessionDashboard(
                viewModel: viewModel,
                onCreateSynthesis: { sessionIds in
                    _ = viewModel.createSynthesisRoom(sessionIds: sessionIds)
                },
                onDispatchCritique: { sessionId in
                    viewModel.dispatchCritiqueAgent(for: sessionId)
                }
            )

        case .synthesisRoom(let roomId):
            SynthesisRoomView(
                viewModel: viewModel,
                roomId: roomId,
                onRunSynthesis: {
                    viewModel.runSynthesis(roomId: roomId, container: container, appState: appState)
                }
            )

        case .conversation:
            if let session = viewModel.selectedSession {
                ConversationView(
                    session: session,
                    inputText: $viewModel.inputText,
                    selectedModelId: $viewModel.selectedModelId,
                    editSuggestions: viewModel.suggestionsForCurrentSession(),
                    queuedCount: viewModel.queuedMessages.count,
                    onSend: {
                        viewModel.sendMessage(container: container, appState: appState)
                    },
                    onRename: { name in
                        viewModel.renameSession(session.id, name: name)
                    },
                    onDelete: {
                        viewModel.deleteSession(session.id)
                    },
                    onExport: {
                        viewModel.exportSessionToClipboard(session.id)
                    },
                    onExportFile: { format in
                        viewModel.exportSessionToFile(session.id, format: format)
                    },
                    onAcceptHunk: { sugId, hunkId in
                        viewModel.acceptHunk(suggestionId: sugId, hunkId: hunkId)
                    },
                    onRejectHunk: { sugId, hunkId in
                        viewModel.rejectHunk(suggestionId: sugId, hunkId: hunkId)
                    },
                    onAcceptAll: { sugId in
                        viewModel.acceptAllHunks(suggestionId: sugId)
                    },
                    onRejectAll: { sugId in
                        viewModel.rejectAllHunks(suggestionId: sugId)
                    },
                    attachments: viewModel.contextAttachments,
                    onRemoveAttachment: { id in
                        viewModel.removeAttachment(id: id)
                    },
                    onAddAttachment: { attachment in
                        viewModel.addAttachment(attachment)
                    },
                    onSetBudget: { budget, hardStop in
                        viewModel.setSessionBudget(session.id, budget: budget, hardStop: hardStop)
                    },
                    onSetAutonomy: { level in
                        viewModel.setAutonomyLevel(session.id, level: level)
                    },
                    guardrailCount: viewModel.guardrails.protectedFiles.count + viewModel.guardrails.blockedCommands.count,
                    pendingApproval: viewModel.pendingToolApproval,
                    onApproveToolCall: { remember in
                        viewModel.approveToolCall(remember: remember)
                    },
                    onRejectToolCall: { remember in
                        viewModel.rejectToolCall(remember: remember)
                    }
                )
            } else {
                AgentEmptyState(onNewSession: { viewModel.isLaunchSheetPresented = true })
            }
        }
    }
}

struct ReviewModeContent: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        if viewModel.isCommitGraphVisible {
            GitGraphContainerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appState.gitHubPRViewModel.selectedPR != nil {
            GitHubPRDetailView(viewModel: appState.gitHubPRViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.reviews.isEmpty {
            AnvilEmptyState(
                icon: "checkmark.circle",
                title: "Review inbox is empty",
                message: "Nothing to review right now."
            )
        } else if viewModel.selectedReview != nil {
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
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if viewModel.environments.isEmpty {
            AnvilEmptyState(
                icon: "shippingbox",
                title: "No deployments configured",
                message: "Connect a hosting provider to deploy.",
                actions: [
                    EmptyStateAction("Configure Provider", icon: "gearshape", style: .primary) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    },
                    EmptyStateAction("Load Demo Data", icon: "tray.and.arrow.down", style: .secondary) {
                        appState.loadDemoData()
                    }
                ]
            )
        } else {
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
}

struct PlaceholderModeContent: View {
    let mode: AnvilMode

    var body: some View {
        AnvilEmptyState(
            icon: mode.icon,
            title: mode.rawValue,
            message: "Coming soon."
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
