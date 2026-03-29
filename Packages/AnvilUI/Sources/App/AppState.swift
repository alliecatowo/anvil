import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit
import AnvilGitHub

/// Result of a git operation surfaced in the UI.
public enum GitOperationResult: Equatable {
    case success(String)
    case failure(String)

    public var message: String {
        switch self {
        case .success(let msg), .failure(let msg): msg
        }
    }

    public var isError: Bool {
        if case .failure = self { return true }
        return false
    }
}

public enum AnvilSpace: String, CaseIterable, Identifiable, Sendable {
    case plan = "Plan"
    case build = "Build"
    case review = "Review"
    case operate = "Operate"
    case library = "Library"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .plan:    "target"
        case .build:   "hammer"
        case .review:  "checkmark.circle"
        case .operate: "gauge"
        case .library: "books.vertical"
        }
    }

    public var shortcutNumber: Int? {
        switch self {
        case .plan:    1
        case .build:   2
        case .review:  3
        case .operate: 4
        case .library: 5
        }
    }
}

public enum FileEncoding: String, CaseIterable, Sendable {
    case utf8 = "UTF-8"
    case ascii = "ASCII"
    case utf16 = "UTF-16"
    case utf16le = "UTF-16 LE"
    case utf16be = "UTF-16 BE"
    case latin1 = "ISO 8859-1"
    case shiftJIS = "Shift JIS"
    case eucjp = "EUC-JP"
    case windows1252 = "Windows-1252"
}

public enum LineEnding: String, CaseIterable, Sendable {
    case lf = "LF"
    case crlf = "CRLF"
    case cr = "CR"
}

/// Represents the currently focused entity in any space.
/// Used by the command palette to show entity-specific actions.
public enum FocusedEntity: Equatable {
    case ticket(id: String, title: String)
    case file(path: String, name: String)
    case agentSession(id: String, name: String)
    case pullRequest(id: String, title: String)

    public var entityType: FocusedEntityType {
        switch self {
        case .ticket: .ticket
        case .file: .file
        case .agentSession: .agentSession
        case .pullRequest: .pullRequest
        }
    }
}

@MainActor
public class AppState: ObservableObject {
    @Published public var currentSpace: AnvilSpace = .build
    @Published public var lastSpace: AnvilSpace = .build
    @Published public var isSidebarVisible: Bool = true
    @Published public var isSidebarCollapsed: Bool = false
    @Published public var isInspectorVisible: Bool = false
    @Published public var isCommandPaletteVisible: Bool = false
    @Published public var commandPaletteInitialMode: PaletteMode = .commands
    /// File path that EditorMode should open when switching to editor via command palette.
    @Published public var pendingFileToOpen: String? = nil
    /// Symbol line that EditorMode should scroll to after opening pendingFileToOpen.
    @Published public var pendingSymbolLine: Int? = nil
    /// Triggers inline edit (⌘K) in editor mode.
    @Published public var triggerInlineEdit: Bool = false
    /// Triggers find bar (⌘F) in editor mode.
    @Published public var triggerFindInFile: Bool = false
    /// Triggers save (⌘S) in editor mode.
    @Published public var triggerSaveFile: Bool = false
    /// Triggers close tab (⌘W) — closes active editor file or terminal tab.
    @Published public var triggerCloseTab: Bool = false
    /// Triggers toggle line comment (⌘/) in editor mode.
    @Published public var triggerToggleComment: Bool = false
    /// Triggers go-to-definition (F12) in editor mode.
    @Published public var triggerGoToDefinition: Bool = false
    /// Project-wide search panel (⌘⇧F).
    @Published public var isProjectSearchVisible: Bool = false
    @Published public var isQuickCaptureVisible: Bool = false
    @Published public var isCodebaseQAVisible: Bool = false
    @Published public var isProjectNotesVisible: Bool = false
    @Published public var isProjectSwitcherVisible: Bool = false
    @Published public var isProjectInfoVisible: Bool = false
    @Published public var isAgentPanelVisible: Bool = false
    @Published public var isTerminalPanelVisible: Bool = false
    @Published public var terminalPanelHeight: CGFloat = 200
    @Published public var terminalViewModel = TerminalViewModel()
    @Published public var isSourceControlVisible: Bool = false
    @Published public var currentBranch: String = "main"
    @Published public var uncommittedFileCount: Int = 0
    @Published public var stagedChanges: [GitFileChange] = []
    @Published public var unstagedChanges: [GitFileChange] = []
    @Published public var untrackedChanges: [GitFileChange] = []
    @Published public var branches: [Branch] = []
    @Published public var isSyncing: Bool = false
    @Published public var gitOperationResult: GitOperationResult?
    @Published public var isAutoPREnabled: Bool = UserDefaults.standard.bool(forKey: "anvil_auto_pr_enabled") {
        didSet { UserDefaults.standard.set(isAutoPREnabled, forKey: "anvil_auto_pr_enabled") }
    }
    @Published public var lastAutoPRURL: String?
    @Published public var isMemoryScanEnabled: Bool = UserDefaults.standard.object(forKey: "anvil_memory_scan_enabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isMemoryScanEnabled, forKey: "anvil_memory_scan_enabled") }
    }
    @Published public var defaultWorktreePath: String = UserDefaults.standard.string(forKey: "anvil_worktree_path") ?? "" {
        didSet { UserDefaults.standard.set(defaultWorktreePath, forKey: "anvil_worktree_path") }
    }
    @Published public var agentStatus: String = "Idle"
    @Published public var agentCurrentTool: String?
    @Published public var agentActiveSessionId: String?
    @Published public var agentRunStartedAt: Date?
    @Published public var sessionCost: Decimal = 0
    @Published public var todayCost: Decimal = 0

    // MARK: - Cursor Position
    @Published public var cursorLine: Int = 1
    @Published public var cursorColumn: Int = 1
    @Published public var selectionCount: Int = 0
    @Published public var isGoToLineVisible: Bool = false

    // MARK: - File Encoding
    @Published public var fileEncoding: FileEncoding = .utf8
    @Published public var lineEnding: LineEnding = .lf

    // MARK: - Shared ViewModels

    @Published public var agentViewModel = AgentViewModel()
    @Published public var intentViewModel = IntentViewModel()
    @Published public var reviewViewModel = ReviewViewModel()
    @Published public var shipViewModel = ShipViewModel()
    @Published var notificationsViewModel = NotificationsViewModel()
    @Published var libraryDocsViewModel = DocsViewModel()
    @Published var editorViewModel = EditorViewModel()
    @Published var testingViewModel = TestingViewModel()
    @Published var databaseViewModel = DatabaseViewModel()
    @Published var observabilityViewModel = ObservabilityViewModel()
    @Published var memoriesViewModel = MemoriesViewModel()
    @Published var gitHubPRViewModel = GitHubPRViewModel()
    @Published var pluginMarketplaceViewModel = PluginMarketplaceViewModel()
    @Published var messagingViewModel = MessagingViewModel()
    @Published var scheduleViewModel = ScheduleViewModel()
    @Published public var autoContextService = AutoContextService()

    // MARK: - Build Section

    @Published public var buildActiveSection: BuildSection = .sessions

    public enum BuildSection: String, CaseIterable, Sendable {
        case sessions = "Sessions"
        case files = "Files"
        case terminal = "Terminal"
        case data = "Data"
        case tests = "Tests"

        public var icon: String {
            switch self {
            case .sessions: "bubble.left.and.text.bubble.right"
            case .files: "doc.text"
            case .terminal: "terminal"
            case .data: "cylinder"
            case .tests: "testtube.2"
            }
        }
    }

    // MARK: - Operate Section

    @Published public var operateActiveSection: OperateSection = .deploy

    public enum OperateSection: String, CaseIterable, Sendable {
        case deploy = "Deploy"
        case monitor = "Monitor"

        public var icon: String {
            switch self {
            case .deploy: "shippingbox"
            case .monitor: "chart.line.uptrend.xyaxis"
            }
        }
    }

    // MARK: - Library Section

    @Published public var libraryActiveSection: LibrarySection = .docs

    public enum LibrarySection: String, CaseIterable, Sendable {
        case docs = "Docs"
        case rules = "Rules"
        case extensions = "Extensions"
        case notifications = "Inbox"
        case messages = "Chat"
        case schedule = "Schedule"

        public var icon: String {
            switch self {
            case .docs: "books.vertical"
            case .rules: "text.badge.checkmark"
            case .extensions: "puzzlepiece.extension"
            case .notifications: "bell"
            case .messages: "bubble.left.and.bubble.right"
            case .schedule: "calendar"
            }
        }
    }

    // MARK: - Split Editor
    lazy var splitEditorState = SplitEditorState(primaryViewModel: editorViewModel)
    /// Triggers vertical split (⌘\).
    @Published public var triggerSplitVertical: Bool = false
    /// Triggers horizontal split (⌘⇧\).
    @Published public var triggerSplitHorizontal: Bool = false

    public init() {
        // Wire agent hunk persistence to editor reload
        agentViewModel.onFilePersisted = { [weak self] path in
            self?.editorViewModel.reloadFile(atPath: path)
        }

        // Wire auto-memory scanning when an agent session completes a turn
        agentViewModel.onSessionCompleted = { [weak self] session in
            guard let self, self.isMemoryScanEnabled else { return }
            self.memoriesViewModel.scanSession(session)
        }
    }

    // MARK: - Focused Entity

    /// The currently focused entity, derived from the active space and its selection state.
    /// Used by the command palette to show entity-specific actions via Cmd+K.
    public var focusedEntity: FocusedEntity? {
        switch currentSpace {
        case .plan:
            if let ticket = intentViewModel.selectedTicket {
                return .ticket(id: ticket.id, title: ticket.title)
            }
        case .build:
            switch buildActiveSection {
            case .sessions:
                if let session = agentViewModel.selectedSession {
                    return .agentSession(id: session.id, name: session.displayName)
                }
            case .files:
                if let file = editorViewModel.selectedFile {
                    return .file(path: file.path, name: file.name)
                }
            default:
                break
            }
        case .review:
            if let pr = gitHubPRViewModel.selectedPR {
                return .pullRequest(id: pr.id, title: pr.title)
            }
            if let review = reviewViewModel.selectedReview {
                return .pullRequest(id: review.id, title: review.title)
            }
        default:
            break
        }
        return nil
    }

    // MARK: - Git Integration

    /// Load real git state: current branch, uncommitted file count, and branch list.
    public func loadGitStatus(from adapter: GitSourceControlAdapter) async {
        if let branch = try? await adapter.currentBranch() {
            currentBranch = branch.name
        }

        // Load working tree changes (staged, unstaged, untracked)
        if let changes = try? await adapter.workingTreeChanges() {
            stagedChanges = changes.staged
            unstagedChanges = changes.unstaged
            untrackedChanges = changes.untracked
            let allPaths = Set(
                changes.staged.map(\.filePath)
                + changes.unstaged.map(\.filePath)
                + changes.untracked.map(\.filePath)
            )
            uncommittedFileCount = allPaths.count
        } else {
            stagedChanges = []
            unstagedChanges = []
            untrackedChanges = []
            uncommittedFileCount = 0
        }

        // Load branch list
        if let allBranches = try? await adapter.branches() {
            branches = allBranches.filter { !$0.name.contains("/") || $0.name.hasPrefix("origin/") == false }
        }
    }

    /// Switch to a branch using the git adapter and refresh status.
    public func switchBranch(_ name: String, using adapter: GitSourceControlAdapter) async {
        do {
            try await adapter.switchBranch(name: name)
            await Task.yield()
            await loadGitStatus(from: adapter)
        } catch {
            // Branch switch failed — status unchanged
        }
    }

    /// Create a new branch and switch to it.
    public func createBranch(_ name: String, using adapter: GitSourceControlAdapter) async {
        do {
            _ = try await adapter.createBranch(name: name, from: nil)
            await Task.yield()
            await loadGitStatus(from: adapter)
            await EventBus.shared.publish(BranchCreatedEvent(branchName: name))
        } catch {
            gitOperationResult = .failure("Branch creation failed: \(error.localizedDescription)")
        }
    }

    /// Delete a branch.
    public func deleteBranch(_ name: String, force: Bool, using adapter: GitSourceControlAdapter) async {
        do {
            try await adapter.deleteBranch(name: name, force: force)
            await loadGitStatus(from: adapter)
            gitOperationResult = .success("Deleted branch \(name)")
        } catch {
            gitOperationResult = .failure("Delete branch failed: \(error.localizedDescription)")
        }
    }

    /// Commit staged changes.
    public func commitChanges(message: String, amend: Bool = false, using adapter: GitSourceControlAdapter) async {
        do {
            let commit = try await adapter.commit(message: message, amend: amend)
            await loadGitStatus(from: adapter)
            gitOperationResult = .success("Committed \(commit.shortHash): \(commit.message)")
            await EventBus.shared.publish(CommitCreatedEvent(commitHash: commit.shortHash, message: commit.message))
        } catch {
            gitOperationResult = .failure("Commit failed: \(error.localizedDescription)")
        }
    }

    /// Push to remote.
    public func pushChanges(using adapter: GitSourceControlAdapter) async {
        isSyncing = true
        do {
            let branch = try? await adapter.currentBranch()
            let needsUpstream = branch?.upstream == nil
            try await adapter.push(setUpstream: needsUpstream)
            await loadGitStatus(from: adapter)
            gitOperationResult = .success("Pushed to remote")
            await EventBus.shared.publish(PushCompletedEvent(branch: currentBranch))
        } catch {
            gitOperationResult = .failure("Push failed: \(error.localizedDescription)")
        }
        isSyncing = false
    }

    /// Pull from remote.
    public func pullChanges(rebase: Bool = false, using adapter: GitSourceControlAdapter) async {
        isSyncing = true
        do {
            try await adapter.pull(rebase: rebase)
            await loadGitStatus(from: adapter)
            gitOperationResult = .success("Pulled from remote")
        } catch {
            gitOperationResult = .failure("Pull failed: \(error.localizedDescription)")
        }
        isSyncing = false
    }

    /// Fetch from remote.
    public func fetchRemote(using adapter: GitSourceControlAdapter) async {
        isSyncing = true
        do {
            try await adapter.fetch()
            await loadGitStatus(from: adapter)
            gitOperationResult = .success("Fetched from remote")
        } catch {
            gitOperationResult = .failure("Fetch failed: \(error.localizedDescription)")
        }
        isSyncing = false
    }

    /// Stash current changes.
    public func stashChanges(message: String? = nil, using adapter: GitSourceControlAdapter) async {
        do {
            try await adapter.stash(message: message)
            await loadGitStatus(from: adapter)
            gitOperationResult = .success("Changes stashed")
        } catch {
            gitOperationResult = .failure("Stash failed: \(error.localizedDescription)")
        }
    }

    /// Pop the latest stash.
    public func popStash(using adapter: GitSourceControlAdapter) async {
        do {
            try await adapter.stashPop()
            await loadGitStatus(from: adapter)
            gitOperationResult = .success("Stash popped")
        } catch {
            gitOperationResult = .failure("Stash pop failed: \(error.localizedDescription)")
        }
    }

    public func switchSpace(_ space: AnvilSpace) {
        withAnimation(AnvilAnimation.modeSwitch) {
            lastSpace = space
            currentSpace = space
        }
    }

    public func toggleSidebar() {
        withAnimation(AnvilAnimation.sidebarCollapse) {
            isSidebarCollapsed.toggle()
        }
    }

    public func toggleInspector() {
        withAnimation(AnvilAnimation.standard) {
            isInspectorVisible.toggle()
        }
    }

    public func toggleCommandPalette(initialMode: PaletteMode = .commands) {
        commandPaletteInitialMode = initialMode
        withAnimation(AnvilAnimation.commandPaletteAppear) {
            isCommandPaletteVisible.toggle()
        }
    }

    public func openFilePalette() {
        toggleCommandPalette(initialMode: .files)
    }

    public func openSymbolPalette() {
        toggleCommandPalette(initialMode: .symbols)
    }

    public func toggleAgentPanel() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            isAgentPanelVisible.toggle()
        }
    }

    public func toggleTerminal() {
        withAnimation(AnvilAnimation.standard) {
            isTerminalPanelVisible.toggle()
        }
        // Ensure at least one session exists when opening
        if isTerminalPanelVisible && terminalViewModel.sessions.isEmpty {
            terminalViewModel.addTab()
        }
    }

    public func closeTerminalTab(_ id: UUID) {
        terminalViewModel.closeTab(id)
        if terminalViewModel.sessions.isEmpty {
            withAnimation(AnvilAnimation.standard) {
                isTerminalPanelVisible = false
            }
        }
    }

    public func toggleQuickCapture() {
        withAnimation(AnvilAnimation.commandPaletteAppear) {
            isQuickCaptureVisible.toggle()
        }
    }

    public func toggleCodebaseQA() {
        withAnimation(AnvilAnimation.commandPaletteAppear) {
            isCodebaseQAVisible.toggle()
        }
    }

    public func toggleProjectNotes() {
        withAnimation(AnvilAnimation.standard) {
            isProjectNotesVisible.toggle()
        }
    }

    public func toggleSourceControl() {
        withAnimation(AnvilAnimation.standard) {
            isSourceControlVisible.toggle()
        }
    }

    public func toggleProjectSearch() {
        withAnimation(AnvilAnimation.standard) {
            isProjectSearchVisible.toggle()
        }
    }

    // MARK: - Project

    @Published public var currentProject: Project?
    @Published public var currentProjectPath: String?

    public func toggleProjectSwitcher() {
        withAnimation(AnvilAnimation.commandPaletteAppear) {
            isProjectSwitcherVisible.toggle()
        }
    }

    public func toggleProjectInfo() {
        withAnimation(AnvilAnimation.standard) {
            isProjectInfoVisible.toggle()
        }
    }

    // MARK: - Demo Data

    public func loadDemoData() {
        // Agent: sample conversation
        let sampleMessages = [
            AgentMessage(role: .user, content: "Fix the authentication bug in the login flow"),
            AgentMessage(role: .assistant, content: "I'll start by examining the auth module to understand the current login flow.\n\nLet me read the relevant files...", toolCalls: [
                ToolCall(name: "read_file", arguments: "{\"path\": \"src/auth/handler.ts\"}", status: .completed, result: ToolResult(content: "// Auth handler with 142 lines of code...\nfunction validateToken(token) {\n  const exp = token.exp;\n  return exp > Date.now();\n}", type: .text)),
            ]),
            AgentMessage(role: .assistant, content: "I found the issue. The token validation is checking expiry against UTC but the token was issued with local time. Here's the fix:"),
        ]
        let session = AgentSession(providerId: "claude-cli", model: "claude-sonnet-4-6", status: .completed, workItemId: "ANV-42", tokenUsage: TokenUsage(inputTokens: 12500, outputTokens: 3200), cost: 0.42, messages: sampleMessages)
        agentViewModel.sessions = [session]
        agentViewModel.selectedSessionId = session.id

        // Intent: reinitialize with demo data (already loaded on init, this resets to defaults)
        intentViewModel = IntentViewModel()

        // Review: sample reviews
        reviewViewModel.reviews = ReviewViewModel.makeSampleReviews()

        // Ship: load demo data
        shipViewModel = ShipViewModel()
        shipViewModel.loadSampleData()

        switchSpace(.build)
    }

    /// Apply a deterministic UI-test launch scenario, used by screenshot tests and seeded UI flows.
    public func applyUITestScenarioIfNeeded(_ environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let rawScenario = environment["ANVIL_UITEST_SCENARIO"],
              let scenario = UITestScenario(rawValue: rawScenario) else {
            return
        }

        applyUITestScenario(scenario)
    }

    /// Seed the app into one canonical UI state without relying on menu clicks.
    public func applyUITestScenario(_ scenario: UITestScenario) {
        // Reset transient shell state first so screenshots don't inherit stale overlays.
        isCommandPaletteVisible = false
        isQuickCaptureVisible = false
        isCodebaseQAVisible = false
        isProjectNotesVisible = false
        isProjectSwitcherVisible = false
        isProjectInfoVisible = false
        isAgentPanelVisible = false
        isInspectorVisible = false
        isTerminalPanelVisible = false
        isProjectSearchVisible = false
        isSidebarVisible = true
        isSidebarCollapsed = false

        switch scenario {
        case .agentEmpty:
            currentSpace = .build
            buildActiveSection = .sessions
            agentViewModel.sessions = []
            agentViewModel.selectedSessionId = nil
            agentViewModel.viewMode = .conversation
            agentViewModel.dashboardSelectedSessionIds.removeAll()
            agentViewModel.queuedMessages.removeAll()
            agentViewModel.contextAttachments.removeAll()
            agentViewModel.editSuggestions.removeAll()
            agentViewModel.pendingToolApproval = nil
            agentViewModel.inputText = ""

        case .agentConversation:
            loadDemoData()
            currentSpace = .build
            buildActiveSection = .sessions
            agentViewModel.viewMode = .conversation
            if agentViewModel.selectedSessionId == nil {
                agentViewModel.selectedSessionId = agentViewModel.sessions.first?.id
            }
            agentViewModel.showConversation()

        case .intentList:
            loadDemoData()
            currentSpace = .plan
            intentViewModel.viewMode = .list
            intentViewModel.grouping = .status
            intentViewModel.searchText = ""
            intentViewModel.selectedTicketId = nil
            intentViewModel.selectedTicketIds.removeAll()

        case .intentBoard:
            loadDemoData()
            currentSpace = .plan
            intentViewModel.viewMode = .board
            intentViewModel.grouping = .status
            intentViewModel.searchText = ""
            intentViewModel.selectedTicketId = nil
            intentViewModel.selectedTicketIds.removeAll()

        case .reviewInbox:
            loadDemoData()
            currentSpace = .review
            reviewViewModel.selectedReviewID = nil
            reviewViewModel.selectedFileID = nil
            reviewViewModel.selectedBranchName = nil
            reviewViewModel.isCommitGraphVisible = false
            appStateResetReviewSelection()

        case .reviewDiff:
            loadDemoData()
            currentSpace = .review
            reviewViewModel.isCommitGraphVisible = false
            appStateResetReviewSelection()
            if let review = reviewViewModel.reviews.first {
                reviewViewModel.selectReview(review.id)
                if let firstFile = review.diff.first {
                    reviewViewModel.selectFile(firstFile.id)
                }
            }

        case .shipDashboard:
            loadDemoData()
            currentSpace = .operate
            operateActiveSection = .deploy
            shipViewModel.selectedTab = .dashboard
            shipViewModel.selectedEnvironmentID = shipViewModel.environments.first?.id

        case .workspaceTerminal:
            loadDemoData()
            currentSpace = .build
            buildActiveSection = .terminal
            if terminalViewModel.sessions.isEmpty {
                _ = terminalViewModel.addTab()
            }
            if let firstSession = terminalViewModel.sessions.first {
                terminalViewModel.selectTab(firstSession.id)
            }

        case .workspaceNotifications:
            loadDemoData()
            currentSpace = .library
            libraryActiveSection = .notifications
            notificationsViewModel.loadSampleData()
            notificationsViewModel.selectedTab = .inbox
            notificationsViewModel.selectedItemID = notificationsViewModel.filteredInboxItems.first?.id
        }
    }

    private func appStateResetReviewSelection() {
        reviewViewModel.selectedReviewID = nil
        reviewViewModel.selectedFileID = nil
        reviewViewModel.selectedBranchName = nil
        reviewViewModel.selectedConflictIndex = nil
    }
}
