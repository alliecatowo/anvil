import SwiftUI
import SwiftTerm
import AnvilTerminal

/// NSViewRepresentable that manages ALL terminal sessions in a single AppKit container.
/// Each session gets its own LocalProcessTerminalView, shown/hidden based on selection.
/// PTY processes survive tab switches because views are hidden, never destroyed.
struct TerminalView: NSViewRepresentable {
    @ObservedObject var viewModel: TerminalViewModel
    var sessionOverrideId: UUID? = nil

    func makeNSView(context: Context) -> TerminalContainerNSView {
        TerminalContainerNSView()
    }

    func updateNSView(_ nsView: TerminalContainerNSView, context: Context) {
        let activeId = sessionOverrideId ?? viewModel.selectedSessionId
        nsView.sync(sessions: viewModel.sessions, activeId: activeId)
    }
}

/// AppKit container that owns terminal views. Uses autoresizingMask for layout.
/// Never reparents views — creates fresh and manages visibility.
final class TerminalContainerNSView: NSView {
    private var terminals: [UUID: LocalProcessTerminalView] = [:]
    private var currentActiveId: UUID?

    override var isFlipped: Bool { true }

    func sync(sessions: [TerminalSession], activeId: UUID?) {
        // 1. Create terminal views for new sessions
        for session in sessions where terminals[session.id] == nil {
            let tv = LocalProcessTerminalView(frame: bounds)
            tv.autoresizingMask = [.width, .height]
            tv.nativeBackgroundColor = NSColor(red: 0x2E/255.0, green: 0x34/255.0, blue: 0x40/255.0, alpha: 1.0)
            tv.nativeForegroundColor = NSColor(red: 0xEC/255.0, green: 0xEF/255.0, blue: 0xF4/255.0, alpha: 1.0)

            let env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
            tv.startProcess(
                executable: session.shell,
                args: ["-l"],
                environment: env,
                execName: (session.shell as NSString).lastPathComponent,
                currentDirectory: session.workingDirectory
            )

            session.bindTerminalView(tv)
            terminals[session.id] = tv
            tv.isHidden = true
            addSubview(tv)
        }

        // 2. Remove views for closed sessions
        let liveIds = Set(sessions.map(\.id))
        for id in Array(terminals.keys) where !liveIds.contains(id) {
            terminals[id]?.removeFromSuperview()
            terminals[id] = nil
        }

        // 3. Switch visibility (only if changed)
        if activeId != currentActiveId {
            if let oldId = currentActiveId {
                terminals[oldId]?.isHidden = true
            }
            if let newId = activeId {
                terminals[newId]?.isHidden = false
            }
            currentActiveId = activeId
        }
    }

    override func layout() {
        super.layout()
        // Ensure all terminal views fill the container
        for (_, tv) in terminals {
            tv.frame = bounds
        }
    }
}
