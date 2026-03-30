import SwiftUI
import SwiftTerm
import AnvilTerminal

/// A single NSView container that manages ALL terminal session views internally.
/// Shows/hides views based on the selected session without destroying them.
/// This preserves PTY processes across tab switches.
struct TerminalView: NSViewRepresentable {
    @ObservedObject var viewModel: TerminalViewModel
    var sessionOverrideId: UUID? = nil

    private var activeId: UUID? {
        sessionOverrideId ?? viewModel.selectedSessionId
    }

    func makeNSView(context: Context) -> TerminalContainerNSView {
        let container = TerminalContainerNSView()
        container.viewModel = viewModel
        container.updateSessions(viewModel.sessions, activeId: activeId)
        return container
    }

    func updateNSView(_ nsView: TerminalContainerNSView, context: Context) {
        nsView.viewModel = viewModel
        nsView.updateSessions(viewModel.sessions, activeId: activeId)
    }
}

/// AppKit container that owns all terminal views and shows only the active one.
class TerminalContainerNSView: NSView {
    var viewModel: TerminalViewModel?
    private var terminalViews: [UUID: LocalProcessTerminalView] = [:]

    func updateSessions(_ sessions: [TerminalSession], activeId: UUID?) {
        // Create views for new sessions
        for session in sessions {
            if terminalViews[session.id] == nil && session.terminalView == nil {
                // Create a new terminal view for this session
                let termView = LocalProcessTerminalView(frame: bounds)
                termView.nativeBackgroundColor = NSColor(red: 0x2E/255.0, green: 0x34/255.0, blue: 0x40/255.0, alpha: 1.0)
                termView.nativeForegroundColor = NSColor(red: 0xEC/255.0, green: 0xEF/255.0, blue: 0xF4/255.0, alpha: 1.0)

                let env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
                termView.startProcess(
                    executable: session.shell,
                    args: ["-l"],
                    environment: env,
                    execName: (session.shell as NSString).lastPathComponent,
                    currentDirectory: session.workingDirectory
                )

                session.bindTerminalView(termView)
                terminalViews[session.id] = termView
                termView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(termView)
                NSLayoutConstraint.activate([
                    termView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    termView.trailingAnchor.constraint(equalTo: trailingAnchor),
                    termView.topAnchor.constraint(equalTo: topAnchor),
                    termView.bottomAnchor.constraint(equalTo: bottomAnchor),
                ])
            } else if let existingView = session.terminalView, terminalViews[session.id] == nil {
                // Session already has a view (from SwiftTermView), adopt it
                terminalViews[session.id] = existingView
                existingView.translatesAutoresizingMaskIntoConstraints = false
                if existingView.superview !== self {
                    existingView.removeFromSuperview()
                    addSubview(existingView)
                    NSLayoutConstraint.activate([
                        existingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                        existingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                        existingView.topAnchor.constraint(equalTo: topAnchor),
                        existingView.bottomAnchor.constraint(equalTo: bottomAnchor),
                    ])
                }
            }
        }

        // Remove views for deleted sessions
        let sessionIds = Set(sessions.map(\.id))
        for (id, view) in terminalViews where !sessionIds.contains(id) {
            view.removeFromSuperview()
            terminalViews.removeValue(forKey: id)
        }

        // Show only the active session
        for (id, view) in terminalViews {
            view.isHidden = (id != activeId)
        }
    }
}
