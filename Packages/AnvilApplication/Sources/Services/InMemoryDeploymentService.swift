import AnvilDomain
import Foundation

/// In-memory deployment store -- default implementation until a real hosting backend is wired.
public actor InMemoryDeploymentService: DeploymentManagementPort {
    private var deployments: [String: Deployment] = [:]

    public init() {}

    public func fetchDeployments(for environmentId: String) async throws -> [Deployment] {
        deployments.values
            .filter { $0.environmentId == environmentId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func triggerDeployment(environmentId: String, branch: String) async throws -> Deployment {
        let deployment = Deployment(
            projectId: "default",
            environmentId: environmentId,
            commitHash: String(UUID().uuidString.prefix(7)),
            status: .building
        )
        deployments[deployment.id] = deployment
        return deployment
    }

    public func cancelDeployment(id: String) async throws {
        guard deployments.removeValue(forKey: id) != nil else {
            throw DeploymentServiceError.notFound
        }
    }
}

public enum DeploymentServiceError: Error, Sendable {
    case notFound
}
