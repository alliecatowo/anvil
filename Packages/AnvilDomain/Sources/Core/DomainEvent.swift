import Foundation

public protocol AnvilDomainEvent: Sendable {
    var eventId: String { get }
    var timestamp: Date { get }
    var sourcePrimitive: String { get }
}

public struct AnyDomainEvent: AnvilDomainEvent, Sendable {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String
    public let payload: any Sendable

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, sourcePrimitive: String, payload: any Sendable) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.sourcePrimitive = sourcePrimitive
        self.payload = payload
    }
}
