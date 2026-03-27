import Foundation

public protocol TicketPort: AnvilProviderDefinition {
    func tickets(filter: TicketFilter?) async throws -> [Ticket]
    func ticketDetail(id: String) async throws -> Ticket
    func createTicket(_ draft: TicketDraft) async throws -> Ticket
    func updateTicket(id: String, changes: TicketUpdate) async throws -> Ticket
    func deleteTicket(id: String) async throws
    func cycles() async throws -> [Cycle]
    func boards() async throws -> [Board]
    func relations(ticketId: String) async throws -> [TicketRelation]
    func addRelation(type: TicketRelationType, source: String, target: String) async throws
    func moveToStatus(ticketId: String, status: String) async throws
}
