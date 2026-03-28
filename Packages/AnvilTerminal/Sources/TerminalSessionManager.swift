import Foundation

// MARK: - Terminal Session Manager

/// Manages multiple terminal sessions.
@MainActor
public final class TerminalSessionManager: ObservableObject, Sendable {

    @Published public var sessions: [TerminalSession] = []
    @Published public var activeSessionId: UUID?

    public var activeSession: TerminalSession? {
        sessions.first { $0.id == activeSessionId }
    }

    public init() {}

    // MARK: - Session Management

    /// Creates and starts a new terminal session.
    @discardableResult
    public func createSession(
        title: String = "zsh",
        shell: String? = nil,
        workingDirectory: String? = nil,
        columns: Int = 80,
        rows: Int = 24
    ) -> TerminalSession {
        let session = TerminalSession(
            title: title,
            columns: columns,
            rows: rows
        )

        sessions.append(session)
        activeSessionId = session.id

        do {
            try session.start(
                shell: shell,
                workingDirectory: workingDirectory
            )
        } catch {
            // Session is created but not running — UI can show error state
        }

        return session
    }

    /// Closes a terminal session by ID.
    public func closeSession(_ id: UUID) {
        if let session = sessions.first(where: { $0.id == id }) {
            session.terminate()
        }
        sessions.removeAll { $0.id == id }

        if activeSessionId == id {
            activeSessionId = sessions.last?.id
        }
    }

    /// Switches to a specific session.
    public func selectSession(_ id: UUID) {
        activeSessionId = id
    }

    /// Terminates all sessions.
    public func terminateAll() {
        for session in sessions {
            session.terminate()
        }
        sessions.removeAll()
        activeSessionId = nil
    }
}
