import Foundation

public protocol PackageManagementPort: AnvilProviderDefinition {
    func dependencies(projectPath: String) async throws -> [Dependency]
    func outdated(projectPath: String) async throws -> [Dependency]
    func vulnerabilities(projectPath: String) async throws -> [Vulnerability]
    func addDependency(projectPath: String, name: String, version: String?) async throws -> Dependency
    func removeDependency(projectPath: String, name: String) async throws
    func updateDependency(projectPath: String, name: String, version: String) async throws -> Dependency
    func audit(projectPath: String) async throws -> [Vulnerability]
}
