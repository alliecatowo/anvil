import Foundation

public struct RemoteConnection: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let host: String
    public let port: Int
    public let username: String?
    public let connectionType: RemoteConnectionType
    public let isConnected: Bool

    public init(id: String = UUID().uuidString, name: String, host: String, port: Int = 22, username: String? = nil, connectionType: RemoteConnectionType = .ssh, isConnected: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.connectionType = connectionType
        self.isConnected = isConnected
    }
}

public enum RemoteConnectionType: String, Sendable, Codable {
    case ssh, devContainer, codespace, cloudVM
}
