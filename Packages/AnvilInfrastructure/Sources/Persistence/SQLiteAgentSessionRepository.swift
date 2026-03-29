import Foundation
import SQLite3
import AnvilDomain

/// SQLite-backed agent session persistence implementing AgentSessionPort.
/// Uses the SQLite3 C API directly for zero external dependencies.
/// Thread-safe via actor isolation (Swift 6 strict concurrency).
///
/// Schema:
///   sessions — one row per AgentSession
///   messages — one row per AgentMessage, FK to sessions
public actor SQLiteAgentSessionRepository: AgentSessionPort {

    nonisolated(unsafe) private var db: OpaquePointer?
    private let dbPath: String

    public init(dbPath: String? = nil) {
        let resolved = dbPath ?? {
            let dir = NSHomeDirectory() + "/.anvil/db"
            try? FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )
            return dir + "/sessions.sqlite"
        }()
        self.dbPath = resolved
    }

    // MARK: - Lifecycle

    public func open() throws {
        let rc = sqlite3_open(dbPath, &db)
        guard rc == SQLITE_OK, db != nil else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw SQLiteSessionError.connectionFailed(msg)
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        try createTables()
    }

    public func close() {
        if let db { sqlite3_close(db) }
        db = nil
    }

    // MARK: - AgentSessionPort

    public func fetchSessions() async throws -> [AgentSession] {
        let db = try requireDB()

        // Fetch all sessions
        let sessionSQL = """
            SELECT id, provider_id, model, status, work_item_id, worktree_path,
                   input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
                   cost, started_at, last_activity_at, custom_name,
                   cost_budget, hard_stop_on_budget, autonomy_level, is_background
            FROM sessions ORDER BY last_activity_at DESC;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sessionSQL, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        var sessions: [AgentSession] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let sessionId = columnText(stmt, 0)
            let messages = try fetchMessages(sessionId: sessionId, db: db)
            sessions.append(sessionFromRow(stmt, messages: messages))
        }
        return sessions
    }

    public func saveSession(_ session: AgentSession) async throws {
        let db = try requireDB()

        // Upsert session row
        let sql = """
            INSERT INTO sessions
                (id, provider_id, model, status, work_item_id, worktree_path,
                 input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
                 cost, started_at, last_activity_at, custom_name,
                 cost_budget, hard_stop_on_budget, autonomy_level, is_background)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                model = excluded.model,
                status = excluded.status,
                input_tokens = excluded.input_tokens,
                output_tokens = excluded.output_tokens,
                cache_read_tokens = excluded.cache_read_tokens,
                cache_write_tokens = excluded.cache_write_tokens,
                cost = excluded.cost,
                last_activity_at = excluded.last_activity_at,
                custom_name = excluded.custom_name,
                cost_budget = excluded.cost_budget,
                hard_stop_on_budget = excluded.hard_stop_on_budget,
                autonomy_level = excluded.autonomy_level,
                is_background = excluded.is_background;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        bindSessionRow(session, to: stmt)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw queryError(db)
        }

        // Upsert all messages
        for message in session.messages {
            try upsertMessage(message, sessionId: session.id, db: db)
        }
    }

    public func saveMessage(_ message: AgentMessage, sessionId: String) async throws {
        let db = try requireDB()
        try upsertMessage(message, sessionId: sessionId, db: db)

        // Touch session last_activity_at
        let sql = "UPDATE sessions SET last_activity_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }
        bindText(formatDate(.now), to: stmt, at: 1)
        bindText(sessionId, to: stmt, at: 2)
        sqlite3_step(stmt)
    }

    public func deleteSession(id: String) async throws {
        let db = try requireDB()
        // Messages deleted via ON DELETE CASCADE
        let sql = "DELETE FROM sessions WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }
        bindText(id, to: stmt, at: 1)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw queryError(db)
        }
    }

    public func searchSessions(query: String) async throws -> [SessionSearchResult] {
        let db = try requireDB()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        // Simple LIKE search across session names and message content
        let pattern = "%\(query)%"
        let sql = """
            SELECT s.id, s.displayName, m.id, m.content, s.lastActivityAt
            FROM sessions s
            LEFT JOIN messages m ON m.sessionId = s.id AND m.content LIKE ?
            WHERE s.displayName LIKE ? OR m.content LIKE ?
            ORDER BY s.lastActivityAt DESC
            LIMIT 50;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }
        bindText(pattern, to: stmt, at: 1)
        bindText(pattern, to: stmt, at: 2)
        bindText(pattern, to: stmt, at: 3)
        var results: [SessionSearchResult] = []
        var seen = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            let sessionId = columnText(stmt, 0)
            let sessionName = columnText(stmt, 1)
            let messageId: String? = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? columnText(stmt, 2) : nil
            let rawExcerpt = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? columnText(stmt, 3) : sessionName
            let ts = sqlite3_column_double(stmt, 4)
            let date = ts > 0 ? Date(timeIntervalSince1970: ts) : Date.distantPast
            let key = sessionId + (messageId ?? "")
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            // Trim excerpt around the match
            let excerpt: String
            if let range = rawExcerpt.range(of: query, options: .caseInsensitive) {
                let start = rawExcerpt.index(range.lowerBound, offsetBy: -min(40, rawExcerpt.distance(from: rawExcerpt.startIndex, to: range.lowerBound)), limitedBy: rawExcerpt.startIndex) ?? rawExcerpt.startIndex
                let end = rawExcerpt.index(range.upperBound, offsetBy: min(80, rawExcerpt.distance(from: range.upperBound, to: rawExcerpt.endIndex)), limitedBy: rawExcerpt.endIndex) ?? rawExcerpt.endIndex
                excerpt = (start > rawExcerpt.startIndex ? "…" : "") + rawExcerpt[start..<end] + (end < rawExcerpt.endIndex ? "…" : "")
            } else {
                excerpt = String(rawExcerpt.prefix(120))
            }
            results.append(SessionSearchResult(sessionId: sessionId, sessionName: sessionName, messageId: messageId, excerpt: excerpt, date: date))
        }
        return results
    }

    // MARK: - Private: Schema

    private func requireDB() throws -> OpaquePointer {
        guard let db else { throw SQLiteSessionError.notOpen }
        return db
    }

    private func createTables() throws {
        guard let db else { throw SQLiteSessionError.notOpen }
        let sessionsSQL = """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                provider_id TEXT NOT NULL,
                model TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'idle',
                work_item_id TEXT,
                worktree_path TEXT,
                input_tokens INTEGER NOT NULL DEFAULT 0,
                output_tokens INTEGER NOT NULL DEFAULT 0,
                cache_read_tokens INTEGER NOT NULL DEFAULT 0,
                cache_write_tokens INTEGER NOT NULL DEFAULT 0,
                cost TEXT NOT NULL DEFAULT '0',
                started_at TEXT NOT NULL,
                last_activity_at TEXT NOT NULL,
                custom_name TEXT,
                cost_budget TEXT,
                hard_stop_on_budget INTEGER NOT NULL DEFAULT 0,
                autonomy_level TEXT NOT NULL DEFAULT 'ask',
                is_background INTEGER NOT NULL DEFAULT 0
            );
            """
        let messagesSQL = """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                tool_calls TEXT NOT NULL DEFAULT '[]',
                timestamp TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id, timestamp);
            """

        var errorMessage: UnsafeMutablePointer<CChar>?
        var rc = sqlite3_exec(db, sessionsSQL, nil, nil, &errorMessage)
        if rc != SQLITE_OK {
            let msg = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteSessionError.schemaFailed(msg)
        }

        rc = sqlite3_exec(db, messagesSQL, nil, nil, &errorMessage)
        if rc != SQLITE_OK {
            let msg = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteSessionError.schemaFailed(msg)
        }
    }

    // MARK: - Private: Messages

    private func fetchMessages(sessionId: String, db: OpaquePointer) throws -> [AgentMessage] {
        let sql = """
            SELECT id, role, content, tool_calls, timestamp
            FROM messages WHERE session_id = ? ORDER BY timestamp ASC;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }
        bindText(sessionId, to: stmt, at: 1)

        var messages: [AgentMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            messages.append(messageFromRow(stmt))
        }
        return messages
    }

    private func upsertMessage(_ message: AgentMessage, sessionId: String, db: OpaquePointer) throws {
        let sql = """
            INSERT INTO messages (id, session_id, role, content, tool_calls, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                content = excluded.content,
                tool_calls = excluded.tool_calls;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw queryError(db)
        }
        defer { sqlite3_finalize(stmt) }

        bindText(message.id, to: stmt, at: 1)
        bindText(sessionId, to: stmt, at: 2)
        bindText(message.role.rawValue, to: stmt, at: 3)
        bindText(message.content, to: stmt, at: 4)
        bindText(encodeToolCalls(message.toolCalls), to: stmt, at: 5)
        bindText(formatDate(message.timestamp), to: stmt, at: 6)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw queryError(db)
        }
    }

    // MARK: - Row Mapping

    private func sessionFromRow(_ stmt: OpaquePointer, messages: [AgentMessage]) -> AgentSession {
        let costString = columnText(stmt, 10)
        let cost = Decimal(string: costString) ?? 0

        let budgetString = columnOptionalText(stmt, 14)
        let costBudget = budgetString.flatMap { Decimal(string: $0) }

        return AgentSession(
            id: columnText(stmt, 0),
            providerId: columnText(stmt, 1),
            model: columnText(stmt, 2),
            status: AgentSessionStatus(rawValue: columnText(stmt, 3)) ?? .idle,
            workItemId: columnOptionalText(stmt, 4),
            worktreePath: columnOptionalText(stmt, 5),
            tokenUsage: TokenUsage(
                inputTokens: Int(sqlite3_column_int(stmt, 6)),
                outputTokens: Int(sqlite3_column_int(stmt, 7)),
                cacheReadTokens: Int(sqlite3_column_int(stmt, 8)),
                cacheWriteTokens: Int(sqlite3_column_int(stmt, 9))
            ),
            cost: cost,
            startedAt: parseDate(columnText(stmt, 11)) ?? .now,
            lastActivityAt: parseDate(columnText(stmt, 12)) ?? .now,
            messages: messages,
            customName: columnOptionalText(stmt, 13),
            costBudget: costBudget,
            hardStopOnBudget: sqlite3_column_int(stmt, 15) != 0,
            autonomyLevel: AutonomyLevel(rawValue: columnText(stmt, 16)) ?? .ask,
            isBackground: sqlite3_column_int(stmt, 17) != 0
        )
    }

    private func messageFromRow(_ stmt: OpaquePointer) -> AgentMessage {
        AgentMessage(
            id: columnText(stmt, 0),
            role: AgentMessageRole(rawValue: columnText(stmt, 1)) ?? .system,
            content: columnText(stmt, 2),
            toolCalls: decodeToolCalls(columnText(stmt, 3)),
            timestamp: parseDate(columnText(stmt, 4)) ?? .now
        )
    }

    // MARK: - Bind Helpers

    private func bindSessionRow(_ session: AgentSession, to stmt: OpaquePointer) {
        bindText(session.id, to: stmt, at: 1)
        bindText(session.providerId, to: stmt, at: 2)
        bindText(session.model, to: stmt, at: 3)
        bindText(session.status.rawValue, to: stmt, at: 4)
        bindOptionalText(session.workItemId, to: stmt, at: 5)
        bindOptionalText(session.worktreePath, to: stmt, at: 6)
        sqlite3_bind_int(stmt, 7, Int32(session.tokenUsage.inputTokens))
        sqlite3_bind_int(stmt, 8, Int32(session.tokenUsage.outputTokens))
        sqlite3_bind_int(stmt, 9, Int32(session.tokenUsage.cacheReadTokens))
        sqlite3_bind_int(stmt, 10, Int32(session.tokenUsage.cacheWriteTokens))
        bindText("\(session.cost)", to: stmt, at: 11)
        bindText(formatDate(session.startedAt), to: stmt, at: 12)
        bindText(formatDate(session.lastActivityAt), to: stmt, at: 13)
        bindOptionalText(session.customName, to: stmt, at: 14)
        bindOptionalText(session.costBudget.map { "\($0)" }, to: stmt, at: 15)
        sqlite3_bind_int(stmt, 16, session.hardStopOnBudget ? 1 : 0)
        bindText(session.autonomyLevel.rawValue, to: stmt, at: 17)
        sqlite3_bind_int(stmt, 18, session.isBackground ? 1 : 0)
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

    // MARK: - Date / JSON Encoding

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

    private func encodeToolCalls(_ toolCalls: [ToolCall]) -> String {
        guard let data = try? JSONEncoder().encode(toolCalls),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func decodeToolCalls(_ json: String) -> [ToolCall] {
        guard let data = json.data(using: .utf8),
              let calls = try? JSONDecoder().decode([ToolCall].self, from: data) else {
            return []
        }
        return calls
    }

    private func queryError(_ db: OpaquePointer) -> SQLiteSessionError {
        let msg = String(cString: sqlite3_errmsg(db))
        return .queryFailed(msg)
    }
}

public enum SQLiteSessionError: LocalizedError, Sendable {
    case notOpen
    case connectionFailed(String)
    case schemaFailed(String)
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notOpen: "Agent session database is not open"
        case .connectionFailed(let msg): "Failed to open session database: \(msg)"
        case .schemaFailed(let msg): "Failed to create session schema: \(msg)"
        case .queryFailed(let msg): "Session query failed: \(msg)"
        }
    }
}
