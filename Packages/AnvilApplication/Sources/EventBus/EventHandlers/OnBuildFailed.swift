import Foundation
import AnvilDomain

public struct BuildFailedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "cicd"
    public let buildId: String
    public let pipelineName: String
    public let branch: String
    public let failureReason: String?

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, buildId: String, pipelineName: String, branch: String, failureReason: String? = nil) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.buildId = buildId
        self.pipelineName = pipelineName
        self.branch = branch
        self.failureReason = failureReason
    }
}
