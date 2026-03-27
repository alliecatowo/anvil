import Foundation
import AnvilDomain

public struct AgentCompletedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "agents"
    public let sessionId: String
    public let workItemId: String?
    public let branchName: String?

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, sessionId: String, workItemId: String? = nil, branchName: String? = nil) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.workItemId = workItemId
        self.branchName = branchName
    }
}
