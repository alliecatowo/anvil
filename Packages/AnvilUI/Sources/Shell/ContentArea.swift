import SwiftUI
import AnvilDomain

public struct ContentArea: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        ZStack {
            switch appState.currentSpace {
            case .plan:
                IntentModeContent(viewModel: appState.intentViewModel)
                    .transition(.opacity)
            case .build:
                BuildContent()
                    .transition(.opacity)
            case .review:
                ReviewModeContent(viewModel: appState.reviewViewModel)
                    .transition(.opacity)
            case .operate:
                OperateContent()
                    .transition(.opacity)
            case .library:
                LibraryContent()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: appState.currentSpace)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        } else if viewModel.isShowingTicketDetailInMainPane, viewModel.selectedTicket != nil {
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

    @State private var showAutoPRSheet = false
    @State private var cachedProjectFiles: [String] = []
    @State private var autoContextDebounce: Task<Void, Never>?

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
                    onModelChange: { modelId in
                        viewModel.updateSessionModel(session.id, modelId: modelId)
                    },
                    guardrailCount: viewModel.guardrails.protectedFiles.count + viewModel.guardrails.blockedCommands.count,
                    pendingApproval: viewModel.pendingToolApproval,
                    onApproveToolCall: { remember in
                        viewModel.approveToolCall(remember: remember)
                    },
                    onRejectToolCall: { remember in
                        viewModel.rejectToolCall(remember: remember)
                    },
                    onCreatePR: {
                        showAutoPRSheet = true
                    },
                    plan: session.plan,
                    onApprovePlan: {
                        viewModel.approvePlan(sessionId: session.id)
                    },
                    onCancelPlan: {
                        viewModel.cancelPlan(sessionId: session.id)
                    },
                    onSkipPlanStep: { stepId in
                        viewModel.skipPlanStep(sessionId: session.id, stepId: stepId)
                    },
                    onAnnotatePlanStep: { stepId, text in
                        viewModel.annotatePlanStep(sessionId: session.id, stepId: stepId, annotation: text)
                    },
                    onReorderPlanStep: { stepId, newOrder in
                        viewModel.reorderPlanStep(sessionId: session.id, stepId: stepId, newOrder: newOrder)
                    },
                    onAddPlanStep: { title, afterId in
                        viewModel.addPlanStep(sessionId: session.id, title: title, afterStepId: afterId)
                    },
                    onRemovePlanStep: { stepId in
                        viewModel.removePlanStep(sessionId: session.id, stepId: stepId)
                    },
                    onSendToBackground: {
                        viewModel.sendToBackground(session.id)
                    },
                    onToggleAgentPanel: {
                        appState.toggleAgentPanel()
                    },
                    isAgentPanelVisible: appState.isAgentPanelVisible,
                    autoContextFiles: appState.autoContextService.suggestions.map { file in
                        AutoContextChipData(id: file.id, path: file.path, name: file.name, reason: file.reason.rawValue)
                    },
                    onDismissAutoContext: { path in
                        appState.autoContextService.dismiss(path)
                    },
                    onAcceptAutoContext: { path in
                        viewModel.addAttachment(.file(path: path))
                        appState.autoContextService.dismiss(path)
                    },
                    contextResolver: ContextSlashResolver(
                        resolveTab: { [weak appState] in
                            guard let file = appState?.editorViewModel.selectedFile else { return nil }
                            return .file(path: file.path)
                        },
                        resolveSelection: { [weak appState] in
                            guard let vm = appState?.editorViewModel,
                                  let file = vm.selectedFile else { return nil }
                            // Use cursor position as a single-line selection if no multi-line selection
                            let lines = file.content.components(separatedBy: "\n")
                            let line = vm.cursorLine
                            guard line > 0, line <= lines.count else { return nil }
                            let preview = lines[line - 1]
                            return .codeSelection(filePath: file.path, startLine: line, endLine: line, preview: preview)
                        },
                        resolveDiff: {
                            guard let diffText = InputBarHelpers.loadGitDiff() else { return nil }
                            let lineCount = diffText.components(separatedBy: "\n").count
                            let summary = "\(lineCount) lines changed"
                            // Truncate large diffs to keep context manageable
                            let truncated = diffText.count > 8000
                                ? String(diffText.prefix(8000)) + "\n... (truncated)"
                                : diffText
                            return .diff(summary: summary, content: truncated)
                        },
                        resolveBranch: { [weak appState] in
                            let branchName = appState?.currentBranch ?? InputBarHelpers.loadCurrentBranch() ?? "unknown"
                            return .branch(name: branchName)
                        },
                        availableTickets: { [weak appState] in
                            appState?.intentViewModel.tickets.map { ($0.id, $0.title) } ?? []
                        }
                    ),
                    onForkFromMessage: { messageIndex in
                        forkSession(from: session, atIndex: messageIndex, viewModel: viewModel)
                    }
                )
                .onAppear {
                    if cachedProjectFiles.isEmpty {
                        cachedProjectFiles = InputBarHelpers.loadProjectFiles()
                    }
                }
                .onChange(of: viewModel.inputText) { _, newText in
                    autoContextDebounce?.cancel()
                    autoContextDebounce = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        appState.autoContextService.score(
                            messageText: newText,
                            recentMessages: session.messages,
                            recentlyEditedPaths: appState.editorViewModel.recentlyEditedPaths,
                            focusedFilePath: appState.editorViewModel.selectedFile?.path,
                            projectFiles: cachedProjectFiles
                        )
                    }
                }
                .sheet(isPresented: $showAutoPRSheet) {
                    AutoPRSheet(session: session) {
                        showAutoPRSheet = false
                    }
                    .environmentObject(container)
                    .environmentObject(appState)
                }
            } else {
                AgentEmptyState(onNewSession: {
                    viewModel.startNewSession(prompt: "", model: viewModel.selectedModelId)
                })
            }
        }
    }

    /// Create a forked session from the given session, copying messages up to (and including) the given index.
    private func forkSession(from session: AgentSession, atIndex messageIndex: Int, viewModel: AgentViewModel) {
        let messagesToCopy = Array(session.messages.prefix(messageIndex + 1))
        let originalName = session.customName ?? session.displayName
        let forkedSession = AgentSession(
            providerId: session.providerId,
            model: session.model,
            status: .idle,
            messages: messagesToCopy,
            customName: "[fork of \(originalName)]",
            autonomyLevel: session.autonomyLevel,
            parentSessionId: session.id,
            forkFromMessageIndex: messageIndex
        )
        viewModel.sessions.insert(forkedSession, at: 0)
        viewModel.selectedSessionId = forkedSession.id
        viewModel.showConversation()
        viewModel.persistSession(forkedSession)
    }
}

struct ReviewModeContent: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        if let conflict = viewModel.selectedConflict {
            MergeConflictView(conflict: conflict) { resolvedContent in
                if let adapter = container.getOrCreateGitAdapter() {
                    viewModel.resolveConflict(
                        filePath: conflict.filePath,
                        resolvedContent: resolvedContent,
                        using: adapter
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isCommitGraphVisible {
            GitGraphContainerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appState.gitHubPRViewModel.selectedPR != nil {
            GitHubPRDetailView(viewModel: appState.gitHubPRViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.selectedBranchName != nil, viewModel.selectedFileID == nil {
            let branchName = viewModel.selectedBranchName ?? "detached"
            let branch = appState.branches.first(where: { $0.name == branchName })
                ?? Branch(name: branchName)
            BranchDetailView(branch: branch, viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isLoadingBranchDiff {
            VStack(spacing: AnvilSpacing.md) {
                ProgressView()
                Text("Loading diff…")
                    .font(AnvilFont.label)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = viewModel.diffLoadError {
            AnvilEmptyState(
                icon: "exclamationmark.triangle",
                title: "Could not load diff",
                message: err
            )
        } else if viewModel.selectedReview != nil {
            DiffReviewView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.reviews.isEmpty {
            AnvilEmptyState(
                icon: "checkmark.circle",
                title: "Review inbox is empty",
                message: "Select a changed file or branch to review diffs.",
                actions: [
                    EmptyStateAction("Load Demo Data", icon: "tray.and.arrow.down", style: .secondary) {
                        appState.loadDemoData()
                        appState.currentSpace = .review
                    }
                ]
            )
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

struct BuildContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.buildActiveSection {
        case .sessions:
            AgentModeContent(viewModel: appState.agentViewModel)
        case .files:
            EditorMode()
        case .data:
            DatabaseMode(viewModel: appState.databaseViewModel)
        case .terminal:
            TerminalMode()
        case .tests:
            if appState.testingViewModel.suites.isEmpty {
                AnvilEmptyState(
                    icon: "testtube.2",
                    title: "No test suites",
                    message: "Run your test suite or load demo data to get started.",
                    actions: [
                        EmptyStateAction("Run Tests", icon: "play.fill", style: .primary) {
                            appState.testingViewModel.projectPath = appState.currentProjectPath
                            if appState.testingViewModel.projectPath == nil {
                                appState.testingViewModel.loadDemoData()
                            }
                            appState.testingViewModel.runAllTests()
                        },
                        EmptyStateAction("Load Demo Data", icon: "tray.and.arrow.down", style: .secondary) {
                            appState.testingViewModel.loadDemoData()
                        }
                    ]
                )
            } else {
                TestDetailView(viewModel: appState.testingViewModel)
            }
        }
    }
}

struct OperateContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.operateActiveSection {
        case .deploy:
            ShipModeContent(viewModel: appState.shipViewModel)
        case .monitor:
            ObservabilityMode()
        }
    }
}

struct LibraryContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.libraryActiveSection {
        case .docs:
            DocsMode()
        case .rules:
            RulesEditorView()
        case .extensions:
            PluginMarketplaceMode(viewModel: appState.pluginMarketplaceViewModel)
        case .notifications:
            NotificationsContentView(viewModel: appState.notificationsViewModel)
        case .messages:
            MessagingMode(viewModel: appState.messagingViewModel)
        case .schedule:
            ScheduleMode(viewModel: appState.scheduleViewModel)
        }
    }
}

struct NotificationsContentView: View {
    @ObservedObject var viewModel: NotificationsViewModel

    var body: some View {
        if let itemId = viewModel.selectedItemID,
           let item = viewModel.inboxItems.first(where: { $0.id == itemId }) {
            VStack(spacing: AnvilSpacing.md) {
                Text(item.notification.title)
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text(item.notification.body)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(AnvilSpacing.lg)
        } else {
            AnvilEmptyState(
                icon: "bell",
                title: "No notification selected",
                message: "Select a notification from the sidebar."
            )
        }
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
                .accessibilityHidden(true)

            Text(title)
                .font(AnvilFont.heading)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)

            if !hint.isEmpty {
                Text(hint)
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
                    .padding(.top, AnvilSpacing.sm)
            }
        }
    }
}
