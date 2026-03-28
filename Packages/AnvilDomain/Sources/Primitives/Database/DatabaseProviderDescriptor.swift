import Foundation

public struct DatabaseProviderDescriptor: Sendable, Identifiable, Codable, Equatable {
    public let id: String
    public let displayName: String
    public let kind: DatabaseProviderKind
    public let connectionStyle: DatabaseConnectionStyle
    public let supportedFileExtensions: [String]
    public let capabilities: [DatabaseCapability]
    public let notes: String?

    public init(
        id: String,
        displayName: String,
        kind: DatabaseProviderKind,
        connectionStyle: DatabaseConnectionStyle,
        supportedFileExtensions: [String] = [],
        capabilities: [DatabaseCapability],
        notes: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.connectionStyle = connectionStyle
        self.supportedFileExtensions = supportedFileExtensions
        self.capabilities = capabilities
        self.notes = notes
    }
}

public enum DatabaseConnectionStyle: String, Sendable, Codable {
    case file
    case server
}

public enum DatabaseCapability: String, Sendable, Codable {
    case connect
    case inspectSchema
    case browseObjects
    case executeQueries
    case migrations
}
