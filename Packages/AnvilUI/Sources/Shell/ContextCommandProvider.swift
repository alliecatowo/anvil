import AnvilDomain
import SwiftUI

/// Provides entity-aware, context-sensitive commands based on what is currently
/// selected in the active space. These commands appear at the top of the command
/// palette under a "Context" section so they are immediately actionable.
struct ContextCommandProvider {

    /// Returns context-sensitive commands based on the focused entity.
    /// When no entity is focused, falls back to space-level generic commands.
    @MainActor
    static func commands(for appState: AppState) -> [CommandItem] {
        guard let entity = appState.focusedEntity else {
            return fallbackCommands(for: appState.currentSpace)
        }

        switch entity {
        case .ticket(let id, _):
            if let ticket = appState.intentViewModel.selectedTicket {
                return ticketCommands(ticket: ticket, appState: appState)
            }
            return [basicTicketCommand(id: id)]
        case .file(let path, let name):
            return fileCommands(path: path, name: name)
        case .agentSession(let id, let name):
            return agentSessionCommands(id: id, name: name, appState: appState)
        case .pullRequest(let id, let title):
            return pullRequestCommands(id: id, title: title, appState: appState)
        }
    }

    // MARK: - Ticket Commands

    @MainActor
    private static func ticketCommands(ticket: Ticket, appState: AppState) -> [CommandItem] {
        var items: [CommandItem] = []

        items.append(CommandItem(
            id: "entity-start-work-\(ticket.id)",
            title: "Start Work",
            subtitle: "\(ticket.id) — \(ticket.title)",
            icon: "play.fill",
            iconColor: AnvilColor.accentGreen,
            category: .entityContext,
            action: .startAgentForTicket(
                ticketId: ticket.id,
                title: ticket.title,
                description: ticket.description
            )
        ))

        items.append(CommandItem(
            id: "entity-edit-ticket-\(ticket.id)",
            title: "Edit Ticket",
            subtitle: ticket.title,
            icon: "pencil",
            iconColor: AnvilColor.accentBlue,
            category: .entityContext,
            action: .editTicket(ticketId: ticket.id)
        ))

        items.append(CommandItem(
            id: "entity-change-status-\(ticket.id)",
            title: "Change Status",
            subtitle: "Current: \(ticket.status.capitalized)",
            icon: "arrow.triangle.2.circlepath",
            iconColor: AnvilColor.accentAmber,
            category: .entityContext,
            action: .changeTicketStatus(ticketId: ticket.id)
        ))

        items.append(CommandItem(
            id: "entity-add-subtask-\(ticket.id)",
            title: "Add Subtask",
            subtitle: ticket.title,
            icon: "plus.circle",
            iconColor: AnvilColor.accentTeal,
            category: .entityContext,
            action: .addSubtask(ticketId: ticket.id)
        ))

        items.append(CommandItem(
            id: "entity-delete-ticket-\(ticket.id)",
            title: "Delete Ticket",
            subtitle: ticket.title,
            icon: "trash",
            iconColor: AnvilColor.accentRed,
            category: .entityContext,
            action: .deleteTicket(ticketId: ticket.id)
        ))

        return items
    }

    private static func basicTicketCommand(id: String) -> CommandItem {
        CommandItem(
            id: "entity-edit-ticket-\(id)",
            title: "Edit Ticket",
            subtitle: id,
            icon: "pencil",
            iconColor: AnvilColor.accentBlue,
            category: .entityContext,
            action: .editTicket(ticketId: id)
        )
    }

    // MARK: - File Commands

    private static func fileCommands(path: String, name: String) -> [CommandItem] {
        [
            CommandItem(
                id: "entity-open-file",
                title: "Open File",
                subtitle: name,
                icon: "doc.text",
                iconColor: AnvilColor.accentBlue,
                category: .entityContext,
                action: .openFile(path: path)
            ),
            CommandItem(
                id: "entity-rename-file",
                title: "Rename File",
                subtitle: name,
                icon: "pencil.line",
                iconColor: AnvilColor.accentAmber,
                category: .entityContext,
                action: .renameFile(path: path)
            ),
            CommandItem(
                id: "entity-copy-path",
                title: "Copy Path",
                subtitle: path,
                icon: "doc.on.doc",
                category: .entityContext,
                action: .copyFilePath(path: path)
            ),
            CommandItem(
                id: "entity-run-tests-file",
                title: "Run Tests for File",
                subtitle: name,
                icon: "testtube.2",
                iconColor: AnvilColor.accentGreen,
                category: .entityContext,
                action: .runTestsForFile(path: path)
            ),
        ]
    }

    // MARK: - Agent Session Commands

    @MainActor
    private static func agentSessionCommands(id: String, name: String, appState: AppState) -> [CommandItem] {
        var items: [CommandItem] = []

        items.append(CommandItem(
            id: "entity-open-session-\(id)",
            title: "Open Session",
            subtitle: name,
            icon: "bubble.left.and.text.bubble.right",
            iconColor: AnvilColor.accentBlue,
            category: .entityContext,
            action: .openAgentSession(sessionId: id)
        ))

        let session = appState.agentViewModel.selectedSession
        if session?.status == .running || session?.status == .paused {
            items.append(CommandItem(
                id: "entity-stop-session-\(id)",
                title: "Stop Session",
                subtitle: name,
                icon: "stop.fill",
                iconColor: AnvilColor.accentRed,
                category: .entityContext,
                action: .stopAgentSession(sessionId: id)
            ))
        }

        items.append(CommandItem(
            id: "entity-export-session-\(id)",
            title: "Export Session",
            subtitle: name,
            icon: "square.and.arrow.up",
            iconColor: AnvilColor.accentGreen,
            category: .entityContext,
            action: .exportAgentSession(sessionId: id)
        ))

        return items
    }

    // MARK: - Pull Request Commands

    @MainActor
    private static func pullRequestCommands(id: String, title: String, appState: AppState) -> [CommandItem] {
        var items: [CommandItem] = []

        items.append(CommandItem(
            id: "entity-approve-pr-\(id)",
            title: "Approve",
            subtitle: title,
            icon: "checkmark.circle",
            iconColor: AnvilColor.accentGreen,
            category: .entityContext,
            action: .approveReview(reviewId: id)
        ))

        items.append(CommandItem(
            id: "entity-request-changes-pr-\(id)",
            title: "Request Changes",
            subtitle: title,
            icon: "exclamationmark.circle",
            iconColor: AnvilColor.accentAmber,
            category: .entityContext,
            action: .requestReviewChanges(reviewId: id)
        ))

        items.append(CommandItem(
            id: "entity-merge-pr-\(id)",
            title: "Merge",
            subtitle: title,
            icon: "arrow.triangle.merge",
            iconColor: AnvilColor.accentPurple,
            category: .entityContext,
            action: .mergePullRequest(prId: id)
        ))

        return items
    }

    // MARK: - Fallback (no entity focused)

    private static func fallbackCommands(for space: AnvilSpace) -> [CommandItem] {
        switch space {
        case .build:
            return [
                CommandItem(
                    id: "entity-find-in-files",
                    title: "Find in Files",
                    icon: "magnifyingglass",
                    iconColor: AnvilColor.accentBlue,
                    shortcut: "\u{2318}\u{21E7}F",
                    category: .entityContext,
                    action: .searchInFiles
                ),
                CommandItem(
                    id: "entity-open-terminal",
                    title: "Open Terminal",
                    icon: "terminal",
                    iconColor: AnvilColor.accentGreen,
                    shortcut: "\u{2318}J",
                    category: .entityContext,
                    action: .toggleTerminal
                ),
                CommandItem(
                    id: "entity-go-to-line",
                    title: "Go to Line",
                    icon: "arrow.right.to.line",
                    iconColor: AnvilColor.accentPurple,
                    shortcut: "\u{2318}G",
                    category: .entityContext,
                    action: .goToLine
                ),
            ]
        default:
            return []
        }
    }
}
