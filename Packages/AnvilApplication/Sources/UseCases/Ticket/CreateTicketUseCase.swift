import AnvilDomain
import Foundation

/// Creates a new ticket and persists it through TicketManagementPort.
public struct CreateTicketUseCase: Sendable {
    private let ticketPort: any TicketManagementPort
    private let eventBus: EventBus

    public init(ticketPort: any TicketManagementPort, eventBus: EventBus) {
        self.ticketPort = ticketPort
        self.eventBus = eventBus
    }

    public func execute(
        title: String,
        description: String = "",
        status: String = "backlog",
        priority: TicketPriority = .medium,
        assignee: String? = nil,
        labels: [String] = [],
        dueDate: Date? = nil,
        storyPoints: Int? = nil
    ) async throws -> Ticket {
        let ticket = Ticket(
            title: title,
            description: description,
            status: status,
            priority: priority,
            assignee: assignee,
            labels: labels,
            dueDate: dueDate,
            storyPoints: storyPoints
        )
        let created = try await ticketPort.createTicket(ticket)
        await eventBus.publish(TicketCreatedEvent(
            ticketId: created.id, title: created.title
        ))
        return created
    }
}
