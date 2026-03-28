import SwiftUI
import AnvilDomain

struct AgentSidebar: View {
    @ObservedObject var viewModel: AgentViewModel

    var body: some View {
        List {
            if !viewModel.synthesisRooms.isEmpty {
                Section {
                    ForEach(viewModel.synthesisRooms) { room in
                        let isActive = isSynthesisRoomActive(room.id)
                        HoverableRow(isSelected: isActive) {
                            HStack(spacing: AnvilSpacing.sm) {
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AnvilColor.accentPurple)
                                    .accessibilityHidden(true)

                                Text(room.title)
                                    .lineLimit(1)

                                Spacer()

                                Circle()
                                    .fill(synthesisStatusColor(room.status))
                                    .frame(width: 6, height: 6)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                        .listRowBackground(isActive ? AnvilColor.selectionBackground : Color.clear)
                        .onTapGesture {
                            viewModel.showSynthesisRoom(room.id)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(room.title), \(room.status.rawValue)")
                        .accessibilityAddTraits(.isButton)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteSynthesisRoom(room.id)
                            }
                        }
                    }
                } header: {
                    AnvilSidebarSectionHeader(
                        title: "Synthesis Rooms",
                        icon: "arrow.triangle.merge",
                        count: viewModel.synthesisRooms.count
                    )
                }
            }

            Section {
                // Dashboard row
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11))
                        .foregroundStyle(viewModel.viewMode == .dashboard ? AnvilColor.textPrimary : AnvilColor.textTertiary)
                        .accessibilityHidden(true)

                    Text("Dashboard")
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(viewModel.viewMode == .dashboard ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .listRowBackground(viewModel.viewMode == .dashboard ? AnvilColor.selectionBackground : Color.clear)
                .onTapGesture {
                    viewModel.showDashboard()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Dashboard")
                .accessibilityAddTraits(viewModel.viewMode == .dashboard ? [.isButton, .isSelected] : .isButton)

                // Session rows
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
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
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
            } header: {
                HStack(spacing: AnvilSpacing.xs) {
                    AnvilSidebarSectionHeader(
                        title: "Sessions",
                        icon: "message",
                        count: viewModel.sessions.count
                    )

                    Button {
                        viewModel.startNewSession(prompt: "", model: viewModel.selectedModelId)
                        viewModel.showConversation()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .accessibilityLabel("New Session")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func isSynthesisRoomActive(_ roomId: String) -> Bool {
        if case .synthesisRoom(let id) = viewModel.viewMode {
            return id == roomId
        }
        return false
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
