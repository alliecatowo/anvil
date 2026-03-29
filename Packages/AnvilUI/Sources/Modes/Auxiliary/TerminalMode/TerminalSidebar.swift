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
    }
}

struct TerminalSessionList: View {
    @ObservedObject var viewModel: TerminalViewModel
    var onSelect: ((UUID) -> Void)?

    var body: some View {
        ForEach(viewModel.sessions) { session in
            Button {
                viewModel.selectTab(session.id)
                onSelect?(session.id)
            } label: {
                AnvilListItem(
                    icon: session.isRunning ? "terminal" : "terminal.fill",
                    title: session.title,
                    subtitle: session.isRunning ? "running" : "exited",
                    tag: session.isRunning ? "running" : "stopped",
                    tagColor: session.isRunning ? AnvilColor.accentGreen : AnvilColor.textTertiary,
                    isSelected: viewModel.selectedSessionId == session.id,
                    isCompact: false
                )
            }
            .buttonStyle(.plain)
        }
    }
}
