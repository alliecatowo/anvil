import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit
import AnvilGitHub

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
    /// Project-wide search panel (⌘⇧F).
    @Published public var isProjectSearchVisible: Bool = false
    @Published public var isQuickCaptureVisible: Bool = false
    @Published public var isCodebaseQAVisible: Bool = false
    @Published public var isProjectNotesVisible: Bool = false
    @Published public var isProjectSwitcherVisible: Bool = false
    @Published public var isProjectInfoVisible: Bool = false
    @Published public var isTerminalPanelVisible: Bool = false
    @Published public var terminalPanelHeight: CGFloat = 200
    @Published var terminalViewModel = TerminalViewModel()
    @Published public var isSourceControlVisible: Bool = false
    @Published public var currentBranch: String = "main"
    @Published public var uncommittedFileCount: Int = 0
    @Published public var branches: [Branch] = []
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
    @Published var gitHubPRViewModel = GitHubPRViewModel()

    // MARK: - Split Editor
    lazy var splitEditorState = SplitEditorState(primaryViewModel: editorViewModel)
    /// Triggers vertical split (⌘\).
    @Published public var triggerSplitVertical: Bool = false
    /// Triggers horizontal split (⌘⇧\).
    @Published public var triggerSplitHorizontal: Bool = false

    public init() {}

    // MARK: - Git Integration

    /// Load real git state: current branch, uncommitted file count, and branch list.
    public func loadGitStatus(from adapter: GitSourceControlAdapter) async {
        if let branch = try? await adapter.currentBranch() {
            currentBranch = branch.name
        }

        // Count uncommitted files (staged + unstaged diffs)
        let staged = (try? await adapter.stagedDiff()) ?? []
        let unstaged = (try? await adapter.unstagedDiff()) ?? []
        let allPaths = Set(staged.map(\.filePath) + unstaged.map(\.filePath))
        uncommittedFileCount = allPaths.count

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
        } catch {
            // Branch creation failed
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
            if isSidebarCollapsed {
                isSidebarCollapsed = false
            } else if isSidebarVisible {
                isSidebarCollapsed = true
            } else {
                isSidebarVisible = true
                isSidebarCollapsed = false
            }
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
}
