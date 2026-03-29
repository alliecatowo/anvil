import Foundation
import AnvilDomain

public struct ReviewApprovedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "review"
    public let reviewId: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, reviewId: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.reviewId = reviewId
    }
}

public struct ReviewCreatedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "review"
    public let reviewId: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, reviewId: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.reviewId = reviewId
    }
}

public struct ReviewUpdatedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "review"
    public let reviewId: String
    public let status: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, reviewId: String, status: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.reviewId = reviewId
        self.status = status
    }
}

public struct InlineCommentAddedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "review"
    public let reviewId: String
    public let fileId: String
    public let lineNumber: Int

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, reviewId: String, fileId: String, lineNumber: Int) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.reviewId = reviewId
        self.fileId = fileId
        self.lineNumber = lineNumber
    }
}
