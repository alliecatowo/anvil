import SwiftUI
import AnvilDomain

// MARK: - Synthesis Room View

/// Full-screen view for a synthesis room: shows input sessions side by side
/// and the synthesized output below (or streaming).
struct SynthesisRoomView: View {
    @ObservedObject var viewModel: AgentViewModel
    let roomId: String
    let onRunSynthesis: () -> Void

    private var room: SynthesisRoom? {
        viewModel.synthesisRooms.first { $0.id == roomId }
    }

    private var inputSessions: [AgentSession] {
        guard let room else { return [] }
        return room.inputSessionIds.compactMap { id in
            viewModel.sessions.first(where: { $0.id == id })
        }
    }

    var body: some View {
        if let room {
            VStack(spacing: 0) {
                roomHeader(room)
                Divider()
                roomContent(room)
            }
            .background(.regularMaterial)
        } else {
            Text("Room not found")
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Header

    private func roomHeader(_ room: SynthesisRoom) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Back to dashboard
            Button {
                viewModel.showDashboard()
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11))
                    Text("Dashboard")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Dashboard")
            .accessibilityAddTraits(.isButton)

            Divider().frame(height: 20)

            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AnvilColor.accentPurple)
                .accessibilityHidden(true)

            Text(room.title)
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            Text("\(inputSessions.count) sessions")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            Spacer()

            // Status
            Text(room.status.rawValue.capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor(room.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor(room.status).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            // Run synthesis button
            if room.status == .pending || room.status == .completed || room.status == .failed {
                Button(action: onRunSynthesis) {
                    Label(room.status == .pending ? "Run Synthesis" : "Re-run", systemImage: room.status == .pending ? "play.fill" : "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel(room.status == .pending ? "Run Synthesis" : "Re-run Synthesis")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.md)
        .background(AnvilColor.backgroundSecondary.opacity(0.5))
    }

    // MARK: - Content

    private func roomContent(_ room: SynthesisRoom) -> some View {
        HSplitView {
            // Left: Input sessions panel
            inputSessionsPanel

            // Right: Synthesis output
            synthesisOutputPanel(room)
        }
    }

    // MARK: - Input Sessions Panel

    private var inputSessionsPanel: some View {
        List {
            Section("Input Sessions") {
                ForEach(inputSessions) { session in
                    sessionSummaryCard(session)
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                }
            }
        }
        .listStyle(.inset)
        .frame(minWidth: 300)
    }

    private func sessionSummaryCard(_ session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Session header
            HStack {
                Circle()
                    .fill(sessionStatusColor(session.status))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)

                Text(session.displayName)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button {
                    viewModel.selectedSessionId = session.id
                    viewModel.showConversation()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Open session")
                .accessibilityLabel("Open session \(session.displayName)")
                .accessibilityAddTraits(.isButton)
            }

            // Stats
            HStack(spacing: AnvilSpacing.md) {
                Text(session.model)
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)

                Text("$\(String(format: "%.3f", NSDecimalNumber(decimal: session.cost).doubleValue))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AnvilColor.accentAmber)

                Text("\(session.messages.count) messages")
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Last few messages preview
            ForEach(session.messages.suffix(3), id: \.id) { message in
                HStack(alignment: .top, spacing: AnvilSpacing.xs) {
                    Image(systemName: message.role == .user ? "person" : "cpu")
                        .font(.system(size: 9))
                        .foregroundStyle(message.role == .user ? AnvilColor.accentBlue : AnvilColor.accentPurple)
                        .frame(width: 14)
                        .accessibilityHidden(true)

                    Text(message.content.prefix(200))
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textSecondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(AnvilSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .fill(AnvilColor.backgroundTertiary)
        }
    }

    // MARK: - Synthesis Output Panel

    private func synthesisOutputPanel(_ room: SynthesisRoom) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(AnvilColor.accentPurple)
                    .accessibilityHidden(true)
                Text("Synthesis Output")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                Spacer()

                if let output = room.output, !output.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(output, forType: .string)
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copy")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy synthesis output")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .background(AnvilColor.backgroundSecondary.opacity(0.3))

            Divider()

            ScrollView {
                if let output = room.output, !output.isEmpty {
                    VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                        Text(output)
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if room.status == .running {
                            HStack(spacing: AnvilSpacing.sm) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Synthesizing...")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.textTertiary)
                            }
                        }
                    }
                    .padding(AnvilSpacing.lg)
                } else if room.status == .running {
                    VStack(spacing: AnvilSpacing.md) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Running synthesis...")
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: AnvilSpacing.lg) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(AnvilColor.accentPurple.opacity(0.4))
                            .accessibilityHidden(true)

                        Text("Ready to Synthesize")
                            .font(AnvilFont.heading)
                            .foregroundStyle(AnvilColor.textSecondary)

                        Text("Click \"Run Synthesis\" to analyze all input sessions and produce a unified summary.")
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 400)
    }

    // MARK: - Helpers

    private func statusColor(_ status: SynthesisStatus) -> Color {
        switch status {
        case .pending: AnvilColor.textTertiary
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentPurple
        case .failed: AnvilColor.accentRed
        }
    }

    private func sessionStatusColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentBlue
        case .failed: AnvilColor.accentRed
        case .paused: AnvilColor.accentAmber
        default: AnvilColor.textTertiary
        }
    }
}
