import SwiftUI
import AnvilTerminal

/// Renders terminal sessions. Shows the active session (or a specific override).
/// All sessions are kept alive in a ZStack — only the active one is visible.
/// This prevents PTY processes from being killed on tab switch.
struct TerminalView: View {
    @ObservedObject var viewModel: TerminalViewModel
    var sessionOverrideId: UUID? = nil

    private var activeId: UUID? {
        sessionOverrideId ?? viewModel.selectedSessionId
    }

    var body: some View {
        ZStack {
            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                // Render ALL sessions but only show the active one.
                // This keeps PTY processes alive across tab switches.
                ForEach(viewModel.sessions) { session in
                    TerminalContentView(session: session, viewModel: viewModel)
                        .opacity(session.id == activeId ? 1 : 0)
                        .allowsHitTesting(session.id == activeId)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "terminal")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.tertiary.opacity(0.5))

            Text("No terminal session")
                .font(AnvilFont.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Terminal Content View

struct TerminalContentView: View {
    @ObservedObject var session: TerminalSession
    @ObservedObject var viewModel: TerminalViewModel

    var body: some View {
        SwiftTermView(
            shell: session.shell,
            workingDirectory: session.workingDirectory,
            onTitleChange: { [weak session] newTitle in
                session?.title = newTitle
            },
            onProcessExit: { [weak session] _ in
                session?.markExited()
            },
            onViewReady: { [weak session] view in
                session?.bindTerminalView(view)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
