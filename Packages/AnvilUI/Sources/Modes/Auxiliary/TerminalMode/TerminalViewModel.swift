import SwiftUI
import AnvilTerminal
import Combine

// MARK: - ViewModel

@MainActor
public final class TerminalViewModel: ObservableObject {
    @Published var sessionManager = TerminalSessionManager()
    @Published var terminalColumns: Int = 80
    @Published var terminalRows: Int = 24
    private var cancellables = Set<AnyCancellable>()

    /// The project working directory, used as CWD for new terminal sessions.
    var projectWorkingDirectory: String?

    var sessions: [TerminalSession] {
        sessionManager.sessions
    }

    var selectedSessionId: UUID? {
        get { sessionManager.activeSessionId }
        set { sessionManager.activeSessionId = newValue }
    }

    var selectedSession: TerminalSession? {
        sessionManager.activeSession
    }

    public init() {
        // Forward nested session manager changes so SwiftUI updates when
        // sessions are added/removed/switched.
        sessionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Initial session is created lazily when the terminal is first
        // opened (see AppState.toggleTerminal / addTab) so it picks up
        // the project working directory configured at startup.
    }

    /// Configures the terminal to use the project working directory for new sessions.
    public func configure(projectPath: String?) {
        projectWorkingDirectory = projectPath
    }

    // MARK: - Actions

    func selectTab(_ id: UUID) {
        sessionManager.selectSession(id)
    }

    @discardableResult
    func addTab() -> TerminalSession {
        let cwd = projectWorkingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        return sessionManager.createSession(
            workingDirectory: cwd,
            columns: terminalColumns,
            rows: terminalRows
        )
    }

    func closeTab(_ id: UUID) {
        sessionManager.closeSession(id)
    }

    func renameSession(_ id: UUID, title: String) {
        guard let session = sessions.first(where: { $0.id == id }),
              !title.isEmpty else { return }
        session.title = title
        objectWillChange.send()
    }

    func selectNextTab() {
        guard let current = selectedSessionId,
              let idx = sessions.firstIndex(where: { $0.id == current }),
              idx + 1 < sessions.count else { return }
        sessionManager.selectSession(sessions[idx + 1].id)
    }

    func selectPreviousTab() {
        guard let current = selectedSessionId,
              let idx = sessions.firstIndex(where: { $0.id == current }),
              idx > 0 else { return }
        sessionManager.selectSession(sessions[idx - 1].id)
    }

    func session(with id: UUID?) -> TerminalSession? {
        guard let id else { return nil }
        return sessions.first { $0.id == id }
    }

    func sendInput(_ text: String) {
        guard let session = selectedSession else { return }
        session.send(text + "\r")
    }

    func sendKey(_ key: TerminalKey) {
        guard let session = selectedSession else { return }
        session.sendKey(key)
    }

    func sendCharacter(_ char: String) {
        guard let session = selectedSession else { return }
        session.send(char)
    }

    func clearBuffer() {
        // Send Ctrl-L (form feed) to clear the terminal screen
        guard let session = selectedSession else { return }
        session.send("\u{000C}")
    }

    func resize(columns: Int, rows: Int) {
        terminalColumns = columns
        terminalRows = rows
        // SwiftTerm handles resize automatically via NSView layout
    }
}
