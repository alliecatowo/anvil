import Foundation
import AnvilDomain

// DeploymentStartedEvent is defined in OnDeploymentStarted.swift

public struct EnvVarAddedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "hosting"
    public let environmentId: String
    public let key: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, environmentId: String, key: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.environmentId = environmentId
        self.key = key
    }
}

public struct EnvVarUpdatedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "hosting"
    public let environmentId: String
    public let key: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, environmentId: String, key: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.environmentId = environmentId
        self.key = key
    }
}

public struct EnvVarDeletedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "hosting"
    public let environmentId: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, environmentId: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.environmentId = environmentId
    }
}
