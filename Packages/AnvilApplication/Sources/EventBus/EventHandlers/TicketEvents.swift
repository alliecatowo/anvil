import Foundation
import AnvilDomain

public struct TicketCreatedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "tickets"
    public let ticketId: String
    public let title: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, ticketId: String, title: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.ticketId = ticketId
        self.title = title
    }
}

public struct TicketUpdatedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "tickets"
    public let ticketId: String
    public let field: String
    public let newValue: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, ticketId: String, field: String, newValue: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.ticketId = ticketId
        self.field = field
        self.newValue = newValue
    }
}

public struct TicketDeletedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "tickets"
    public let ticketId: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, ticketId: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.ticketId = ticketId
    }
}
