import SwiftUI
import AnvilTerminal
import Combine

// MARK: - ViewModel

@MainActor
final class TerminalViewModel: ObservableObject {
    @Published var sessionManager = TerminalSessionManager()
    @Published var terminalColumns: Int = 80
    @Published var terminalRows: Int = 24
    private var cancellables = Set<AnyCancellable>()

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

    init() {
        // Forward nested session manager changes so SwiftUI updates when
        // sessions are added/removed/switched.
        sessionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Create an initial terminal session
        sessionManager.createSession(
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            columns: terminalColumns,
            rows: terminalRows
        )
    }

    // MARK: - Actions

    func selectTab(_ id: UUID) {
        sessionManager.selectSession(id)
    }

    @discardableResult
    func addTab() -> TerminalSession {
        sessionManager.createSession(
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            columns: terminalColumns,
            rows: terminalRows
        )
    }

    func closeTab(_ id: UUID) {
        sessionManager.closeSession(id)
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
