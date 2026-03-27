import Foundation

public protocol HostingPort: AnvilProviderDefinition {
    func deploy(projectPath: String, environment: HostingEnvironment) async throws -> Deployment
    func deployments(projectId: String) async throws -> [Deployment]
    func deploymentStatus(deploymentId: String) async throws -> Deployment
    func rollback(deploymentId: String) async throws -> Deployment
    func environments(projectId: String) async throws -> [HostingEnvironment]
    func buildLogs(deploymentId: String) async throws -> [BuildLog]
    func environmentVariables(environmentId: String) async throws -> [String: String]
    func setEnvironmentVariable(environmentId: String, key: String, value: String) async throws
}
