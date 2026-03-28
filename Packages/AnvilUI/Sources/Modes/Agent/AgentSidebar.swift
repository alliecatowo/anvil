import SwiftUI
import AnvilDomain

struct AgentSidebar: View {
    @ObservedObject var viewModel: AgentViewModel
    @State private var activeSidebarTab: SidebarTab = .sessions

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AnvilSpacing.sm) {
                Button {
                    viewModel.startNewSession(prompt: "", model: viewModel.selectedModelId)
                    viewModel.showConversation()
                } label: {
                    Label("New Session", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Picker("View", selection: $activeSidebarTab) {
                    Label("Sessions", systemImage: "message").tag(SidebarTab.sessions)
                    Label("Dashboard", systemImage: "square.grid.2x2").tag(SidebarTab.dashboard)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            List {
                if !viewModel.synthesisRooms.isEmpty {
                    Section("Synthesis Rooms") {
                        ForEach(viewModel.synthesisRooms) { room in
                            let isActive = isSynthesisRoomActive(room.id)
                            HStack(spacing: AnvilSpacing.sm) {
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AnvilColor.accentPurple)

                                Text(room.title)
                                    .lineLimit(1)

                                Spacer()

                                Circle()
                                    .fill(synthesisStatusColor(room.status))
                                    .frame(width: 6, height: 6)
                            }
                            .contentShape(Rectangle())
                            .listRowBackground(isActive ? AnvilColor.selectionBackground : Color.clear)
                            .onTapGesture {
                                viewModel.showSynthesisRoom(room.id)
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteSynthesisRoom(room.id)
                                }
                            }
                        }
                    }
                }

                Section("Sessions") {
                    ForEach(viewModel.sessions) { session in
                        AgentSessionRow(
                            session: session,
                            isSelected: session.id == viewModel.selectedSessionId && viewModel.viewMode == .conversation,
                            linkedCount: viewModel.linkedSessions(for: session.id).count
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedSessionId = session.id
                            viewModel.showConversation()
                        }
                        .contextMenu {
                            Button("Rename...") {
                                viewModel.selectedSessionId = session.id
                            }
                            Button("Export to Clipboard") {
                                viewModel.exportSessionToClipboard(session.id)
                            }
                            Divider()
                            Button("Review with Critique Agent") {
                                viewModel.dispatchCritiqueAgent(for: session.id)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.deleteSession(session.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .onAppear {
            syncSidebarTabFromViewMode()
        }
        .onChange(of: activeSidebarTab) { _, newValue in
            switch newValue {
            case .sessions:
                if case .dashboard = viewModel.viewMode {
                    viewModel.showConversation()
                }
            case .dashboard:
                viewModel.showDashboard()
            }
        }
        .onChange(of: viewModel.viewMode) { _, _ in
            syncSidebarTabFromViewMode()
        }
    }

    private enum SidebarTab: Hashable {
        case sessions
        case dashboard
    }

    private func isSynthesisRoomActive(_ roomId: String) -> Bool {
        if case .synthesisRoom(let id) = viewModel.viewMode {
            return id == roomId
        }
        return false
    }

    private func syncSidebarTabFromViewMode() {
        switch viewModel.viewMode {
        case .dashboard:
            activeSidebarTab = .dashboard
        default:
            activeSidebarTab = .sessions
        }
    }

    private func synthesisStatusColor(_ status: SynthesisStatus) -> Color {
        switch status {
        case .pending: AnvilColor.textTertiary
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentPurple
        case .failed: AnvilColor.accentRed
        }
    }
}

struct AgentSessionRow: View {
    let session: AgentSession
    let isSelected: Bool
    var linkedCount: Int = 0

    var body: some View {
        AnvilListItem(
            icon: statusIcon,
            title: session.displayName,
            subtitle: subtitle,
            tag: session.status.rawValue,
            tagColor: statusColor,
            isSelected: isSelected,
            isCompact: false
        )
    }

    private var subtitle: String {
        var parts = [session.model]
        if linkedCount > 0 {
            parts.append("\(linkedCount) linked")
        }
        return parts.joined(separator: " | ")
    }

    var statusIcon: String {
        switch session.status {
        case .running: "circle.fill"
        case .completed: "checkmark.circle"
        case .failed: "xmark.circle"
        case .paused: "pause.circle"
        default: "circle"
        }
    }

    var statusColor: Color {
        switch session.status {
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentBlue
        case .failed: AnvilColor.accentRed
        case .paused: AnvilColor.accentAmber
        default: AnvilColor.textTertiary
        }
    }
}
