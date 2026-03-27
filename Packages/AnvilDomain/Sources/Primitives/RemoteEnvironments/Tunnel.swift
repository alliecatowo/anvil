import Foundation

public struct Tunnel: Sendable, Identifiable, Codable {
    public let id: String
    public let connectionId: String
    public let localPort: Int
    public let remotePort: Int
    public let isActive: Bool

    public init(id: String = UUID().uuidString, connectionId: String, localPort: Int, remotePort: Int, isActive: Bool = true) {
        self.id = id
        self.connectionId = connectionId
        self.localPort = localPort
        self.remotePort = remotePort
        self.isActive = isActive
    }
}
