import SwiftUI
import AnvilTerminal

struct TerminalMode: View {
    @EnvironmentObject private var appState: AppState
    @State private var splitSessionId: UUID?
    @State private var splitAxis: TerminalSplitAxis = .vertical

    var body: some View {
        TerminalWorkspace(
            viewModel: appState.terminalViewModel,
            splitSessionId: $splitSessionId,
            splitAxis: $splitAxis,
            onSplitCommandHandled: {
                appState.triggerSplitVertical = false
                appState.triggerSplitHorizontal = false
            }
        )
        .onAppear {
            appState.isTerminalPanelVisible = false
        }
        .onChange(of: appState.triggerSplitVertical) { _, shouldSplit in
            guard shouldSplit else { return }
            handleExternalSplitCommand(axis: .vertical)
        }
        .onChange(of: appState.triggerSplitHorizontal) { _, shouldSplit in
            guard shouldSplit else { return }
            handleExternalSplitCommand(axis: .horizontal)
        }
    }

    private func handleExternalSplitCommand(axis: TerminalSplitAxis) {
        if splitSessionId != nil, splitAxis == axis {
            splitSessionId = nil
        } else {
            splitAxis = axis
            let newSession = appState.terminalViewModel.addTab()
            splitSessionId = newSession.id
        }
        appState.triggerSplitVertical = false
        appState.triggerSplitHorizontal = false
    }
}

private enum TerminalSplitAxis: Equatable {
    case vertical
    case horizontal
}

private struct TerminalWorkspace: View {
    @ObservedObject var viewModel: TerminalViewModel
    @Binding var splitSessionId: UUID?
    @Binding var splitAxis: TerminalSplitAxis
    let onSplitCommandHandled: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar at the top
            TerminalTabBar(viewModel: viewModel)

            Divider()

            // Terminal content area
            if let splitSession = viewModel.session(with: splitSessionId),
               splitSession.id != viewModel.selectedSessionId {
                splitContainer(primarySession: viewModel.selectedSession, secondarySession: splitSession)
            } else {
                terminalContentCard(session: viewModel.selectedSession, showsHeaderActions: true)
            }
        }
        .background(AnvilColor.backgroundPrimary)
        .onAppear {
            if viewModel.sessions.isEmpty {
                _ = viewModel.addTab()
            }
        }
        .onChange(of: viewModel.sessions.map(\.id)) { _, ids in
            if let splitId = splitSessionId, !ids.contains(splitId) {
                splitSessionId = nil
            }
        }
        .onChange(of: viewModel.selectedSessionId) { _, selectedId in
            if splitSessionId == selectedId {
                splitSessionId = nil
            }
        }
        .onChange(of: viewModel.sessions.count) { _, count in
            if count < 2 {
                splitSessionId = nil
            }
        }
    }

    @ViewBuilder
    private func splitContainer(primarySession: TerminalSession?, secondarySession: TerminalSession) -> some View {
        switch splitAxis {
        case .vertical:
            HSplitView {
                terminalContentCard(session: primarySession, showsHeaderActions: true)
                terminalContentCard(session: secondarySession, showsHeaderActions: false)
            }
        case .horizontal:
            VSplitView {
                terminalContentCard(session: primarySession, showsHeaderActions: true)
                terminalContentCard(session: secondarySession, showsHeaderActions: false)
            }
        }
    }

    @ViewBuilder
    private func terminalContentCard(session: TerminalSession?, showsHeaderActions: Bool) -> some View {
        VStack(spacing: 0) {
            if showsHeaderActions {
                contentHeader(session: session)
                Divider()
            }
            TerminalView(viewModel: viewModel, sessionOverrideId: session?.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(AnvilSpacing.md)
                .accessibilityLabel("Terminal output")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let id = session?.id else { return }
            if viewModel.selectedSessionId != id {
                viewModel.selectTab(id)
            }
        }
    }

    private func contentHeader(session: TerminalSession?) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session?.title ?? "Terminal")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text(session?.isRunning == false ? "Shell exited" : "Interactive shell")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            Button(splitSessionTitle, systemImage: splitIcon) {
                toggleSplit(axis: .vertical)
            }
            .buttonStyle(.bordered)

            Button("Clear", systemImage: "eraser") {
                viewModel.clearBuffer()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(.bar)
    }

    private var splitSessionTitle: String {
        splitSessionId == nil ? "Split Pane" : "Close Split"
    }

    private var splitIcon: String {
        switch splitAxis {
        case .vertical:
            "rectangle.split.2x1"
        case .horizontal:
            "rectangle.split.1x2"
        }
    }

    private func toggleSplit(axis: TerminalSplitAxis) {
        if splitSessionId != nil, splitAxis == axis {
            splitSessionId = nil
            onSplitCommandHandled()
            return
        }

        splitAxis = axis
        let newSession = viewModel.addTab()
        splitSessionId = newSession.id
        onSplitCommandHandled()
    }
}
