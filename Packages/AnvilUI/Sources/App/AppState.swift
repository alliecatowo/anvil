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
}
