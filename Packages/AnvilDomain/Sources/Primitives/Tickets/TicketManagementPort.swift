import Foundation

/// Internal ticket management port for CRUD operations on tickets.
/// This is the "management" counterpart to TicketPort (which targets external
/// providers like Linear or Jira). ViewModels and use cases depend on this
/// protocol; adapters provide concrete implementations.
public protocol TicketManagementPort: Sendable {
    func fetchTickets() async throws -> [Ticket]
    func createTicket(_ ticket: Ticket) async throws -> Ticket
    func updateTicket(_ ticket: Ticket) async throws -> Ticket
    func deleteTicket(id: String) async throws
    func moveTicket(id: String, toStatus: String) async throws -> Ticket
}
