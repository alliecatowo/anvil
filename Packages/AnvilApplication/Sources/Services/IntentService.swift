import Foundation
import AnvilDomain

/// Application-layer service for ticket (intent) management.
/// Owns the canonical ticket list, wraps TicketManagementPort, and publishes
/// domain events via EventBus. ViewModels observe @Published properties only.
@MainActor
public final class IntentService: ObservableObject {

    // MARK: Published state

    @Published public var tickets: [Ticket] = []

    // MARK: Dependencies

    private let ticketPort: any TicketManagementPort
    private let eventBus: EventBus

    public init(ticketPort: any TicketManagementPort, eventBus: EventBus) {
        self.ticketPort = ticketPort
        self.eventBus = eventBus
    }

    // MARK: - Load

    public func loadTickets() {
        Task {
            if let fetched = try? await ticketPort.fetchTickets() {
                tickets = fetched
            }
        }
    }

    // MARK: - CRUD

    public func createTicket(
        title: String,
        description: String = "",
        status: String = "backlog",
        priority: TicketPriority = .medium,
        assignee: String? = nil,
        dueDate: Date? = nil,
        storyPoints: Int? = nil
    ) async throws -> Ticket {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let ticket = Ticket(
            title: trimmed,
            description: description,
            status: status,
            priority: priority,
            assignee: assignee,
            dueDate: dueDate,
            storyPoints: storyPoints
        )
        let created = try await ticketPort.createTicket(ticket)
        tickets.append(created)
        await eventBus.publish(TicketCreatedEvent(ticketId: created.id, title: trimmed))
        return created
    }

    public func updateTicket(_ ticket: Ticket) async throws -> Ticket {
        let updated = try await ticketPort.updateTicket(ticket)
        if let idx = tickets.firstIndex(where: { $0.id == updated.id }) {
            tickets[idx] = updated
        }
        await eventBus.publish(TicketUpdatedEvent(ticketId: updated.id, field: "ticket", newValue: updated.title))
        return updated
    }

    public func moveTicket(id: String, toStatus newStatus: String) {
        guard let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        tickets[idx].status = newStatus
        tickets[idx].updatedAt = .now
        let snapshot = tickets[idx]
        Task {
            _ = try? await ticketPort.moveTicket(id: id, toStatus: newStatus)
            await eventBus.publish(TicketUpdatedEvent(ticketId: id, field: "status", newValue: newStatus))
        }
        _ = snapshot
    }

    public func deleteTicket(id: String) {
        tickets.removeAll { $0.id == id }
        Task {
            try? await ticketPort.deleteTicket(id: id)
            await eventBus.publish(TicketDeletedEvent(ticketId: id))
        }
    }

    public func updateField(_ ticketId: String, field: String, apply: (inout Ticket) -> Void) {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        apply(&tickets[idx])
        tickets[idx].updatedAt = .now
        let snapshot = tickets[idx]
        Task { [snapshot] in
            _ = try? await ticketPort.updateTicket(snapshot)
            await eventBus.publish(TicketUpdatedEvent(ticketId: ticketId, field: field, newValue: ""))
        }
    }
}
