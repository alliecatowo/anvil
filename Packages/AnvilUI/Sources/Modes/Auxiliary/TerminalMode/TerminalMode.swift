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
        HSplitView {
            sessionSidebar
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)

            if let splitSession = viewModel.session(with: splitSessionId), splitSession.id != viewModel.selectedSessionId {
                splitContainer(primarySession: viewModel.selectedSession, secondarySession: splitSession)
            } else {
                terminalWorkspaceCard(session: viewModel.selectedSession, showsHeaderActions: true)
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
                terminalWorkspaceCard(session: primarySession, showsHeaderActions: true)
                terminalWorkspaceCard(session: secondarySession, showsHeaderActions: false)
            }
        case .horizontal:
            VSplitView {
                terminalWorkspaceCard(session: primarySession, showsHeaderActions: true)
                terminalWorkspaceCard(session: secondarySession, showsHeaderActions: false)
            }
        }
    }

    private var sessionSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Terminal")
                    .font(AnvilFont.subheading)
                Spacer()
                Button {
                    _ = viewModel.addTab()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("New Terminal Session")
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .background(.bar)

            List {
                Section("Sessions") {
                    ForEach(viewModel.sessions) { session in
                        HStack(spacing: AnvilSpacing.sm) {
                            Image(systemName: session.isRunning ? "terminal" : "terminal.fill")
                                .foregroundStyle(session.isRunning ? AnvilColor.accentBlue : .secondary)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(AnvilFont.sidebarItem)
                                    .lineLimit(1)
                                Text(session.isRunning ? "Running" : "Exited")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.sessions.count > 1 {
                                Button {
                                    viewModel.closeTab(session.id)
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Close \(session.title)")
                            }
                        }
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(session.title), \(session.isRunning ? "running" : "exited")")
                        .accessibilityAddTraits(.isButton)
                        .onTapGesture {
                            viewModel.selectTab(session.id)
                        }
                        .listRowBackground(viewModel.selectedSessionId == session.id ? Color.accentColor.opacity(0.14) : Color.clear)
                    }
                }

            }
            .listStyle(.sidebar)
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func terminalWorkspaceCard(session: TerminalSession?, showsHeaderActions: Bool) -> some View {
        VStack(spacing: 0) {
            workspaceHeader(session: session, showsHeaderActions: showsHeaderActions)
            Divider()
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

    private func workspaceHeader(session: TerminalSession?, showsHeaderActions: Bool) -> some View {
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

            if showsHeaderActions {
                Button("New Session", systemImage: "plus") {
                    _ = viewModel.addTab()
                }
                .buttonStyle(.bordered)

                Button(splitSessionTitle, systemImage: splitIcon) {
                    toggleSplit(axis: .vertical)
                }
                .buttonStyle(.bordered)

                Button("Clear", systemImage: "eraser") {
                    viewModel.clearBuffer()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundToolbar)
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
