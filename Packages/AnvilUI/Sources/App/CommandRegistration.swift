import SwiftUI
import AppKit
import AnvilDomain
import AnvilApplication

/// Registers all built-in commands into the CommandRegistry.
/// Called once at app launch from the .task modifier in MainWindow.
@MainActor
public func registerBuiltInCommands(registry: CommandRegistry, appState: AppState) {

    // MARK: - Space Switching

    for space in AnvilSpace.allCases {
        let shortcutHint = space.shortcutNumber.map { "\u{2318}\($0)" }
        registry.register(
            AnvilCommand(
                id: "space-\(space.rawValue.lowercased())",
                title: "Switch to \(space.rawValue)",
                icon: space.icon,
                category: .spaces,
                keyboardShortcut: shortcutHint
            )
        ) {
            appState.switchSpace(space)
        }
    }

    // MARK: - Actions

    registry.register(
        AnvilCommand(id: "new-agent-session", title: "New Build Session", icon: "cpu", category: .agent, keyboardShortcut: "\u{2318}\u{21E7}A", keyBinding: .cmdShift("a"))
    ) {
        appState.switchSpace(.build)
        appState.agentViewModel.startNewSession(prompt: "", model: "claude-sonnet-4-6")
    }

    registry.register(
        AnvilCommand(id: "new-item", title: "New Ticket", icon: "plus.square", category: .plan, keyboardShortcut: "\u{2318}N", keyBinding: .cmd("n"))
    ) {
        appState.switchSpace(.plan)
        appState.intentViewModel.isCreatingTicket = true
    }

    registry.register(
        AnvilCommand(id: "settings", title: "Settings", icon: "gear", category: .actions, keyboardShortcut: "\u{2318},", keyBinding: .cmd(","))
    ) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    registry.register(
        AnvilCommand(id: "quick-capture", title: "Quick Capture", icon: "note.text.badge.plus", category: .actions, keyboardShortcut: "\u{2318}\u{21E7}Space", keyBinding: .cmdShift("space"))
    ) {
        appState.toggleQuickCapture()
    }

    registry.register(
        AnvilCommand(id: "search-in-files", title: "Search in Files", icon: "magnifyingglass", category: .navigation, keyboardShortcut: "\u{2318}\u{21E7}F", group: "File", keyBinding: .cmdShift("f"))
    ) {
        appState.toggleProjectSearch()
    }

    // MARK: - Navigation

    registry.register(
        AnvilCommand(id: "toggle-sidebar", title: "Toggle Sidebar", icon: "sidebar.left", category: .navigation, keyboardShortcut: "\u{2318}B", group: "View", keyBinding: .cmd("b"))
    ) {
        appState.toggleSidebar()
    }

    registry.register(
        AnvilCommand(id: "toggle-inspector", title: "Toggle Inspector", icon: "sidebar.right", category: .navigation, keyboardShortcut: "\u{2318}\u{21E7}I", group: "View", keyBinding: .cmdShift("i"))
    ) {
        appState.toggleInspector()
    }

    registry.register(
        AnvilCommand(id: "toggle-terminal", title: "Toggle Terminal", icon: "terminal", category: .terminal, keyboardShortcut: "\u{2318}J", group: "Terminal", keyBinding: .cmd("j"))
    ) {
        appState.toggleTerminal()
    }

    registry.register(
        AnvilCommand(id: "go-to-line", title: "Go to Line...", icon: "number", category: .navigation, keyboardShortcut: "\u{2303}G", keyBinding: KeyBinding(key: "g", modifiers: [.control]))
    ) {
        appState.isGoToLineVisible = true
    }

    // MARK: - Editor Actions

    registry.register(
        AnvilCommand(id: "show-all-commands", title: "Show All Commands", icon: "command", category: .navigation, keyboardShortcut: "\u{2318}\u{21E7}P", keyBinding: .cmdShift("p"))
    ) {
        appState.toggleCommandPalette()
    }

    registry.register(
        AnvilCommand(id: "close-tab", title: "Close Tab", icon: "xmark.square", category: .editor, keyboardShortcut: "\u{2318}W", keyBinding: .cmd("w"))
    ) {
        appState.triggerCloseTab = true
    }

    registry.register(
        AnvilCommand(id: "toggle-comment", title: "Toggle Line Comment", icon: "text.quote", category: .editor, keyboardShortcut: "\u{2318}/", keyBinding: .cmd("/"))
    ) {
        appState.triggerToggleComment = true
    }

    registry.register(
        AnvilCommand(id: "go-to-definition", title: "Go to Definition", icon: "arrow.right.circle", category: .editor, keyboardShortcut: "F12", keyBinding: KeyBinding(key: "f12"))
    ) {
        appState.triggerGoToDefinition = true
    }

    // MARK: - Plan Space Contextual

    registry.register(
        AnvilCommand(id: "ctx-create-ticket", title: "Create Ticket", icon: "plus.square", category: .plan, spaceScope: "Plan")
    ) {
        appState.switchSpace(.plan)
        appState.intentViewModel.isCreatingTicket = true
    }

    registry.register(
        AnvilCommand(id: "ctx-board-view", title: "Switch to Board View", icon: "square.grid.3x3", category: .plan, spaceScope: "Plan")
    ) {
        appState.intentViewModel.viewMode = .board
    }

    registry.register(
        AnvilCommand(id: "ctx-list-view", title: "Switch to List View", icon: "list.bullet", category: .plan, spaceScope: "Plan")
    ) {
        appState.intentViewModel.viewMode = .list
    }

    registry.register(
        AnvilCommand(id: "ctx-clear-filters", title: "Clear All Filters", icon: "line.3.horizontal.decrease.circle", category: .plan, spaceScope: "Plan")
    ) {
        appState.intentViewModel.clearFilters()
    }

    // MARK: - Build Space Contextual

    registry.register(
        AnvilCommand(id: "ctx-new-session", title: "New Build Session", icon: "cpu", category: .agent, keyboardShortcut: "\u{2318}\u{21E7}A", spaceScope: "Build")
    ) {
        appState.switchSpace(.build)
        appState.agentViewModel.startNewSession(prompt: "", model: "claude-sonnet-4-6")
    }

    registry.register(
        AnvilCommand(id: "ctx-source-control", title: "Toggle Source Control Panel", icon: "arrow.triangle.branch", category: .editor, spaceScope: "Build", group: "Git")
    ) {
        appState.isSourceControlVisible.toggle()
    }

    registry.register(
        AnvilCommand(id: "ctx-toggle-whitespace", title: "Toggle Whitespace Visibility", subtitle: "Cycle: None \u{2192} Boundary \u{2192} All", icon: "eye", category: .editor, spaceScope: "Build", group: "Editor")
    ) {
        appState.editorViewModel.cycleWhitespace()
    }

    registry.register(
        AnvilCommand(id: "ctx-toggle-wordwrap", title: "Toggle Word Wrap", icon: "text.word.spacing", category: .editor, keyboardShortcut: "\u{2325}Z", spaceScope: "Build", group: "Editor")
    ) {
        appState.editorViewModel.toggleWordWrap()
    }

    registry.register(
        AnvilCommand(id: "ctx-toggle-indent-guides", title: "Toggle Indent Guides", icon: "line.3.horizontal", category: .editor, spaceScope: "Build", group: "Editor")
    ) {
        appState.editorViewModel.showIndentGuides.toggle()
    }

    registry.register(
        AnvilCommand(id: "ctx-toggle-git-gutter", title: "Toggle Git Gutter", icon: "arrow.triangle.branch", category: .editor, spaceScope: "Build", group: "Git")
    ) {
        appState.editorViewModel.showGitGutter.toggle()
    }

    registry.register(
        AnvilCommand(id: "ctx-toggle-bracket-matching", title: "Toggle Bracket Matching", icon: "curlybraces", category: .editor, spaceScope: "Build", group: "Editor")
    ) {
        appState.editorViewModel.showBracketMatching.toggle()
    }

    registry.register(
        AnvilCommand(id: "ctx-toggle-code-folding", title: "Toggle Code Folding", icon: "chevron.down.square", category: .editor, spaceScope: "Build", group: "Editor")
    ) {
        appState.editorViewModel.codeFoldingEnabled.toggle()
    }

    registry.register(
        AnvilCommand(id: "ctx-fold-all", title: "Fold All Regions", icon: "arrow.down.right.and.arrow.up.left", category: .editor, keyboardShortcut: "\u{2318}\u{2325}[", spaceScope: "Build", group: "Editor")
    ) {
        if let file = appState.editorViewModel.selectedFile {
            let lines = file.content.components(separatedBy: "\n")
            appState.editorViewModel.foldAll(lines: lines)
        }
    }

    registry.register(
        AnvilCommand(id: "ctx-unfold-all", title: "Unfold All Regions", icon: "arrow.up.left.and.arrow.down.right", category: .editor, keyboardShortcut: "\u{2318}\u{2325}]", spaceScope: "Build", group: "Editor")
    ) {
        appState.editorViewModel.unfoldAll()
    }

    registry.register(
        AnvilCommand(id: "ctx-new-terminal", title: "New Terminal Session", icon: "plus.square", category: .terminal, keyboardShortcut: "\u{2318}\u{21E7}T", spaceScope: "Build", group: "Terminal")
    ) {
        appState.switchSpace(.build)
        _ = appState.terminalViewModel.addTab()
    }

    registry.register(
        AnvilCommand(id: "ctx-split-terminal-vertical", title: "Split Terminal Right", icon: "rectangle.split.2x1", category: .terminal, keyboardShortcut: "\u{2318}\\", spaceScope: "Build", group: "Terminal")
    ) {
        appState.switchSpace(.build)
        appState.triggerSplitVertical = true
    }

    registry.register(
        AnvilCommand(id: "ctx-split-terminal-horizontal", title: "Split Terminal Down", icon: "rectangle.split.1x2", category: .terminal, keyboardShortcut: "\u{2318}\u{21E7}\\", spaceScope: "Build", group: "Terminal")
    ) {
        appState.switchSpace(.build)
        appState.triggerSplitHorizontal = true
    }

    registry.register(
        AnvilCommand(id: "ctx-clear-terminal", title: "Clear Active Terminal", icon: "eraser", category: .terminal, keyboardShortcut: "\u{2318}K", spaceScope: "Build", group: "Terminal")
    ) {
        appState.switchSpace(.build)
        appState.terminalViewModel.clearBuffer()
    }

    // MARK: - Review Space Contextual

    registry.register(
        AnvilCommand(id: "ctx-refresh-prs", title: "Refresh Pull Requests", icon: "arrow.clockwise", category: .review, spaceScope: "Review", group: "Git")
    ) {
        // Triggers PR refresh in review mode
    }

    registry.register(
        AnvilCommand(id: "ctx-review-source-control", title: "Toggle Source Control Panel", icon: "arrow.triangle.branch", category: .review, spaceScope: "Review", group: "Git")
    ) {
        appState.isSourceControlVisible.toggle()
    }

    // MARK: - Operate Space Contextual

    registry.register(
        AnvilCommand(id: "ctx-refresh-deploys", title: "Refresh Deployments", icon: "arrow.clockwise", category: .operate, spaceScope: "Operate")
    ) {
        // Triggers deploy refresh in operate mode
    }
}
