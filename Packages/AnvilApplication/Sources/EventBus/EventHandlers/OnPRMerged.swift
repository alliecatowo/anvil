import Foundation
import AnvilDomain

public struct PRMergedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "source-control-cloud"
    public let pullRequestId: String
    public let repo: String
    public let branch: String
    public let linkedTicketId: String?

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, pullRequestId: String, repo: String, branch: String, linkedTicketId: String? = nil) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.pullRequestId = pullRequestId
        self.repo = repo
        self.branch = branch
        self.linkedTicketId = linkedTicketId
    }
}
