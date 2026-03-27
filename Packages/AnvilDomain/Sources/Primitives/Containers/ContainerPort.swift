import Foundation

public protocol ContainerPort: AnvilProviderDefinition {
    func containers() async throws -> [Container]
    func container(containerId: String) async throws -> Container
    func startContainer(containerId: String) async throws
    func stopContainer(containerId: String) async throws
    func removeContainer(containerId: String, force: Bool) async throws
    func containerLogs(containerId: String, tail: Int) async throws -> String
    func images() async throws -> [ContainerImage]
    func pullImage(name: String, tag: String) async throws -> ContainerImage
    func composeUp(stackPath: String) async throws -> ComposeStack
    func composeDown(stackPath: String) async throws
    func composeStacks() async throws -> [ComposeStack]
}
