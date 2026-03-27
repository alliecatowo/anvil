import Foundation

public struct ComposeStack: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let configPath: String
    public let services: [ComposeService]
    public let status: ComposeStackStatus

    public init(id: String = UUID().uuidString, name: String, configPath: String, services: [ComposeService] = [], status: ComposeStackStatus = .stopped) {
        self.id = id
        self.name = name
        self.configPath = configPath
        self.services = services
        self.status = status
    }
}

public struct ComposeService: Sendable, Identifiable, Codable {
    public var id: String { name }
    public let name: String
    public let image: String
    public let status: ContainerStatus
    public let ports: [PortMapping]

    public init(name: String, image: String, status: ContainerStatus = .created, ports: [PortMapping] = []) {
        self.name = name
        self.image = image
        self.status = status
        self.ports = ports
    }
}

public enum ComposeStackStatus: String, Sendable, Codable {
    case running, stopped, partial
}
