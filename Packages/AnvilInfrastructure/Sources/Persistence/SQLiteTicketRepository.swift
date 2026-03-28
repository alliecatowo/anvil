import Foundation
import SQLite3
import AnvilDomain
import AnvilApplication

/// SQLite-backed ticket persistence implementing TicketManagementPort.
/// Uses the SQLite3 C API directly for zero external dependencies.
/// Thread-safe via actor isolation (Swift 6 strict concurrency).
public actor SQLiteTicketRepository: TicketManagementPort {

    // nonisolated(unsafe): OpaquePointer is not Sendable, but access is
    // serialised by actor isolation so this is safe.
    nonisolated(unsafe) private var db: OpaquePointer?
    private let dbPath: String

    public init(dbPath: String? = nil) {
        let resolved = dbPath ?? {
            let dir = NSHomeDirectory() + "/.anvil/db"
            try? FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )
            return dir + "/tickets.sqlite"
        }()
        self.dbPath = resolved
    }

    // MARK: - Lifecycle

    /// Open the database and create the tickets table if needed.
    public func open() throws {
        let rc = sqlite3_open(dbPath, &db)
        guard rc == SQLITE_OK, db != nil else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw SQLiteTicketError.connectionFailed(msg)
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        try createTable()
    }

    /// Close the database connection.
    public func close() {
        if let db { sqlite3_close(db) }
        db = nil
    }

    // MARK: - TicketManagementPort

    public func fetchTickets() async throws -> [Ticket] {
        let db = try requireDB()
        let sql = """
            SELECT id, title, description, status, priority, assignee,
                   labels, due_date, story_points, epic_id, created_at, updated_at
            FROM tickets ORDER BY created_at DESC;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        var tickets: [Ticket] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            tickets.append(ticketFromRow(stmt))
        }
        return tickets
    }

    public func createTicket(_ ticket: Ticket) async throws -> Ticket {
        let db = try requireDB()
        let sql = """
            INSERT INTO tickets
                (id, title, description, status, priority, assignee,
                 labels, due_date, story_points, epic_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        bindTicket(ticket, to: stmt)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw queryError(db)
        }
        return ticket
    }

    public func updateTicket(_ ticket: Ticket) async throws -> Ticket {
        let db = try requireDB()
        let sql = """
            UPDATE tickets SET
                title = ?, description = ?, status = ?, priority = ?,
                assignee = ?, labels = ?, due_date = ?, story_points = ?,
                epic_id = ?, updated_at = ?
            WHERE id = ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        bindText(ticket.title, to: stmt, at: 1)
        bindText(ticket.description, to: stmt, at: 2)
        bindText(ticket.status, to: stmt, at: 3)
        sqlite3_bind_int(stmt, 4, Int32(ticket.priority.rawValue))
        bindOptionalText(ticket.assignee, to: stmt, at: 5)
        bindText(encodeLabels(ticket.labels), to: stmt, at: 6)
        bindOptionalDate(ticket.dueDate, to: stmt, at: 7)
        bindOptionalInt(ticket.storyPoints, to: stmt, at: 8)
        bindOptionalText(ticket.epicId, to: stmt, at: 9)
        bindText(formatDate(ticket.updatedAt), to: stmt, at: 10)
        bindText(ticket.id, to: stmt, at: 11)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw queryError(db)
        }
        guard sqlite3_changes(db) > 0 else {
            throw TicketServiceError.notFound
        }
        return ticket
    }

    public func deleteTicket(id: String) async throws {
        let db = try requireDB()
        let sql = "DELETE FROM tickets WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        bindText(id, to: stmt, at: 1)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw queryError(db)
        }
        guard sqlite3_changes(db) > 0 else {
            throw TicketServiceError.notFound
        }
    }

    public func moveTicket(id: String, toStatus newStatus: String) async throws -> Ticket {
        let db = try requireDB()
        let sql = "UPDATE tickets SET status = ?, updated_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        bindText(newStatus, to: stmt, at: 1)
        bindText(formatDate(.now), to: stmt, at: 2)
        bindText(id, to: stmt, at: 3)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw queryError(db)
        }
        guard sqlite3_changes(db) > 0 else {
            throw TicketServiceError.notFound
        }

        // Fetch and return the updated ticket
        return try fetchTicket(id: id, db: db)
    }

    // MARK: - Private

    private func requireDB() throws -> OpaquePointer {
        guard let db else { throw SQLiteTicketError.notOpen }
        return db
    }

    private func createTable() throws {
        guard let db else { throw SQLiteTicketError.notOpen }
        let sql = """
            CREATE TABLE IF NOT EXISTS tickets (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'open',
                priority INTEGER NOT NULL DEFAULT 2,
                assignee TEXT,
                labels TEXT NOT NULL DEFAULT '[]',
                due_date TEXT,
                story_points INTEGER,
                epic_id TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if rc != SQLITE_OK {
            let msg = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteTicketError.schemaFailed(msg)
        }
    }

    private func fetchTicket(id: String, db: OpaquePointer) throws -> Ticket {
        let sql = """
            SELECT id, title, description, status, priority, assignee,
                   labels, due_date, story_points, epic_id, created_at, updated_at
            FROM tickets WHERE id = ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        bindText(id, to: stmt, at: 1)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw TicketServiceError.notFound
        }
        return ticketFromRow(stmt)
    }

    // MARK: - Row Mapping

    private func ticketFromRow(_ stmt: OpaquePointer) -> Ticket {
        let id = columnText(stmt, 0)
        let title = columnText(stmt, 1)
        let description = columnText(stmt, 2)
        let status = columnText(stmt, 3)
        let priority = TicketPriority(rawValue: Int(sqlite3_column_int(stmt, 4))) ?? .medium
        let assignee = columnOptionalText(stmt, 5)
        let labels = decodeLabels(columnText(stmt, 6))
        let dueDate = columnOptionalText(stmt, 7).flatMap(parseDate)
        let storyPoints: Int? = sqlite3_column_type(stmt, 8) == SQLITE_NULL
            ? nil : Int(sqlite3_column_int(stmt, 8))
        let epicId = columnOptionalText(stmt, 9)
        let createdAt = parseDate(columnText(stmt, 10)) ?? .now
        let updatedAt = parseDate(columnText(stmt, 11)) ?? .now

        return Ticket(
            id: id,
            title: title,
            description: description,
            status: status,
            priority: priority,
            assignee: assignee,
            labels: labels,
            dueDate: dueDate,
            storyPoints: storyPoints,
            epicId: epicId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Bind Helpers

    private func bindTicket(_ ticket: Ticket, to stmt: OpaquePointer) {
        bindText(ticket.id, to: stmt, at: 1)
        bindText(ticket.title, to: stmt, at: 2)
        bindText(ticket.description, to: stmt, at: 3)
        bindText(ticket.status, to: stmt, at: 4)
        sqlite3_bind_int(stmt, 5, Int32(ticket.priority.rawValue))
        bindOptionalText(ticket.assignee, to: stmt, at: 6)
        bindText(encodeLabels(ticket.labels), to: stmt, at: 7)
        bindOptionalDate(ticket.dueDate, to: stmt, at: 8)
        bindOptionalInt(ticket.storyPoints, to: stmt, at: 9)
        bindOptionalText(ticket.epicId, to: stmt, at: 10)
        bindText(formatDate(ticket.createdAt), to: stmt, at: 11)
        bindText(formatDate(ticket.updatedAt), to: stmt, at: 12)
    }

    private func bindText(_ value: String, to stmt: OpaquePointer, at index: Int32) {
        sqlite3_bind_text(stmt, index, (value as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func bindOptionalText(_ value: String?, to stmt: OpaquePointer, at index: Int32) {
        if let value {
            bindText(value, to: stmt, at: index)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindOptionalDate(_ value: Date?, to stmt: OpaquePointer, at index: Int32) {
        if let value {
            bindText(formatDate(value), to: stmt, at: index)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindOptionalInt(_ value: Int?, to stmt: OpaquePointer, at index: Int32) {
        if let value {
            sqlite3_bind_int(stmt, index, Int32(value))
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    // MARK: - Column Helpers

    private func columnText(_ stmt: OpaquePointer, _ index: Int32) -> String {
        if let text = sqlite3_column_text(stmt, index) {
            return String(cString: text)
        }
        return ""
    }

    private func columnOptionalText(_ stmt: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        if let text = sqlite3_column_text(stmt, index) {
            return String(cString: text)
        }
        return nil
    }

    // MARK: - Date / Label Encoding

    // nonisolated(unsafe): ISO8601DateFormatter is not Sendable but this static
    // is only accessed from actor-isolated methods, ensuring serial access.
    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func parseDate(_ string: String) -> Date? {
        Self.dateFormatter.date(from: string)
    }

    private func encodeLabels(_ labels: [String]) -> String {
        guard let data = try? JSONEncoder().encode(labels),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func decodeLabels(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let labels = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return labels
    }

    private func queryError(_ db: OpaquePointer) -> SQLiteTicketError {
        let msg = String(cString: sqlite3_errmsg(db))
        return .queryFailed(msg)
    }
}

public enum SQLiteTicketError: LocalizedError, Sendable {
    case notOpen
    case connectionFailed(String)
    case schemaFailed(String)
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notOpen: return "Ticket database is not open"
        case .connectionFailed(let msg): return "Failed to open ticket database: \(msg)"
        case .schemaFailed(let msg): return "Failed to create ticket schema: \(msg)"
        case .queryFailed(let msg): return "Ticket query failed: \(msg)"
        }
    }
}
