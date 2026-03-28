import SwiftUI
import AppKit
import SwiftTerm

// MARK: - SwiftTerm NSView Wrapper

/// A SwiftUI wrapper around SwiftTerm's `LocalProcessTerminalView`.
/// Each instance owns one real PTY process running `/bin/zsh` (or a custom shell).
/// ANSI colors, resize handling, and full terminal emulation are provided by SwiftTerm.
public struct SwiftTermView: NSViewRepresentable {
    public typealias NSViewType = LocalProcessTerminalView

    private let shell: String
    private let workingDirectory: String?
    private let environment: [String]?
    private let onTitleChange: (@MainActor @Sendable (String) -> Void)?
    private let onProcessExit: (@MainActor @Sendable (Int32) -> Void)?
    private let onViewReady: (@MainActor @Sendable (LocalProcessTerminalView) -> Void)?

    /// Creates a SwiftTermView that launches a real PTY shell.
    ///
    /// - Parameters:
    ///   - shell: Path to the shell binary. Defaults to `/bin/zsh`.
    ///   - workingDirectory: Initial working directory for the shell process.
    ///   - environment: Environment variables as `["KEY=VALUE"]` strings. Pass `nil` for defaults.
    ///   - onTitleChange: Called when the terminal title changes (e.g. via OSC escape sequences).
    ///   - onProcessExit: Called when the shell process exits.
    ///   - onViewReady: Called once when the `LocalProcessTerminalView` is created, allowing
    ///     the caller to store a reference for resize/send operations.
    public init(
        shell: String = "/bin/zsh",
        workingDirectory: String? = nil,
        environment: [String]? = nil,
        onTitleChange: (@MainActor @Sendable (String) -> Void)? = nil,
        onProcessExit: (@MainActor @Sendable (Int32) -> Void)? = nil,
        onViewReady: (@MainActor @Sendable (LocalProcessTerminalView) -> Void)? = nil
    ) {
        self.shell = shell
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.onTitleChange = onTitleChange
        self.onProcessExit = onProcessExit
        self.onViewReady = onViewReady
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            onTitleChange: onTitleChange,
            onProcessExit: onProcessExit
        )
    }

    @MainActor
    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))

        // Apply dark terminal colors (Nord-inspired palette)
        terminalView.nativeBackgroundColor = NSColor(red: 0x2E/255.0, green: 0x34/255.0, blue: 0x40/255.0, alpha: 1.0)
        terminalView.nativeForegroundColor = NSColor(red: 0xEC/255.0, green: 0xEF/255.0, blue: 0xF4/255.0, alpha: 1.0)

        // Set the delegate for title changes and process exit
        terminalView.processDelegate = context.coordinator

        // Build environment: inherit current process environment if none specified
        let env = environment ?? Terminal.getEnvironmentVariables(termName: "xterm-256color")

        // Launch the shell as a login shell
        let loginName = "-" + (shell as NSString).lastPathComponent

        terminalView.startProcess(
            executable: shell,
            args: [loginName],
            environment: env,
            execName: loginName,
            currentDirectory: workingDirectory
        )

        // Notify caller that the view is ready
        onViewReady?(terminalView)

        return terminalView
    }

    @MainActor
    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Update coordinator callbacks in case closures changed
        context.coordinator.onTitleChange = onTitleChange
        context.coordinator.onProcessExit = onProcessExit
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, LocalProcessTerminalViewDelegate, @unchecked Sendable {
        var onTitleChange: (@MainActor @Sendable (String) -> Void)?
        var onProcessExit: (@MainActor @Sendable (Int32) -> Void)?

        init(
            onTitleChange: (@MainActor @Sendable (String) -> Void)?,
            onProcessExit: (@MainActor @Sendable (Int32) -> Void)?
        ) {
            self.onTitleChange = onTitleChange
            self.onProcessExit = onProcessExit
        }

        // MARK: - LocalProcessTerminalViewDelegate

        public func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // SwiftTerm handles TIOCSWINSZ internally
        }

        public func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            let cb = onTitleChange
            DispatchQueue.main.async { cb?(title) }
        }

        public func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
            // Could be used to track cwd changes in the future
        }

        public func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
            let cb = onProcessExit
            let code = exitCode ?? -1
            DispatchQueue.main.async { cb?(code) }
        }
    }
}
