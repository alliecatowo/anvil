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
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.sessions) { session in
                        Button {
                            viewModel.selectTab(session.id)
                        } label: {
                            HStack(spacing: AnvilSpacing.sm) {
                                Image(systemName: session.isRunning ? "terminal" : "terminal.fill")
                                    .foregroundStyle(session.isRunning ? AnvilColor.accentBlue : AnvilColor.textTertiary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .font(AnvilFont.sidebarItem)
                                        .foregroundStyle(AnvilColor.textPrimary)
                                        .lineLimit(1)
                                    Text(session.isRunning ? "Running" : "Exited")
                                        .font(AnvilFont.label)
                                        .foregroundStyle(AnvilColor.textTertiary)
                                }

                                Spacer()

                                if viewModel.sessions.count > 1 {
                                    Button {
                                        viewModel.closeTab(session.id)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, AnvilSpacing.sm)
                            .padding(.vertical, AnvilSpacing.sm)
                            .background(
                                viewModel.selectedSessionId == session.id
                                    ? AnvilColor.selectionBackground
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                terminalAction("New Session", icon: "plus") {
                    _ = viewModel.addTab()
                }
                terminalAction(splitSessionTitle, icon: splitIcon) {
                    toggleSplit(axis: .vertical)
                }
                terminalAction("Clear Screen", icon: "eraser") {
                    viewModel.clearBuffer()
                }
            }
            .padding(AnvilSpacing.sm)
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func terminalWorkspaceCard(session: TerminalSession?, showsHeaderActions: Bool) -> some View {
        VStack(spacing: 0) {
            workspaceHeader(session: session, showsHeaderActions: showsHeaderActions)
            Divider().overlay(AnvilColor.borderSubtle)
            TerminalView(viewModel: viewModel, sessionOverrideId: session?.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(AnvilSpacing.md)
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

    private func terminalAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AnvilColor.textSecondary)
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
