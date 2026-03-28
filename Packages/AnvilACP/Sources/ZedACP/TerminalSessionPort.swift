import Foundation

// MARK: - Terminal Session Port

/// Protocol abstracting a terminal PTY session for use by the ACP client.
///
/// This port allows ZedACPClient to manage terminal sessions without depending
/// directly on the AnvilTerminal package, preserving the hexagonal architecture.
/// The concrete adapter (backed by PTYProcess) is injected at construction time.
public protocol TerminalSessionPort: Sendable {
    /// Spawns the terminal process with the given parameters.
    func spawn(
        shell: String?,
        columns: UInt16,
        rows: UInt16,
        workingDirectory: String?
    ) throws

    /// Writes raw data to the terminal's stdin.
    func write(_ data: Data)

    /// Resizes the terminal to the given dimensions.
    func resize(columns: UInt16, rows: UInt16)

    /// Terminates the terminal process.
    func terminate()

    /// Callback invoked when the terminal produces output.
    /// The adapter must forward PTY output through this closure.
    var onOutput: (@Sendable (Data) -> Void)? { get set }

    /// Callback invoked when the terminal process exits.
    var onExit: (@Sendable (Int32) -> Void)? { get set }
}

/// Factory that creates new terminal session instances.
public protocol TerminalSessionFactory: Sendable {
    func makeSession() -> any TerminalSessionPort
}
