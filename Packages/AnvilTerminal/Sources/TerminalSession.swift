import Foundation

// MARK: - Terminal Session

/// A single terminal session wrapping a PTY process and screen buffer.
@MainActor
public final class TerminalSession: ObservableObject, Identifiable, Sendable {

    public let id: UUID
    @Published public var title: String
    @Published public private(set) var screenBuffer: ScreenBuffer
    @Published public private(set) var isRunning: Bool = false

    private let pty = PTYProcess()
    private let parser = ANSIParser()

    public init(
        id: UUID = UUID(),
        title: String = "zsh",
        columns: Int = 80,
        rows: Int = 24
    ) {
        self.id = id
        self.title = title
        self.screenBuffer = ScreenBuffer(columns: columns, rows: rows)
    }

    // MARK: - Lifecycle

    /// Starts the terminal session by spawning the shell.
    public func start(
        shell: String? = nil,
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) throws {
        let cols = UInt16(screenBuffer.columns)
        let rows = UInt16(screenBuffer.rows)

        pty.onOutput = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.handleOutput(data)
            }
        }

        pty.onExit = { [weak self] exitCode in
            Task { @MainActor [weak self] in
                self?.handleExit(exitCode)
            }
        }

        try pty.spawn(
            shell: shell,
            columns: cols,
            rows: rows,
            environment: environment,
            workingDirectory: workingDirectory
        )

        isRunning = true
    }

    /// Sends keyboard input to the PTY.
    public func send(_ string: String) {
        pty.write(string)
    }

    /// Sends raw data to the PTY.
    public func send(_ data: Data) {
        pty.write(data)
    }

    /// Sends a special key to the PTY.
    public func sendKey(_ key: TerminalKey) {
        pty.write(key.ansiSequence)
    }

    /// Resizes the terminal.
    public func resize(columns: Int, rows: Int) {
        screenBuffer.resize(columns: columns, rows: rows)
        pty.resize(columns: UInt16(columns), rows: UInt16(rows))
    }

    /// Terminates the session.
    public func terminate() {
        pty.terminate()
        isRunning = false
    }

    // MARK: - Private

    private func handleOutput(_ data: Data) {
        let tokens = parser.parse(data)

        // Check for title changes
        for token in tokens {
            if case .setTitle(let newTitle) = token {
                self.title = newTitle
            }
        }

        screenBuffer.process(tokens)
        // Trigger SwiftUI update
        objectWillChange.send()
    }

    private func handleExit(_ exitCode: Int32) {
        isRunning = false
    }
}

// MARK: - Terminal Keys

public enum TerminalKey: Sendable {
    case up, down, left, right
    case home, end
    case pageUp, pageDown
    case delete
    case tab, backtab
    case escape
    case enter
    case backspace

    public var ansiSequence: String {
        switch self {
        case .up: return "\u{1B}[A"
        case .down: return "\u{1B}[B"
        case .right: return "\u{1B}[C"
        case .left: return "\u{1B}[D"
        case .home: return "\u{1B}[H"
        case .end: return "\u{1B}[F"
        case .pageUp: return "\u{1B}[5~"
        case .pageDown: return "\u{1B}[6~"
        case .delete: return "\u{1B}[3~"
        case .tab: return "\t"
        case .backtab: return "\u{1B}[Z"
        case .escape: return "\u{1B}"
        case .enter: return "\r"
        case .backspace: return "\u{7F}"
        }
    }
}
