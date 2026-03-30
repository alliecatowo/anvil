import SwiftUI
import AnvilTerminal

struct TerminalSidebarSection: View {
    @ObservedObject var viewModel: TerminalViewModel

    var body: some View {
        List {
            AnvilSidebarSection(
                title: "Sessions",
                icon: "terminal",
                count: viewModel.sessions.count,
                content: {
                    TerminalSessionList(viewModel: viewModel)
                },
                trailing: {
                    Button {
                        _ = viewModel.addTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help("New Terminal Session")
                    .accessibilityLabel("New Terminal Session")
                }
            )
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}

struct TerminalSessionList: View {
    @ObservedObject var viewModel: TerminalViewModel
    var onSelect: ((UUID) -> Void)?

    var body: some View {
        ForEach(viewModel.sessions) { session in
            AnvilSidebarRowButton(
                title: session.title,
                icon: session.isRunning ? "terminal" : "terminal.fill",
                subtitle: session.isRunning ? "running" : "exited",
                isActive: viewModel.selectedSessionId == session.id
            ) {
                viewModel.selectTab(session.id)
                onSelect?(session.id)
            } trailing: {
                AnvilBadge(
                    text: session.isRunning ? "running" : "stopped",
                    color: session.isRunning ? AnvilColor.accentGreen : AnvilColor.textTertiary
                )
            }
        }
    }
}
