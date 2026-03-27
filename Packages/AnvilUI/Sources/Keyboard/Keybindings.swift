import SwiftUI

public struct Keybinding: Identifiable, Sendable {
    public let id: String
    public let key: KeyEquivalent
    public let modifiers: EventModifiers
    public let action: String
    public let context: KeybindingContext
    public let label: String

    public init(
        id: String,
        key: KeyEquivalent,
        modifiers: EventModifiers = [],
        action: String,
        context: KeybindingContext = .global,
        label: String
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.action = action
        self.context = context
        self.label = label
    }
}

public enum KeybindingContext: String, Sendable {
    case global
    case list
    case editor
    case review
    case agent
}

public enum AnvilKeybindings {
    public static let all: [Keybinding] = [
        // MARK: - Global

        Keybinding(id: "cmd-k", key: "k", modifiers: .command, action: "commandPalette", label: "Command Palette"),
        Keybinding(id: "cmd-shift-p", key: "p", modifiers: [.command, .shift], action: "commandsOnly", label: "Commands Only"),
        Keybinding(id: "cmd-e", key: "e", modifiers: .command, action: "quickSwitch", label: "Quick Switch"),
        Keybinding(id: "cmd-1", key: "1", modifiers: .command, action: "mode.intent", label: "Intent Mode"),
        Keybinding(id: "cmd-2", key: "2", modifiers: .command, action: "mode.agent", label: "Agent Mode"),
        Keybinding(id: "cmd-3", key: "3", modifiers: .command, action: "mode.review", label: "Review Mode"),
        Keybinding(id: "cmd-4", key: "4", modifiers: .command, action: "mode.ship", label: "Ship Mode"),
        Keybinding(id: "cmd-5", key: "5", modifiers: .command, action: "mode.editor", label: "Editor Mode"),
        Keybinding(id: "cmd-6", key: "6", modifiers: .command, action: "mode.database", label: "Database Mode"),
        Keybinding(id: "cmd-7", key: "7", modifiers: .command, action: "mode.terminal", label: "Terminal Mode"),
        Keybinding(id: "cmd-8", key: "8", modifiers: .command, action: "mode.docs", label: "Docs Mode"),
        Keybinding(id: "cmd-9", key: "9", modifiers: .command, action: "mode.messaging", label: "Messaging Mode"),
        Keybinding(id: "cmd-0", key: "0", modifiers: .command, action: "mode.notifications", label: "Notifications Mode"),
        Keybinding(id: "cmd-n", key: "n", modifiers: .command, action: "newItem", label: "New Item"),
        Keybinding(id: "cmd-shift-a", key: "a", modifiers: [.command, .shift], action: "newAgentSession", label: "New Agent Session"),
        Keybinding(id: "cmd-shift-n", key: "n", modifiers: [.command, .shift], action: "appendProjectNotes", label: "Append to Project Notes"),
        Keybinding(id: "cmd-b", key: "b", modifiers: .command, action: "toggleSidebar", label: "Toggle Sidebar"),
        Keybinding(id: "cmd-j", key: "j", modifiers: .command, action: "toggleTerminal", label: "Toggle Terminal"),
        Keybinding(id: "cmd-shift-i", key: "i", modifiers: [.command, .shift], action: "toggleInspector", label: "Toggle Inspector"),
        Keybinding(id: "cmd-t", key: "t", modifiers: .command, action: "newTab", label: "New Tab"),
        Keybinding(id: "cmd-w", key: "w", modifiers: .command, action: "closeTab", label: "Close Tab"),
        Keybinding(id: "cmd-comma", key: ",", modifiers: .command, action: "settings", label: "Settings"),
        Keybinding(id: "cmd-period", key: ".", modifiers: .command, action: "quickActions", label: "Quick Actions"),
        Keybinding(id: "cmd-shift-o", key: "o", modifiers: [.command, .shift], action: "projectSwitcher", label: "Switch Project"),
        Keybinding(id: "ctrl-g", key: "g", modifiers: .control, action: "goToLine", label: "Go to Line"),

        // MARK: - List Navigation

        Keybinding(id: "list-j", key: "j", action: "list.moveDown", context: .list, label: "Move Down"),
        Keybinding(id: "list-k", key: "k", action: "list.moveUp", context: .list, label: "Move Up"),
        Keybinding(id: "list-x", key: "x", action: "list.toggleSelect", context: .list, label: "Toggle Select"),
        Keybinding(id: "list-slash", key: "/", action: "list.filter", context: .list, label: "Filter"),

        // MARK: - Review Mode

        Keybinding(id: "review-a", key: "a", action: "review.approve", context: .review, label: "Approve"),
        Keybinding(id: "review-r", key: "r", action: "review.requestChanges", context: .review, label: "Request Changes"),
        Keybinding(id: "review-c", key: "c", action: "review.comment", context: .review, label: "Comment"),
        Keybinding(id: "review-n", key: "n", action: "review.nextHunk", context: .review, label: "Next Hunk"),
        Keybinding(id: "review-p", key: "p", action: "review.prevHunk", context: .review, label: "Previous Hunk"),
        Keybinding(id: "review-d", key: "d", action: "review.toggleDiffMode", context: .review, label: "Toggle Diff Mode"),

        // MARK: - Agent Mode

        Keybinding(id: "agent-y", key: "y", action: "agent.approveToolCall", context: .agent, label: "Approve Tool Call"),
        Keybinding(id: "agent-n", key: "n", action: "agent.rejectToolCall", context: .agent, label: "Reject Tool Call"),
    ]

    public static func bindings(for context: KeybindingContext) -> [Keybinding] {
        all.filter { $0.context == context }
    }
}
