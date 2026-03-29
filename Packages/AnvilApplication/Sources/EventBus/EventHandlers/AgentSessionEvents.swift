import Foundation
import AnvilDomain

public struct AgentSessionStartedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "agents"
    public let sessionId: String
    public let model: String
    public let workItemId: String?

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, sessionId: String, model: String, workItemId: String? = nil) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.model = model
        self.workItemId = workItemId
    }
}

public struct AgentProviderSwitchedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "agents"
    public let sessionId: String
    public let previousProvider: String
    public let newProvider: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, sessionId: String, previousProvider: String, newProvider: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.previousProvider = previousProvider
        self.newProvider = newProvider
    }
}

public struct AgentSessionFailedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "agents"
    public let sessionId: String
    public let error: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, sessionId: String, error: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.error = error
    }
}
