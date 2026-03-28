import SwiftUI
import AnvilDomain

// MARK: - Session Dashboard

/// List view showing all agent sessions with status, cost, tokens.
/// Allows multi-select to create synthesis rooms or dispatch critique agents.
struct SessionDashboard: View {
    @ObservedObject var viewModel: AgentViewModel

    let onCreateSynthesis: ([String]) -> Void
    let onDispatchCritique: (String) -> Void

    @State private var dashboardFilter: DashboardFilter = .all

    private enum DashboardFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        case failed = "Failed"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            dashboardHeader
            Divider()
            filterBar
            dashboardContent
        }
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Session Dashboard")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            HStack(spacing: AnvilSpacing.md) {
                Text("\(viewModel.sessions.count) sessions")
                Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: viewModel.totalCost).doubleValue)) cost")
                Text("\(formatTokenCount(viewModel.totalTokens)) tokens")
                Text("\(viewModel.synthesisRooms.count) rooms")
            }
            .font(AnvilFont.label)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.md)
    }

    // MARK: - Filter

    private var filterBar: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Picker("Filter", selection: $dashboardFilter) {
                ForEach(DashboardFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if !viewModel.dashboardSelectedSessionIds.isEmpty {
                Spacer()

                Text("\(viewModel.dashboardSelectedSessionIds.count) selected")
                    .font(AnvilFont.label)
                    .foregroundStyle(.secondary)

                if viewModel.dashboardSelectedSessionIds.count >= 2 {
                    Button("Synthesize") {
                        onCreateSynthesis(Array(viewModel.dashboardSelectedSessionIds))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button("Clear") {
                    viewModel.dashboardSelectedSessionIds.removeAll()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - Content

    private var dashboardContent: some View {
        List(selection: Binding<Set<String>>(
            get: { viewModel.dashboardSelectedSessionIds },
            set: { viewModel.dashboardSelectedSessionIds = $0 }
        )) {
            // Synthesis rooms section
            if !viewModel.synthesisRooms.isEmpty {
                Section("Synthesis Rooms") {
                    ForEach(viewModel.synthesisRooms) { room in
                        SynthesisRoomRow(
                            room: room,
                            sessionNames: room.inputSessionIds.compactMap { id in
                                viewModel.sessions.first(where: { $0.id == id })?.displayName
                            },
                            onOpen: {
                                viewModel.showSynthesisRoom(room.id)
                            },
                            onDelete: {
                                viewModel.deleteSynthesisRoom(room.id)
                            }
                        )
                    }
                }
            }

            Section("Sessions") {
                ForEach(filteredSessions) { session in
                    SessionRow(
                        session: session,
                        linkedCount: viewModel.linkedSessions(for: session.id).count,
                        onOpen: {
                            viewModel.selectedSessionId = session.id
                            viewModel.showConversation()
                        },
                        onCritique: {
                            onDispatchCritique(session.id)
                        }
                    )
                    .tag(session.id)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Helpers

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private var filteredSessions: [AgentSession] {
        switch dashboardFilter {
        case .all:
            return viewModel.sessions
        case .active:
            return viewModel.sessions.filter { $0.status == .running || $0.status == .paused }
        case .completed:
            return viewModel.sessions.filter { $0.status == .completed }
        case .failed:
            return viewModel.sessions.filter { $0.status == .failed }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: AgentSession
    let linkedCount: Int
    let onOpen: () -> Void
    let onCritique: () -> Void

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AnvilSpacing.sm) {
                    Text(session.model)
                    Text(session.status.rawValue)
                    if linkedCount > 0 {
                        Text("\(linkedCount) linked")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Text(session.startedAt, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("Open Session", action: onOpen)
            Button("Review with Critique Agent", action: onCritique)
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentBlue
        case .failed: AnvilColor.accentRed
        case .paused: AnvilColor.accentAmber
        default: AnvilColor.textTertiary
        }
    }
}

// MARK: - Synthesis Room Row

struct SynthesisRoomRow: View {
    let room: SynthesisRoom
    let sessionNames: [String]
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentPurple)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.title)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text(sessionNames.joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Circle()
                .fill(synthesisStatusColor)
                .frame(width: 6, height: 6)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("Open Room", action: onOpen)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var synthesisStatusColor: Color {
        switch room.status {
        case .pending: AnvilColor.textTertiary
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentPurple
        case .failed: AnvilColor.accentRed
        }
    }
}
