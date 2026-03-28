import AnvilDomain
import Foundation

/// In-memory ticket store -- default implementation until a real backend is wired.
public actor InMemoryTicketService: TicketManagementPort {
    private var tickets: [String: Ticket] = [:]

    public init() {}

    public func fetchTickets() async throws -> [Ticket] {
        Array(tickets.values).sorted { $0.createdAt > $1.createdAt }
    }

    public func createTicket(_ ticket: Ticket) async throws -> Ticket {
        tickets[ticket.id] = ticket
        return ticket
    }

    public func updateTicket(_ ticket: Ticket) async throws -> Ticket {
        guard tickets[ticket.id] != nil else { throw TicketServiceError.notFound }
        tickets[ticket.id] = ticket
        return ticket
    }

    public func deleteTicket(id: String) async throws {
        guard tickets.removeValue(forKey: id) != nil else { throw TicketServiceError.notFound }
    }

    public func moveTicket(id: String, toStatus newStatus: String) async throws -> Ticket {
        guard var ticket = tickets[id] else { throw TicketServiceError.notFound }
        ticket.status = newStatus
        ticket.updatedAt = .now
        tickets[id] = ticket
        return ticket
    }
}

public enum TicketServiceError: Error, Sendable {
    case notFound
}
