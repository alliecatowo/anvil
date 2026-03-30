import SwiftUI
import AnvilTerminal

struct TerminalView: View {
    @ObservedObject var viewModel: TerminalViewModel
    var sessionOverrideId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let session = activeSession {
                TerminalContentView(session: session, viewModel: viewModel)
                    .id(session.id)
            } else {
                emptyState
            }
        }
        .background(Color.clear)
    }

    private var activeSession: TerminalSession? {
        if let sessionOverrideId {
            return viewModel.session(with: sessionOverrideId)
        }
        return viewModel.selectedSession
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "terminal")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))

            Text("No terminal session")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Terminal Content View

struct TerminalContentView: View {
    @ObservedObject var session: TerminalSession
    @ObservedObject var viewModel: TerminalViewModel

    var body: some View {
        VStack(spacing: 0) {
            // SwiftTerm-backed terminal view -- real PTY with full ANSI support
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
        .clipped()
    }
}
