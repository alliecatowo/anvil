import AnvilDomain
import SwiftUI

/// Provides entity-aware, context-sensitive commands based on what is currently
/// selected in the active space. These commands appear at the top of the command
/// palette under a "Context" section so they are immediately actionable.
struct ContextCommandProvider {

    /// Returns context-sensitive commands based on the current space and any
    /// focused entity (selected ticket, selected PR, etc.).
    @MainActor
    static func commands(for appState: AppState) -> [CommandItem] {
        var commands: [CommandItem] = []

        switch appState.currentSpace {
        case .plan:
            if let ticket = appState.intentViewModel.selectedTicket {
                commands += planCommands(ticket: ticket, appState: appState)
            }
        case .review:
            if let review = appState.reviewViewModel.selectedReview {
                commands += reviewCommands(review: review)
            }
        case .build:
            commands += buildEntityCommands(appState: appState)
        default:
            break
        }

        return commands
    }

    // MARK: - Plan Commands (ticket focused)

    @MainActor
    private static func planCommands(ticket: Ticket, appState: AppState) -> [CommandItem] {
        var items: [CommandItem] = []

        items.append(CommandItem(
            id: "entity-edit-ticket-\(ticket.id)",
            title: "Edit Ticket: \(ticket.title)",
            subtitle: ticket.id,
            icon: "pencil",
            iconColor: AnvilColor.accentBlue,
            category: .entityContext,
            action: .editTicket(ticketId: ticket.id)
        ))

        items.append(CommandItem(
            id: "entity-assign-ticket-\(ticket.id)",
            title: "Assign to Me",
            subtitle: ticket.assignee.map { "Currently: \($0)" } ?? "Unassigned",
            icon: "person.badge.plus",
            iconColor: AnvilColor.accentGreen,
            category: .entityContext,
            action: .assignTicketToMe(ticketId: ticket.id)
        ))

        if ticket.status != "in progress" {
            items.append(CommandItem(
                id: "entity-mark-inprogress-\(ticket.id)",
                title: "Mark In Progress",
                subtitle: "Current: \(ticket.status.capitalized)",
                icon: "circle.lefthalf.filled",
                iconColor: AnvilColor.accentBlue,
                category: .entityContext,
                action: .markTicketInProgress(ticketId: ticket.id)
            ))
        }

        items.append(CommandItem(
            id: "entity-agent-ticket-\(ticket.id)",
            title: "Start Agent Session for Ticket",
            subtitle: "\(ticket.id) - \(ticket.title)",
            icon: "cpu",
            iconColor: AnvilColor.accentPurple,
            category: .entityContext,
            action: .startAgentForTicket(
                ticketId: ticket.id,
                title: ticket.title,
                description: ticket.description
            )
        ))

        items.append(CommandItem(
            id: "entity-copy-ticket-id-\(ticket.id)",
            title: "Copy Ticket ID",
            subtitle: ticket.id,
            icon: "doc.on.doc",
            category: .entityContext,
            action: .copyTicketId(ticketId: ticket.id)
        ))

        return items
    }

    // MARK: - Review Commands (PR/review focused)

    private static func reviewCommands(review: Review) -> [CommandItem] {
        var items: [CommandItem] = []

        if review.status == .pending {
            items.append(CommandItem(
                id: "entity-approve-review-\(review.id)",
                title: "Approve Review",
                subtitle: review.title,
                icon: "checkmark.circle",
                iconColor: AnvilColor.accentGreen,
                category: .entityContext,
                action: .approveReview(reviewId: review.id)
            ))

            items.append(CommandItem(
                id: "entity-request-changes-\(review.id)",
                title: "Request Changes",
                subtitle: review.title,
                icon: "exclamationmark.circle",
                iconColor: AnvilColor.accentAmber,
                category: .entityContext,
                action: .requestReviewChanges(reviewId: review.id)
            ))
        }

        if review.sourceType == .pullRequest {
            items.append(CommandItem(
                id: "entity-open-source-\(review.id)",
                title: "Open in GitHub",
                subtitle: review.sourceId,
                icon: "arrow.up.right.square",
                iconColor: AnvilColor.accentBlue,
                category: .entityContext,
                action: .openReviewSource(sourceId: review.sourceId)
            ))

            items.append(CommandItem(
                id: "entity-copy-url-\(review.id)",
                title: "Copy PR URL",
                subtitle: review.sourceId,
                icon: "doc.on.doc",
                category: .entityContext,
                action: .copyReviewURL(sourceId: review.sourceId)
            ))
        }

        return items
    }

    // MARK: - Build Commands (editor entity-aware)

    @MainActor
    private static func buildEntityCommands(appState: AppState) -> [CommandItem] {
        var items: [CommandItem] = []

        items.append(CommandItem(
            id: "entity-find-in-files",
            title: "Find in Files",
            icon: "magnifyingglass",
            iconColor: AnvilColor.accentBlue,
            shortcut: "\u{2318}\u{21E7}F",
            category: .entityContext,
            action: .searchInFiles
        ))

        items.append(CommandItem(
            id: "entity-open-terminal",
            title: "Open Terminal",
            icon: "terminal",
            iconColor: AnvilColor.accentGreen,
            shortcut: "\u{2318}J",
            category: .entityContext,
            action: .toggleTerminal
        ))

        items.append(CommandItem(
            id: "entity-go-to-line",
            title: "Go to Line",
            icon: "arrow.right.to.line",
            iconColor: AnvilColor.accentPurple,
            shortcut: "\u{2318}G",
            category: .entityContext,
            action: .goToLine
        ))

        return items
    }
}
