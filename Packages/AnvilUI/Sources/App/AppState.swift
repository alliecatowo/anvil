import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit
import AnvilGitHub

public enum AnvilMode: String, CaseIterable, Identifiable, Sendable {
    case intent = "Intent"
    case agent = "Agent"
    case review = "Review"
    case ship = "Ship"
    case editor = "Editor"
    case database = "Database"
    case terminal = "Terminal"
    case docs = "Docs"
    case messaging = "Messaging"
    case notifications = "Notifications"
    case testing = "Testing"
    case extensions = "Extensions"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .intent: "target"
        case .agent: "cpu"
        case .review: "checkmark.circle"
        case .ship: "shippingbox"
        case .editor: "doc.text"
        case .database: "cylinder"
        case .terminal: "terminal"
        case .docs: "book"
        case .messaging: "message"
        case .notifications: "bell"
        case .testing: "testtube.2"
        case .extensions: "puzzlepiece.extension"
        }
    }

    public var shortcutNumber: Int? {
        switch self {
        case .intent: 1
        case .agent: 2
        case .review: 3
        case .ship: 4
        case .editor: 5
        case .database: 6
        case .terminal: 7
        case .docs: 8
        case .messaging: 9
        case .notifications: 0
        case .testing: nil
        case .extensions: nil
        }
    }

    public static var coreModes: [AnvilMode] {
        [.intent, .agent, .review, .ship]
    }

    public static var auxiliaryModes: [AnvilMode] {
        [.editor, .database, .terminal, .testing, .docs, .messaging, .notifications, .extensions]
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

// MARK: - Terminal Tab

public struct TerminalTab: Identifiable {
    public let id = UUID().uuidString
    public var name: String
    public var shellPath: String = "/bin/zsh"
}

@MainActor
public class AppState: ObservableObject {
    @Published public var currentMode: AnvilMode = .agent
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
    @Published public var isQuickCaptureVisible: Bool = false
    @Published public var isProjectNotesVisible: Bool = false
    @Published public var isProjectSwitcherVisible: Bool = false
    @Published public var isProjectInfoVisible: Bool = false
    @Published public var isTerminalPanelVisible: Bool = false
    @Published public var terminalPanelHeight: CGFloat = 200
    @Published public var terminalTabs: [TerminalTab] = [TerminalTab(name: "zsh")]
    @Published public var selectedTerminalTabId: String?
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
    @Published var gitHubPRViewModel = GitHubPRViewModel()

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
            await loadGitStatus(from: adapter)
        } catch {
            // Branch switch failed — status unchanged
        }
    }

    /// Create a new branch and switch to it.
    public func createBranch(_ name: String, using adapter: GitSourceControlAdapter) async {
        do {
            _ = try await adapter.createBranch(name: name, from: nil)
            await loadGitStatus(from: adapter)
        } catch {
            // Branch creation failed
        }
    }

    public func switchMode(_ mode: AnvilMode) {
        withAnimation(AnvilAnimation.modeSwitch) {
            currentMode = mode
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
        // Ensure at least one tab exists
        if isTerminalPanelVisible && terminalTabs.isEmpty {
            addTerminalTab()
        }
        if isTerminalPanelVisible && selectedTerminalTabId == nil {
            selectedTerminalTabId = terminalTabs.first?.id
        }
    }

    public func addTerminalTab() {
        let tab = TerminalTab(name: "zsh")
        terminalTabs.append(tab)
        selectedTerminalTabId = tab.id
    }

    public func closeTerminalTab(_ id: String) {
        terminalTabs.removeAll { $0.id == id }
        if selectedTerminalTabId == id {
            selectedTerminalTabId = terminalTabs.last?.id
        }
        if terminalTabs.isEmpty {
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

        // Intent: sample tickets
        let tickets = [
            Ticket(id: "ANV-101", title: "Fix SSO token refresh", status: "in-progress", priority: .critical, assignee: "allie", labels: ["auth", "bug"]),
            Ticket(id: "ANV-102", title: "Add dark mode to settings", status: "open", priority: .medium, labels: ["ui"]),
            Ticket(id: "ANV-103", title: "Migrate to new API v3", status: "open", priority: .high, assignee: "allie", labels: ["api", "migration"]),
            Ticket(id: "ANV-104", title: "Write E2E tests for checkout", status: "in-review", priority: .medium, labels: ["testing"]),
            Ticket(id: "ANV-105", title: "Update dependencies", status: "done", priority: .low, labels: ["chore"]),
        ]
        intentViewModel.tickets = tickets

        // Review: sample reviews
        reviewViewModel.reviews = ReviewViewModel.makeSampleReviews()

        // Ship: sample environments and deployments
        let (envs, deploys, logs, vars) = ShipViewModel.makeSampleData()
        shipViewModel.environments = envs
        shipViewModel.deployments = deploys
        shipViewModel.buildLogs = logs
        shipViewModel.envVars = vars
        shipViewModel.selectedEnvironmentID = envs.first?.id

        switchMode(.agent)
    }
}
