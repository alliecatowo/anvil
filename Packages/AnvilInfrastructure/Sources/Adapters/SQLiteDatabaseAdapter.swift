import Foundation
import SQLite3
import AnvilDomain

/// Real SQLite adapter implementing DatabasePort using the SQLite3 C API.
/// Uses an internal actor for thread-safe connection management (Swift 6 concurrency).
/// @unchecked Sendable: All mutable state is isolated in the ConnectionStore actor.
/// Only `let` properties are accessed directly.
public final class SQLiteDatabaseAdapter: DatabasePort, @unchecked Sendable {
    public let providerId: String = "sqlite-local"
    public let providerName: String = "SQLite"
    public let providerKind: DatabaseProviderKind = .sqlite
    public let descriptor = DatabaseProviderDescriptor(
        id: "sqlite-local",
        displayName: "SQLite",
        kind: .sqlite,
        connectionStyle: .file,
        supportedFileExtensions: ["sqlite", "sqlite3", "db"],
        capabilities: [.connect, .inspectSchema, .browseObjects, .executeQueries, .migrations],
        notes: "Local file-backed database."
    )

    private struct Connection: Sendable {
        // nonisolated(unsafe): OpaquePointer is not Sendable, but each Connection is
        // only accessed through the actor-isolated ConnectionStore, ensuring serial access.
        nonisolated(unsafe) let db: OpaquePointer
        let path: String
    }

    /// Actor-isolated connection storage for Swift 6 concurrency safety.
    private actor ConnectionStore {
        var connections: [String: Connection] = [:]

        func get(_ id: String) -> Connection? { connections[id] }
        func set(_ id: String, _ conn: Connection) { connections[id] = conn }
        func remove(_ id: String) -> Connection? { connections.removeValue(forKey: id) }
        var isEmpty: Bool { connections.isEmpty }
    }

    private let store = ConnectionStore()

    public init() {}

    // MARK: - AnvilProviderDefinition

    public func validateConnection() async throws -> Bool {
        await !store.isEmpty
    }

    // MARK: - DatabasePort

    public func connect(connection: DatabaseConnection) async throws -> DatabaseConnection {
        guard connection.providerKind == .sqlite else {
            throw SQLiteAdapterError.unsupportedConfiguration("SQLite provider cannot open \(connection.providerKind.displayName) connections")
        }

        guard let filePath = connection.configuration.filePath, !filePath.isEmpty else {
            throw SQLiteAdapterError.unsupportedConfiguration("SQLite requires a local database file")
        }

        var db: OpaquePointer?
        let rc = sqlite3_open(filePath, &db)
        guard rc == SQLITE_OK, let db else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            if let db { sqlite3_close(db) }
            throw SQLiteAdapterError.connectionFailed(msg)
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        await store.set(connection.id, Connection(db: db, path: filePath))
        return DatabaseConnection(
            id: connection.id,
            name: connection.name,
            providerId: providerId,
            providerKind: .sqlite,
            configuration: .sqlite(filePath: filePath),
            isConnected: true
        )
    }

    public func connect(connectionId: String) async throws {
        _ = try await connect(
            connection: DatabaseConnection(
                id: connectionId,
                name: URL(fileURLWithPath: connectionId).lastPathComponent,
                providerId: providerId,
                providerKind: .sqlite,
                configuration: .sqlite(filePath: connectionId)
            )
        )
    }

    public func disconnect(connectionId: String) async throws {
        guard let conn = await store.remove(connectionId) else { return }
        sqlite3_close(conn.db)
    }

    public func schema(connectionId: String) async throws -> Schema {
        let db = try await getDB(connectionId)
        let dbName = URL(fileURLWithPath: connectionId).deletingPathExtension().lastPathComponent

        // Get tables
        let tableNames = try queryColumn(db: db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")

        var tableDefs: [TableDefinition] = []
        for tableName in tableNames {
            let columns = try introspectColumns(db: db, table: tableName)
            let primaryKeys = try introspectPrimaryKeys(db: db, table: tableName)
            let rowCount = try countRows(db: db, table: tableName)
            tableDefs.append(TableDefinition(
                name: tableName,
                columns: columns,
                primaryKey: primaryKeys,
                rowCount: rowCount
            ))
        }

        // Get views
        let viewNames = try queryColumn(db: db, sql: "SELECT name FROM sqlite_master WHERE type='view' ORDER BY name;")

        return Schema(tables: tableDefs, views: viewNames, databaseName: dbName)
    }

    public func execute(connectionId: String, query: String) async throws -> QueryResult {
        let db = try await getDB(connectionId)
        let start = CFAbsoluteTimeGetCurrent()

        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, query, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteAdapterError.queryFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        let columnCount = Int(sqlite3_column_count(stmt))
        var columns: [String] = []
        for i in 0..<columnCount {
            let name = sqlite3_column_name(stmt, Int32(i)).map { String(cString: $0) } ?? "col\(i)"
            columns.append(name)
        }

        var rows: [[String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String] = []
            for i in 0..<columnCount {
                let colType = sqlite3_column_type(stmt, Int32(i))
                switch colType {
                case SQLITE_NULL:
                    row.append("NULL")
                case SQLITE_INTEGER:
                    row.append(String(sqlite3_column_int64(stmt, Int32(i))))
                case SQLITE_FLOAT:
                    row.append(String(sqlite3_column_double(stmt, Int32(i))))
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(stmt, Int32(i)) {
                        row.append(String(cString: text))
                    } else {
                        row.append("")
                    }
                case SQLITE_BLOB:
                    let bytes = sqlite3_column_bytes(stmt, Int32(i))
                    row.append("<BLOB \(bytes) bytes>")
                default:
                    row.append("")
                }
            }
            rows.append(row)
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        let affected = Int(sqlite3_changes(db))

        return QueryResult(
            columns: columns,
            rows: rows,
            rowsAffected: affected,
            executionTimeMs: elapsed
        )
    }

    public func tables(connectionId: String) async throws -> [String] {
        let db = try await getDB(connectionId)
        return try queryColumn(db: db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
    }

    public func migrations(directory: String) async throws -> [Migration] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        // Look for .sql files sorted by name (convention: 001_create_users.sql)
        let sqlFiles = files.filter { $0.hasSuffix(".sql") }.sorted()

        return sqlFiles.enumerated().map { index, fileName in
            let name = (fileName as NSString).deletingPathExtension
            let version = String(format: "%03d", index + 1)
            return Migration(id: fileName, name: name, version: version, status: .pending)
        }
    }

    public func runMigration(connectionId: String, migration: Migration) async throws {
        let db = try await getDB(connectionId)

        // The migration id is the filename; look for it relative to the connection's db path
        let conn = await store.get(connectionId)
        guard let conn else { return }
        let dbDir = (conn.path as NSString).deletingLastPathComponent
        let migrationPath = (dbDir as NSString).appendingPathComponent(migration.id)

        guard let sql = try? String(contentsOfFile: migrationPath, encoding: .utf8) else {
            throw SQLiteAdapterError.queryFailed("Migration file not found: \(migration.id)")
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if rc != SQLITE_OK {
            let msg = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteAdapterError.queryFailed("Migration failed: \(msg)")
        }
    }

    public func rollbackMigration(connectionId: String, migration: Migration) async throws {
        // Look for a corresponding down migration file (e.g. 001_create_users.down.sql)
        let conn = await store.get(connectionId)
        guard let conn else { return }
        let dbDir = (conn.path as NSString).deletingLastPathComponent
        let baseName = (migration.id as NSString).deletingPathExtension
        let downFile = "\(baseName).down.sql"
        let downPath = (dbDir as NSString).appendingPathComponent(downFile)

        guard let sql = try? String(contentsOfFile: downPath, encoding: .utf8) else {
            throw SQLiteAdapterError.queryFailed("Rollback file not found: \(downFile)")
        }

        let db = try await getDB(connectionId)
        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if rc != SQLITE_OK {
            let msg = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteAdapterError.queryFailed("Rollback failed: \(msg)")
        }
    }

    // MARK: - Paginated Table Browse

    public func browse(connectionId: String, request: DatabaseBrowseRequest) async throws -> QueryResult {
        guard request.objectName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            throw SQLiteAdapterError.queryFailed("Invalid database object name")
        }

        var sql = "SELECT * FROM \"\(request.objectName)\""
        if let col = request.sortColumn, col.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            sql += " ORDER BY \"\(col)\" \(request.sortAscending ? "ASC" : "DESC")"
        }
        sql += " LIMIT \(request.limit) OFFSET \(request.offset);"

        return try await execute(connectionId: connectionId, query: sql)
    }

    /// Fetch rows from a table with pagination and optional sorting.
    public func browseTable(
        connectionId: String,
        table: String,
        limit: Int = 50,
        offset: Int = 0,
        sortColumn: String? = nil,
        sortAscending: Bool = true
    ) async throws -> QueryResult {
        try await browse(
            connectionId: connectionId,
            request: DatabaseBrowseRequest(
                objectName: table,
                limit: limit,
                offset: offset,
                sortColumn: sortColumn,
                sortAscending: sortAscending
            )
        )
    }

    /// Get total row count for a table.
    public func tableRowCount(connectionId: String, table: String) async throws -> Int {
        guard table.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            throw SQLiteAdapterError.queryFailed("Invalid table name")
        }
        let db = try await getDB(connectionId)
        return try countRows(db: db, table: table)
    }

    /// Get indexes for a table.
    public func indexes(connectionId: String, table: String) async throws -> [IndexInfo] {
        guard table.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            throw SQLiteAdapterError.queryFailed("Invalid table name")
        }
        let db = try await getDB(connectionId)
        let result = try executeRaw(db: db, sql: "PRAGMA index_list(\"\(table)\");")
        var indexes: [IndexInfo] = []
        for row in result {
            guard row.count >= 3 else { continue }
            let name = row[1]
            let unique = row[2] == "1"
            // Get columns for this index
            let colResult = try executeRaw(db: db, sql: "PRAGMA index_info(\"\(name)\");")
            let cols = colResult.compactMap { $0.count >= 3 ? $0[2] : nil }
            indexes.append(IndexInfo(name: name, columns: cols, isUnique: unique))
        }
        return indexes
    }

    // MARK: - Private Helpers

    private func getDB(_ connectionId: String) async throws -> OpaquePointer {
        guard let conn = await store.get(connectionId) else {
            throw SQLiteAdapterError.notConnected
        }
        return conn.db
    }

    private func queryColumn(db: OpaquePointer, sql: String) throws -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteAdapterError.queryFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }
        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let text = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: text))
            }
        }
        return results
    }

    private func executeRaw(db: OpaquePointer, sql: String) throws -> [[String]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteAdapterError.queryFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }
        let colCount = Int(sqlite3_column_count(stmt))
        var rows: [[String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String] = []
            for i in 0..<colCount {
                if let text = sqlite3_column_text(stmt, Int32(i)) {
                    row.append(String(cString: text))
                } else {
                    row.append("")
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func introspectColumns(db: OpaquePointer, table: String) throws -> [ColumnDefinition] {
        let rows = try executeRaw(db: db, sql: "PRAGMA table_info(\"\(table)\");")
        // PRAGMA table_info columns: cid, name, type, notnull, dflt_value, pk
        return rows.compactMap { row in
            guard row.count >= 6 else { return nil }
            let name = row[1]
            let dataType = row[2].isEmpty ? "ANY" : row[2]
            let notNull = row[3] == "1"
            let defaultVal = row[4].isEmpty ? nil : row[4]
            return ColumnDefinition(
                name: name,
                dataType: dataType,
                isNullable: !notNull,
                defaultValue: defaultVal
            )
        }
    }

    private func introspectPrimaryKeys(db: OpaquePointer, table: String) throws -> [String] {
        let rows = try executeRaw(db: db, sql: "PRAGMA table_info(\"\(table)\");")
        return rows.compactMap { row in
            guard row.count >= 6, row[5] != "0" else { return nil }
            return row[1]
        }
    }

    private func countRows(db: OpaquePointer, table: String) throws -> Int {
        let results = try queryColumn(db: db, sql: "SELECT COUNT(*) FROM \"\(table)\";")
        return Int(results.first ?? "0") ?? 0
    }
}

// MARK: - Supporting Types

public struct IndexInfo: Sendable {
    public let name: String
    public let columns: [String]
    public let isUnique: Bool
}

public enum SQLiteAdapterError: LocalizedError {
    case connectionFailed(String)
    case notConnected
    case queryFailed(String)
    case unsupportedConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .notConnected: return "Not connected to database"
        case .queryFailed(let msg): return "Query failed: \(msg)"
        case .unsupportedConfiguration(let msg): return msg
        }
    }
}
