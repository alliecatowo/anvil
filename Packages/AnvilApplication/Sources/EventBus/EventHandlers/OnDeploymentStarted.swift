import Foundation
import AnvilDomain

public struct DeploymentStartedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "hosting"
    public let deploymentId: String
    public let environmentId: String
    public let branch: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, deploymentId: String, environmentId: String, branch: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.deploymentId = deploymentId
        self.environmentId = environmentId
        self.branch = branch
    }
}
