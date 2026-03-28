import Foundation

public protocol DeploymentManagementPort: Sendable {
    func fetchDeployments(for environmentId: String) async throws -> [Deployment]
    func triggerDeployment(environmentId: String, branch: String) async throws -> Deployment
    func cancelDeployment(id: String) async throws
}
