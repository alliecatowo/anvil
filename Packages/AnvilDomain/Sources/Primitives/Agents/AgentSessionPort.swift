import Foundation

/// Port for persisting and loading agent sessions across app launches.
/// Implementations store sessions and their messages durably (e.g. SQLite).
public protocol AgentSessionPort: Sendable {
    /// Load all persisted sessions (most recent first). Messages are included.
    func fetchSessions() async throws -> [AgentSession]

    /// Persist a new or updated session (upsert semantics).
    func saveSession(_ session: AgentSession) async throws

    /// Persist a single message appended to an existing session.
    func saveMessage(_ message: AgentMessage, sessionId: String) async throws

    /// Delete a session and all its messages.
    func deleteSession(id: String) async throws

    /// Full-text search across session names and message content.
    /// Returns results ranked by relevance with matched excerpts.
    func searchSessions(query: String) async throws -> [SessionSearchResult]
}

/// A search result from full-text search across agent sessions.
public struct SessionSearchResult: Sendable, Identifiable {
    public let id: String
    public let sessionId: String
    public let sessionName: String
    public let messageId: String?
    public let excerpt: String
    public let date: Date
    public let rank: Double

    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        sessionName: String,
        messageId: String? = nil,
        excerpt: String,
        date: Date,
        rank: Double = 0
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.messageId = messageId
        self.excerpt = excerpt
        self.date = date
        self.rank = rank
    }
}
