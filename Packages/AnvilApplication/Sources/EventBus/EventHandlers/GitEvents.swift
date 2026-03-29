import Foundation
import AnvilDomain

public struct BranchCreatedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "source-control"
    public let branchName: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, branchName: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.branchName = branchName
    }
}

public struct CommitCreatedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "source-control"
    public let commitHash: String
    public let message: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, commitHash: String, message: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.commitHash = commitHash
        self.message = message
    }
}

public struct DraftPRCreatedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "source-control"
    public let sessionId: String
    public let prNumber: Int
    public let url: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, sessionId: String, prNumber: Int, url: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.prNumber = prNumber
        self.url = url
    }
}

public struct PushCompletedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "source-control"
    public let branch: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, branch: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.branch = branch
    }
}
