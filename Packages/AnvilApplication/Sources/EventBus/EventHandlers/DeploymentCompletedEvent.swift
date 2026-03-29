import Foundation
import AnvilDomain

public struct DeploymentCompletedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "hosting"
    public let deploymentId: String
    public let environmentId: String
    public let success: Bool
    public let message: String?

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, deploymentId: String, environmentId: String, success: Bool, message: String? = nil) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.deploymentId = deploymentId
        self.environmentId = environmentId
        self.success = success
        self.message = message
    }
}
