import Foundation

public struct DatabaseConnection: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let host: String
    public let port: Int
    public let database: String
    public let engineType: DatabaseEngineType
    public let isConnected: Bool

    public init(id: String = UUID().uuidString, name: String, host: String, port: Int, database: String, engineType: DatabaseEngineType, isConnected: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.database = database
        self.engineType = engineType
        self.isConnected = isConnected
    }
}

public enum DatabaseEngineType: String, Sendable, Codable {
    case postgresql, mysql, sqlite, mongodb, redis
}
