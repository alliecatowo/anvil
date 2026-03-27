import Foundation

public protocol DatabasePort: AnvilProviderDefinition {
    func connect(connectionId: String) async throws
    func disconnect(connectionId: String) async throws
    func schema(connectionId: String) async throws -> Schema
    func execute(connectionId: String, query: String) async throws -> QueryResult
    func tables(connectionId: String) async throws -> [String]
    func migrations(directory: String) async throws -> [Migration]
    func runMigration(connectionId: String, migration: Migration) async throws
    func rollbackMigration(connectionId: String, migration: Migration) async throws
}
