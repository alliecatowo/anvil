import AnvilDomain
import Foundation

/// Triggers a new deployment through the DeploymentManagementPort and publishes
/// a DeploymentStartedEvent on the EventBus so downstream subscribers can react.
public struct CreateDeploymentUseCase: Sendable {
    private let deploymentPort: any DeploymentManagementPort
    private let eventBus: EventBus

    public init(deploymentPort: any DeploymentManagementPort, eventBus: EventBus) {
        self.deploymentPort = deploymentPort
        self.eventBus = eventBus
    }

    public func execute(environmentId: String, branch: String) async throws -> Deployment {
        let deployment = try await deploymentPort.triggerDeployment(
            environmentId: environmentId,
            branch: branch
        )
        await eventBus.publish(DeploymentStartedEvent(
            deploymentId: deployment.id,
            environmentId: deployment.environmentId,
            branch: branch
        ))
        return deployment
    }
}
