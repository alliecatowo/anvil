import Foundation

public struct Container: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let image: String
    public let status: ContainerStatus
    public let ports: [PortMapping]
    public let createdAt: Date

    public init(id: String, name: String, image: String, status: ContainerStatus = .created, ports: [PortMapping] = [], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.image = image
        self.status = status
        self.ports = ports
        self.createdAt = createdAt
    }
}

public enum ContainerStatus: String, Sendable, Codable {
    case created, running, paused, restarting, exited, dead
}

public struct PortMapping: Sendable, Codable {
    public let hostPort: Int
    public let containerPort: Int
    public let proto: String

    public init(hostPort: Int, containerPort: Int, proto: String = "tcp") {
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.proto = proto
    }
}
