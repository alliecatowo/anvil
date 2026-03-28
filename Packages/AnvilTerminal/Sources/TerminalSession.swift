import Foundation
import SwiftTerm
import AppKit

// MARK: - Terminal Session

/// A single terminal session backed by SwiftTerm's LocalProcessTerminalView.
/// Each session corresponds to one real PTY process.
@MainActor
public final class TerminalSession: ObservableObject, Identifiable, Sendable {

    public let id: UUID
    @Published public var title: String
    @Published public private(set) var isRunning: Bool = false

    /// The shell executable path for this session.
    public let shell: String

    /// The initial working directory for this session.
    public let workingDirectory: String?

    /// Reference to the SwiftTerm view backing this session.
    /// Set when the SwiftTermView's `onViewReady` fires.
    public private(set) var terminalView: LocalProcessTerminalView?

    public init(
        id: UUID = UUID(),
        title: String = "zsh",
        shell: String? = nil,
        workingDirectory: String? = nil,
        columns: Int = 80,
        rows: Int = 24
    ) {
        self.id = id
        self.title = title
        self.shell = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        self.workingDirectory = workingDirectory
        self.isRunning = true
    }

    // MARK: - View Binding

    /// Called by SwiftTermView.onViewReady to bind the underlying NSView to this session.
    public func bindTerminalView(_ view: LocalProcessTerminalView) {
        self.terminalView = view
    }

    // MARK: - Input

    /// Sends a string to the PTY process.
    public func send(_ string: String) {
        guard let view = terminalView, let data = string.data(using: .utf8) else { return }
        let bytes = [UInt8](data)
        view.process.send(data: bytes[...])
    }

    /// Sends raw data to the PTY process.
    public func send(_ data: Data) {
        guard let view = terminalView else { return }
        let bytes = [UInt8](data)
        view.process.send(data: bytes[...])
    }

    /// Sends a special key to the PTY.
    public func sendKey(_ key: TerminalKey) {
        send(key.ansiSequence)
    }

    // MARK: - Lifecycle

    /// Resizes the terminal. SwiftTerm handles TIOCSWINSZ internally when
    /// the NSView frame changes, so this is typically not needed for SwiftTermView usage.
    public func resize(columns: Int, rows: Int) {
        // SwiftTerm auto-handles resize via the NSView layout system.
        // This method exists for API compatibility.
    }

    /// Marks the session as exited.
    public func markExited() {
        isRunning = false
    }

    /// Terminates the session.
    public func terminate() {
        terminalView?.terminate()
        isRunning = false
        terminalView = nil
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
