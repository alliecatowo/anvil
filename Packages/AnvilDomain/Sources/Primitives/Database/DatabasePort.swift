import Foundation

public protocol DatabasePort: AnvilProviderDefinition {
    var providerKind: DatabaseProviderKind { get }
    var descriptor: DatabaseProviderDescriptor { get }
    func connect(connection: DatabaseConnection) async throws -> DatabaseConnection
    func connect(connectionId: String) async throws
    func disconnect(connectionId: String) async throws
    func schema(connectionId: String) async throws -> Schema
    func execute(connectionId: String, query: String) async throws -> QueryResult
    func browse(connectionId: String, request: DatabaseBrowseRequest) async throws -> QueryResult
    func tables(connectionId: String) async throws -> [String]
    func migrations(directory: String) async throws -> [Migration]
    func runMigration(connectionId: String, migration: Migration) async throws
    func rollbackMigration(connectionId: String, migration: Migration) async throws
}

public extension DatabasePort {
    func connect(connectionId: String) async throws {
        let filePath = connectionId
        let connection = DatabaseConnection(
            id: connectionId,
            name: URL(fileURLWithPath: filePath).lastPathComponent,
            providerId: providerId,
            providerKind: providerKind,
            configuration: .sqlite(filePath: filePath)
        )
        _ = try await connect(connection: connection)
    }

    func browse(connectionId: String, request: DatabaseBrowseRequest) async throws -> QueryResult {
        guard request.objectName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            throw DatabasePortError.invalidObjectName
        }

        var sql = "SELECT * FROM \"\(request.objectName)\""
        if let sortColumn = request.sortColumn {
            guard sortColumn.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
                throw DatabasePortError.invalidSortColumn
            }
            sql += " ORDER BY \"\(sortColumn)\" \(request.sortAscending ? "ASC" : "DESC")"
        }
        sql += " LIMIT \(request.limit) OFFSET \(request.offset);"
        return try await execute(connectionId: connectionId, query: sql)
    }
}

public enum DatabasePortError: LocalizedError {
    case invalidObjectName
    case invalidSortColumn

    public var errorDescription: String? {
        switch self {
        case .invalidObjectName:
            "Invalid database object name"
        case .invalidSortColumn:
            "Invalid database sort column"
        }
    }
}
