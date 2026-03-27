import SwiftUI
import AnvilDomain

// MARK: - Session Dashboard

/// Grid view showing all agent sessions with status, cost, tokens.
/// Allows multi-select to create synthesis rooms or dispatch critique agents.
struct SessionDashboard: View {
    @ObservedObject var viewModel: AgentViewModel

    let onCreateSynthesis: ([String]) -> Void
    let onDispatchCritique: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: AnvilSpacing.md)
    ]

    var body: some View {
        VStack(spacing: 0) {
            dashboardHeader
            Divider().overlay(AnvilColor.borderSubtle)
            dashboardContent
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        HStack(spacing: AnvilSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Session Dashboard")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Text("\(viewModel.sessions.count) sessions \(viewModel.activeSessions.isEmpty ? "" : "(\(viewModel.activeSessions.count) active)")")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            // Aggregate stats
            HStack(spacing: AnvilSpacing.lg) {
                statBadge(
                    label: "Total Cost",
                    value: "$\(String(format: "%.2f", NSDecimalNumber(decimal: viewModel.totalCost).doubleValue))",
                    color: AnvilColor.accentAmber
                )
                statBadge(
                    label: "Total Tokens",
                    value: formatTokenCount(viewModel.totalTokens),
                    color: AnvilColor.accentBlue
                )
                statBadge(
                    label: "Rooms",
                    value: "\(viewModel.synthesisRooms.count)",
                    color: AnvilColor.accentPurple
                )
            }

            Divider().frame(height: 24).overlay(AnvilColor.borderSubtle)

            // Selection actions
            if !viewModel.dashboardSelectedSessionIds.isEmpty {
                HStack(spacing: AnvilSpacing.sm) {
                    Text("\(viewModel.dashboardSelectedSessionIds.count) selected")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentBlue)

                    if viewModel.dashboardSelectedSessionIds.count >= 2 {
                        Button {
                            onCreateSynthesis(Array(viewModel.dashboardSelectedSessionIds))
                        } label: {
                            HStack(spacing: AnvilSpacing.xxs) {
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 11))
                                Text("Synthesize")
                                    .font(AnvilFont.label)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, AnvilSpacing.sm)
                            .padding(.vertical, 4)
                            .background(AnvilColor.accentPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        viewModel.dashboardSelectedSessionIds.removeAll()
                    } label: {
                        Text("Clear")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.md)
        .background(AnvilColor.backgroundSecondary.opacity(0.5))
    }

    // MARK: - Content

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                // Synthesis rooms section
                if !viewModel.synthesisRooms.isEmpty {
                    synthesisRoomsSection
                }

                // Sessions grid
                LazyVGrid(columns: columns, spacing: AnvilSpacing.md) {
                    ForEach(viewModel.sessions) { session in
                        SessionCard(
                            session: session,
                            isSelected: viewModel.dashboardSelectedSessionIds.contains(session.id),
                            linkedSessions: viewModel.linkedSessions(for: session.id),
                            onToggleSelect: {
                                if viewModel.dashboardSelectedSessionIds.contains(session.id) {
                                    viewModel.dashboardSelectedSessionIds.remove(session.id)
                                } else {
                                    viewModel.dashboardSelectedSessionIds.insert(session.id)
                                }
                            },
                            onOpen: {
                                viewModel.selectedSessionId = session.id
                                viewModel.showConversation()
                            },
                            onCritique: {
                                onDispatchCritique(session.id)
                            }
                        )
                    }
                }
            }
            .padding(AnvilSpacing.lg)
        }
    }

    // MARK: - Synthesis Rooms Section

    private var synthesisRoomsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AnvilColor.accentPurple)
                Text("Synthesis Rooms")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: AnvilSpacing.md) {
                ForEach(viewModel.synthesisRooms) { room in
                    SynthesisRoomCard(
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

            Divider().overlay(AnvilColor.borderSubtle).padding(.top, AnvilSpacing.sm)
        }
    }

    // MARK: - Helpers

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AnvilColor.textTertiary)
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: AgentSession
    let isSelected: Bool
    let linkedSessions: [(session: AgentSession, label: String)]
    let onToggleSelect: () -> Void
    let onOpen: () -> Void
    let onCritique: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Header
            HStack {
                // Selection checkbox
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)

                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(session.displayName)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(session.status.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Model + time
            HStack {
                Text(session.model)
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textTertiary)
                Spacer()
                Text(session.startedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Stats row
            HStack(spacing: AnvilSpacing.md) {
                HStack(spacing: 3) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 10))
                    Text("$\(String(format: "%.3f", NSDecimalNumber(decimal: session.cost).doubleValue))")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(AnvilColor.accentAmber)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10))
                    Text("\(session.tokenUsage.inputTokens)in / \(session.tokenUsage.outputTokens)out")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(AnvilColor.textTertiary)

                Spacer()
            }

            // Linked sessions
            if !linkedSessions.isEmpty {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.accentPurple)
                    ForEach(linkedSessions.prefix(3), id: \.session.id) { linked in
                        Text(linked.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AnvilColor.accentPurple.opacity(0.8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentPurple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }

            // Actions
            HStack(spacing: AnvilSpacing.sm) {
                Button(action: onOpen) {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "message")
                            .font(.system(size: 10))
                        Text("Open")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(AnvilColor.accentBlue)
                    .padding(.horizontal, AnvilSpacing.xs)
                    .padding(.vertical, 3)
                    .background(AnvilColor.accentBlue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button(action: onCritique) {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "eye.trianglebadge.exclamationmark")
                            .font(.system(size: 10))
                        Text("Review")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(AnvilColor.accentAmber)
                    .padding(.horizontal, AnvilSpacing.xs)
                    .padding(.vertical, 3)
                    .background(AnvilColor.accentAmber.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(AnvilSpacing.cardPadding)
        .background(AnvilColor.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(
                    isSelected ? AnvilColor.accentBlue : AnvilColor.borderSubtle,
                    lineWidth: isSelected ? 2 : 1
                )
        )
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

// MARK: - Synthesis Room Card

struct SynthesisRoomCard: View {
    let room: SynthesisRoom
    let sessionNames: [String]
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AnvilColor.accentPurple)

                Text(room.title)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(room.status.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(synthesisStatusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(synthesisStatusColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Input sessions
            HStack(spacing: AnvilSpacing.xs) {
                ForEach(sessionNames.indices, id: \.self) { i in
                    if i > 0 {
                        Image(systemName: "plus")
                            .font(.system(size: 8))
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    Text(sessionNames[i])
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(AnvilColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            // Preview of output
            if let output = room.output, !output.isEmpty {
                Text(output.prefix(120) + (output.count > 120 ? "..." : ""))
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(2)
            }

            HStack {
                Button(action: onOpen) {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 10))
                        Text("Open")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(AnvilColor.accentPurple)
                    .padding(.horizontal, AnvilSpacing.xs)
                    .padding(.vertical, 3)
                    .background(AnvilColor.accentPurple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AnvilSpacing.cardPadding)
        .background(AnvilColor.accentPurple.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(AnvilColor.accentPurple.opacity(0.25), lineWidth: 1)
        )
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
