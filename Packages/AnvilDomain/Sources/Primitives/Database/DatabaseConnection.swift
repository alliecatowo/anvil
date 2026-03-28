import Foundation

public struct DatabaseConnection: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let providerId: String
    public let providerKind: DatabaseProviderKind
    public let configuration: DatabaseConnectionConfiguration
    public let host: String
    public let port: Int
    public let database: String
    public let engineType: DatabaseEngineType
    public let isConnected: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        providerId: String,
        providerKind: DatabaseProviderKind,
        configuration: DatabaseConnectionConfiguration,
        isConnected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.providerId = providerId
        self.providerKind = providerKind
        self.configuration = configuration
        self.host = configuration.host ?? ""
        self.port = configuration.port ?? 0
        self.database = configuration.databaseName
        self.engineType = providerKind.engineType
        self.isConnected = isConnected
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: Int,
        database: String,
        engineType: DatabaseEngineType,
        isConnected: Bool = false
    ) {
        self.init(
            id: id,
            name: name,
            providerId: engineType.defaultProviderId,
            providerKind: engineType.providerKind,
            configuration: DatabaseConnectionConfiguration(
                filePath: engineType == .sqlite ? host : nil,
                host: engineType == .sqlite ? nil : host,
                port: engineType == .sqlite ? nil : port,
                databaseName: database
            ),
            isConnected: isConnected
        )
    }
}

public enum DatabaseEngineType: String, Sendable, Codable {
    case postgresql, mysql, sqlite, mongodb, redis
}

public enum DatabaseProviderKind: String, Sendable, Codable, CaseIterable {
    case sqlite
    case postgresql
    case mysql
    case mongodb
    case redis

    public var displayName: String {
        switch self {
        case .sqlite: "SQLite"
        case .postgresql: "PostgreSQL"
        case .mysql: "MySQL"
        case .mongodb: "MongoDB"
        case .redis: "Redis"
        }
    }

    public var engineType: DatabaseEngineType {
        switch self {
        case .sqlite: .sqlite
        case .postgresql: .postgresql
        case .mysql: .mysql
        case .mongodb: .mongodb
        case .redis: .redis
        }
    }
}

public struct DatabaseConnectionConfiguration: Sendable, Codable, Equatable {
    public let filePath: String?
    public let host: String?
    public let port: Int?
    public let databaseName: String
    public let username: String?
    public let options: [String: String]

    public init(
        filePath: String? = nil,
        host: String? = nil,
        port: Int? = nil,
        databaseName: String,
        username: String? = nil,
        options: [String: String] = [:]
    ) {
        self.filePath = filePath
        self.host = host
        self.port = port
        self.databaseName = databaseName
        self.username = username
        self.options = options
    }

    public static func sqlite(filePath: String) -> Self {
        Self(
            filePath: filePath,
            databaseName: URL(fileURLWithPath: filePath).lastPathComponent
        )
    }

    public var displayLocation: String {
        if let filePath, !filePath.isEmpty {
            return filePath
        }
        if let host, !host.isEmpty {
            if let port {
                return "\(host):\(port)"
            }
            return host
        }
        return databaseName
    }
}

public extension DatabaseEngineType {
    var providerKind: DatabaseProviderKind {
        switch self {
        case .sqlite: .sqlite
        case .postgresql: .postgresql
        case .mysql: .mysql
        case .mongodb: .mongodb
        case .redis: .redis
        }
    }

    var defaultProviderId: String {
        switch self {
        case .sqlite: "sqlite-local"
        case .postgresql: "postgresql"
        case .mysql: "mysql"
        case .mongodb: "mongodb"
        case .redis: "redis"
        }
    }
}
