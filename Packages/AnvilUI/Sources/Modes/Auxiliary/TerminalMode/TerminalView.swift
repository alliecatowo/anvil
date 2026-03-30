import SwiftUI
import SwiftTerm
import AnvilTerminal

/// Renders the active terminal session (or a specific override for splits).
/// Uses .id(session.id) to switch views, but reuses existing PTY views
/// via ReusableTerminalView when the session already has a bound terminal.
struct TerminalView: View {
    @ObservedObject var viewModel: TerminalViewModel
    var sessionOverrideId: UUID? = nil

    private var activeSession: TerminalSession? {
        if let sessionOverrideId {
            return viewModel.session(with: sessionOverrideId)
        }
        return viewModel.selectedSession
    }

    var body: some View {
        if let session = activeSession {
            TerminalContentView(session: session, viewModel: viewModel)
                .id(session.id)
        } else {
            emptyState
        }
    }

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
        Group {
            if session.terminalView != nil {
                // Session already has a PTY — reuse it
                ReusableTerminalView(session: session)
            } else {
                // First time — create PTY via SwiftTermView
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reusable Terminal View

/// NSViewRepresentable that reuses an existing LocalProcessTerminalView
/// instead of creating a new PTY process. This preserves terminal state
/// across tab switches.
struct ReusableTerminalView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        if let termView = session.terminalView {
            termView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(termView)
            NSLayoutConstraint.activate([
                termView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                termView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                termView.topAnchor.constraint(equalTo: container.topAnchor),
                termView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // If the terminal view isn't in the container yet, add it
        guard let termView = session.terminalView else { return }
        if termView.superview !== nsView {
            nsView.subviews.forEach { $0.removeFromSuperview() }
            termView.translatesAutoresizingMaskIntoConstraints = false
            nsView.addSubview(termView)
            NSLayoutConstraint.activate([
                termView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
                termView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
                termView.topAnchor.constraint(equalTo: nsView.topAnchor),
                termView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor),
            ])
        }
    }
}
