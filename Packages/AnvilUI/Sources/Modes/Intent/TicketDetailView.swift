import SwiftUI
import AnvilDomain
import AnvilGit

struct TicketDetailView: View {
    @ObservedObject var viewModel: IntentViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    @State private var branchCreated: String?
    @State private var isDispatching = false

    var body: some View {
        if let ticket = viewModel.selectedTicket {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back bar
                    backBar(ticket)

                    Divider().overlay(AnvilColor.borderSubtle)

                    // Content
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxl) {
                        headerSection(ticket)
                        descriptionSection(ticket)
                        labelsSection(ticket)
                        relatedSection(ticket)
                        activitySection
                    }
                    .padding(AnvilSpacing.xxl)
                }
            }
            .background(AnvilColor.backgroundPrimary)
        }
    }

    // MARK: - Back Bar

    private func backBar(_ ticket: Ticket) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Button {
                viewModel.selectTicket(nil)
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Back")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Create Branch button
            if let created = branchCreated {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentGreen)
                    Text(created)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentGreen)
                }
            } else {
                AnvilButton("Create Branch", icon: "arrow.triangle.branch", style: .secondary) {
                    createBranchForTicket(ticket)
                }
            }

            // Dispatch to Agent button
            AnvilButton("Dispatch to Agent", icon: "cpu", style: .primary) {
                dispatchTicketToAgent(ticket)
            }
            .disabled(isDispatching)

            Text(ticket.id)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - Branch Creation

    private func createBranchForTicket(_ ticket: Ticket) {
        let branchName = generateBranchName(from: ticket)
        guard let adapter = container.getOrCreateGitAdapter() else { return }
        Task {
            await appState.createBranch(branchName, using: adapter)
            branchCreated = branchName
        }
    }

    private func generateBranchName(from ticket: Ticket) -> String {
        let id = ticket.id.lowercased()
        let slug = ticket.title
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .prefix(40)
        return "\(id)/\(slug)"
    }

    // MARK: - Dispatch to Agent

    private func dispatchTicketToAgent(_ ticket: Ticket) {
        isDispatching = true

        // Create branch if not already created
        if branchCreated == nil {
            createBranchForTicket(ticket)
        }

        // Dispatch to agent mode: create session, switch mode
        appState.agentViewModel.dispatchFromTicket(
            ticketId: ticket.id,
            title: ticket.title,
            description: ticket.description
        )
        appState.switchMode(.agent)

        isDispatching = false
    }

    // MARK: - Header

    private func headerSection(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            // Editable title
            TextField("Title", text: $viewModel.editingTitle, onCommit: {
                viewModel.updateTitle(viewModel.editingTitle)
            })
            .textFieldStyle(.plain)
            .font(AnvilFont.heading)
            .foregroundStyle(AnvilColor.textPrimary)

            // Metadata row
            HStack(spacing: AnvilSpacing.lg) {
                // Status
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: IntentViewModel.statusIcon(ticket.status))
                        .font(.system(size: 12))
                        .foregroundStyle(IntentViewModel.statusColor(ticket.status))
                    AnvilBadge(
                        text: ticket.status.capitalized,
                        color: IntentViewModel.statusColor(ticket.status)
                    )
                }

                // Priority
                HStack(spacing: AnvilSpacing.xxs) {
                    priorityIndicator(ticket.priority)
                    Text(IntentViewModel.priorityLabel(ticket.priority))
                        .font(AnvilFont.label)
                        .foregroundStyle(IntentViewModel.priorityColor(ticket.priority))
                }

                // Assignee
                if let assignee = ticket.assignee {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Circle()
                            .fill(AnvilColor.backgroundElevated)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text(String(assignee.prefix(1)).uppercased())
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AnvilColor.textSecondary)
                            )
                        Text(assignee)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                }

                // Story points
                if let sp = ticket.storyPoints {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "diamond")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text("\(sp) pts")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                }

                // Due date
                if let due = ticket.dueDate {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text(due, style: .date)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Description

    private func descriptionSection(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("DESCRIPTION")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)

            if ticket.description.isEmpty {
                Text("No description provided.")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .italic()
            } else {
                Text(ticket.description)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .textSelection(.enabled)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Labels

    private func labelsSection(_ ticket: Ticket) -> some View {
        Group {
            if !ticket.labels.isEmpty {
                VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    Text("LABELS")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .tracking(0.3)

                    FlowLayout(spacing: AnvilSpacing.xs) {
                        ForEach(ticket.labels, id: \.self) { label in
                            AnvilBadge(text: label, color: labelColor(label))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Related Items

    private func relatedSection(_ ticket: Ticket) -> some View {
        let relations = viewModel.relationsFor(ticket.id)
        return Group {
            if !relations.isEmpty {
                VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    Text("RELATED")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .tracking(0.3)

                    ForEach(relations) { relation in
                        relationRow(relation, currentId: ticket.id)
                    }
                }
            }
        }
    }

    private func relationRow(_ relation: TicketRelation, currentId: String) -> some View {
        let isSource = relation.sourceId == currentId
        let otherId = isSource ? relation.targetId : relation.sourceId
        let otherTicket = viewModel.tickets.first { $0.id == otherId }
        let label = relationLabel(relation.type, isSource: isSource)

        return HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: relationIcon(relation.type))
                .font(.system(size: 11))
                .foregroundStyle(relationColor(relation.type))
                .frame(width: 16)

            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            if let other = otherTicket {
                Text(other.id)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.accentBlue)

                Text(other.title)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .lineLimit(1)
            } else {
                Text(otherId)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()
        }
        .padding(AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Activity Placeholder

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("ACTIVITY")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)

            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: AnvilSpacing.sm) {
                    Circle()
                        .fill(AnvilColor.backgroundElevated)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AnvilColor.backgroundTertiary)
                                .frame(width: CGFloat(80 + i * 20), height: 10)
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AnvilColor.backgroundTertiary)
                                .frame(width: 50, height: 8)
                        }
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AnvilColor.backgroundTertiary)
                            .frame(width: CGFloat(150 + i * 30), height: 8)
                    }
                }
                .padding(.vertical, AnvilSpacing.xxs)
            }

            Text("Activity log coming soon")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, AnvilSpacing.xs)
        }
    }

    // MARK: - Helpers

    private func priorityIndicator(_ priority: TicketPriority) -> some View {
        let color = IntentViewModel.priorityColor(priority)
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private func labelColor(_ label: String) -> Color {
        switch label.lowercased() {
        case "bug", "p0-sev":           AnvilColor.accentRed
        case "feature":                  AnvilColor.accentGreen
        case "infra", "database":        AnvilColor.accentTeal
        case "testing":                  AnvilColor.accentPurple
        case "refactor", "architecture": AnvilColor.accentAmber
        case "auth":                     AnvilColor.accentRed
        default:                         AnvilColor.accentBlue
        }
    }

    private func relationLabel(_ type: TicketRelationType, isSource: Bool) -> String {
        switch type {
        case .blocks:    isSource ? "Blocks" : "Blocked by"
        case .blockedBy: isSource ? "Blocked by" : "Blocks"
        case .parent:    isSource ? "Parent of" : "Child of"
        case .child:     isSource ? "Child of" : "Parent of"
        case .duplicate: "Duplicate of"
        case .related:   "Related to"
        }
    }

    private func relationIcon(_ type: TicketRelationType) -> String {
        switch type {
        case .blocks, .blockedBy: "exclamationmark.triangle"
        case .parent, .child:     "arrow.up.arrow.down"
        case .duplicate:          "doc.on.doc"
        case .related:            "link"
        }
    }

    private func relationColor(_ type: TicketRelationType) -> Color {
        switch type {
        case .blocks, .blockedBy: AnvilColor.accentRed
        case .parent, .child:     AnvilColor.accentBlue
        case .duplicate:          AnvilColor.accentAmber
        case .related:            AnvilColor.textSecondary
        }
    }
}

// MARK: - Flow Layout

/// Simple horizontal wrapping layout for labels/badges.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (offsets, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
