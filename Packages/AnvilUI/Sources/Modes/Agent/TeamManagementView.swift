import SwiftUI
import AnvilDomain

// MARK: - Team Member (derived from sessions)

/// A team member is a logical grouping of sessions by model (specialty).
/// Each unique model acts as a distinct "agent role" in the roster.
private struct TeamMember: Identifiable {
    let id: String          // model id
    let role: String        // human-readable role name
    let model: String       // model id
    let sessions: [AgentSession]

    var activeSessions: [AgentSession] {
        sessions.filter { $0.status == .running }
    }

    var currentTask: String? {
        // Show the most recent running session's display name
        activeSessions.first?.displayName
    }

    var status: AgentSessionStatus {
        if sessions.contains(where: { $0.status == .running }) { return .running }
        if sessions.contains(where: { $0.status == .failed }) { return .failed }
        if sessions.contains(where: { $0.status == .paused }) { return .paused }
        return .idle
    }

    var todayCost: Decimal {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessions
            .filter { calendar.startOfDay(for: $0.startedAt) == today }
            .reduce(Decimal.zero) { $0 + $1.cost }
    }
}

// MARK: - Team Management View

struct TeamManagementView: View {
    @ObservedObject var viewModel: AgentViewModel

    var onSelectSession: ((String) -> Void)?

    @State private var selectedMemberId: String?

    private var teamMembers: [TeamMember] {
        let grouped = Dictionary(grouping: viewModel.sessions) { $0.model }
        return grouped
            .map { model, sessions in
                TeamMember(
                    id: model,
                    role: readableRole(for: model),
                    model: model,
                    sessions: sessions.sorted { $0.lastActivityAt > $1.lastActivityAt }
                )
            }
            .sorted { lhs, rhs in
                // Running members first, then by session count
                if lhs.status == .running && rhs.status != .running { return true }
                if lhs.status != .running && rhs.status == .running { return false }
                return lhs.sessions.count > rhs.sessions.count
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            if teamMembers.isEmpty {
                emptyState
            } else {
                rosterList
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "person.3")
                .font(.system(size: 24))
                .foregroundStyle(AnvilColor.textTertiary)

            Text("No team members")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)

            Text("Start an agent session to populate the roster.")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AnvilSpacing.lg)
    }

    // MARK: - Roster List

    private var rosterList: some View {
        List(selection: $selectedMemberId) {
            ForEach(teamMembers) { member in
                teamMemberRow(member)
                    .tag(member.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 8))
            }
        }
        .listStyle(.inset)
        .onChange(of: selectedMemberId) { _, newId in
            guard let newId,
                  let member = teamMembers.first(where: { $0.id == newId }),
                  let mostRecent = member.activeSessions.first ?? member.sessions.first else { return }
            onSelectSession?(mostRecent.id)
        }
    }

    // MARK: - Team Member Row

    private func teamMemberRow(_ member: TeamMember) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Animated status dot
            statusDot(member.status)
                .frame(width: 14)

            // Name, role, current task
            VStack(alignment: .leading, spacing: 2) {
                Text(member.role)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AnvilSpacing.xs) {
                    if let task = member.currentTask {
                        Text(task)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Idle")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
            }

            Spacer()

            // Cost today + session count
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCost(member.todayCost))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(AnvilColor.textTertiary)

                Text("\(member.sessions.count) session\(member.sessions.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .padding(.vertical, AnvilSpacing.xxs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.role), \(member.status.rawValue), \(member.currentTask ?? "idle"), cost today \(formatCost(member.todayCost))")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Status Dot

    @ViewBuilder
    private func statusDot(_ status: AgentSessionStatus) -> some View {
        switch status {
        case .running:
            TeamRunningDot()
        case .failed:
            Circle()
                .fill(AnvilColor.accentRed)
                .frame(width: 8, height: 8)
        case .paused:
            Circle()
                .fill(AnvilColor.accentAmber)
                .frame(width: 8, height: 8)
        default:
            Circle()
                .stroke(AnvilColor.textTertiary, lineWidth: 1.5)
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Helpers

    private func readableRole(for model: String) -> String {
        // Derive a human-readable role from model ID
        if model.contains("opus") { return "Opus (Architect)" }
        if model.contains("sonnet") { return "Sonnet (Engineer)" }
        if model.contains("haiku") { return "Haiku (Scout)" }
        if model.contains("gpt-4") { return "GPT-4 (Analyst)" }
        if model.contains("gpt-3") { return "GPT-3.5 (Assistant)" }
        if model.contains("gemini") { return "Gemini (Researcher)" }
        if model.contains("deepseek") { return "DeepSeek (Coder)" }
        return model
    }

    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 2
        return formatter.string(from: cost as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Running Dot (animated pulse per spec)

private struct TeamRunningDot: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(AnvilColor.accentGreen)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .opacity(isAnimating ? 0.7 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
            .accessibilityLabel("Running")
    }
}
