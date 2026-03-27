import SwiftUI
import AnvilDomain
import AnvilGit

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
        }
    }

    public static var coreModes: [AnvilMode] {
        [.intent, .agent, .review, .ship]
    }

    public static var auxiliaryModes: [AnvilMode] {
        [.editor, .database, .terminal, .docs, .messaging, .notifications]
    }
}

@MainActor
public class AppState: ObservableObject {
    @Published public var currentMode: AnvilMode = .agent
    @Published public var isSidebarVisible: Bool = true
    @Published public var isSidebarCollapsed: Bool = false
    @Published public var isInspectorVisible: Bool = false
    @Published public var isCommandPaletteVisible: Bool = false
    @Published public var isQuickCaptureVisible: Bool = false
    @Published public var isProjectNotesVisible: Bool = false
    @Published public var isTerminalPanelVisible: Bool = false
    @Published public var currentBranch: String = "main"
    @Published public var agentStatus: String = "Idle"
    @Published public var sessionCost: Decimal = 0
    @Published public var todayCost: Decimal = 0

    // MARK: - Shared ViewModels

    @Published public var agentViewModel = AgentViewModel()
    @Published public var intentViewModel = IntentViewModel()
    @Published public var reviewViewModel = ReviewViewModel()
    @Published public var shipViewModel = ShipViewModel()

    public init() {}

    // MARK: - Git Integration

    /// Load the real branch name from the Git adapter and update the status bar.
    public func loadGitStatus(from adapter: GitSourceControlAdapter) async {
        if let branch = try? await adapter.currentBranch() {
            currentBranch = branch.name
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

    public func toggleCommandPalette() {
        withAnimation(AnvilAnimation.commandPaletteAppear) {
            isCommandPaletteVisible.toggle()
        }
    }

    public func toggleTerminal() {
        withAnimation(AnvilAnimation.standard) {
            isTerminalPanelVisible.toggle()
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

    // MARK: - Project

    @Published public var currentProjectPath: String?

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
