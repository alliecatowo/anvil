import SwiftUI
import AnvilDomain

struct AgentSidebar: View {
    @ObservedObject var viewModel: AgentViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top actions
            HStack(spacing: AnvilSpacing.sm) {
                Button(action: {
                    viewModel.startNewSession(prompt: "", model: viewModel.selectedModelId)
                    viewModel.showConversation()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AnvilColor.accentPurple)
                        Text("New Session")
                            .font(AnvilFont.sidebarItem)
                        Spacer()
                    }
                    .foregroundStyle(AnvilColor.textPrimary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

                Button(action: {
                    viewModel.showDashboard()
                }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13))
                        .foregroundStyle(
                            viewModel.viewMode == .dashboard
                                ? AnvilColor.accentBlue
                                : AnvilColor.textTertiary
                        )
                }
                .buttonStyle(.borderless)
                .help("Session Dashboard")
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            ScrollView {
                LazyVStack(spacing: 0) {
                    // Synthesis rooms section
                    if !viewModel.synthesisRooms.isEmpty {
                        synthesisRoomsSection
                    }

                    // Sessions section
                    sectionHeader("Sessions", count: viewModel.sessions.count)

                    ForEach(viewModel.sessions) { session in
                        AgentSessionRow(
                            session: session,
                            isSelected: session.id == viewModel.selectedSessionId && viewModel.viewMode == .conversation,
                            linkedCount: viewModel.linkedSessions(for: session.id).count
                        )
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
        }
    }

    // MARK: - Synthesis Rooms Section

    private var synthesisRoomsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Synthesis Rooms", count: viewModel.synthesisRooms.count)

            ForEach(viewModel.synthesisRooms) { room in
                let isActive: Bool = {
                    if case .synthesisRoom(let id) = viewModel.viewMode {
                        return id == room.id
                    }
                    return false
                }()

                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentPurple)

                    Text(room.title)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Circle()
                        .fill(synthesisStatusColor(room.status))
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .background(isActive ? AnvilColor.selectionBackground : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.showSynthesisRoom(room.id)
                }
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        viewModel.deleteSynthesisRoom(room.id)
                    }
                }
            }

            Divider().overlay(AnvilColor.borderSubtle).padding(.vertical, AnvilSpacing.xxs)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AnvilColor.textTertiary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
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
