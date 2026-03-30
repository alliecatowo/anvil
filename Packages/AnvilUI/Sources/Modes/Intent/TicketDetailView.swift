import SwiftUI
import AnvilDomain
import AnvilGit

struct TicketDetailView: View {
    @ObservedObject var viewModel: IntentViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    @State private var branchCreated: String?
    @State private var isDispatching = false
    @State private var showingLinkPopover = false
    @State private var linkRelationType: TicketRelationType = .related
    @State private var linkTargetSearch = ""
    @State private var isEditingDescription = false

    var body: some View {
        if let ticket = viewModel.selectedTicket {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back bar
                    backBar(ticket)

                    Divider()

                    // Content
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxl) {
                        headerSection(ticket)
                        metadataEditors(ticket)
                        descriptionSection(ticket)
                        subtaskSection(ticket)
                        labelsSection(ticket)
                        relatedSection(ticket)
                        activitySection(ticket)
                    }
                    .padding(AnvilSpacing.xxl)
                }
            }
            .background(.regularMaterial)
        }
    }

    // MARK: - Back Bar

    private func backBar(_ ticket: Ticket) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Button {
                viewModel.closeTicketDetailInMainPane()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("intent.ticket-detail.back")

            Spacer()

            if let created = branchCreated {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text(created)
                        .font(AnvilFont.code)
                        .foregroundStyle(.green)
                }
            }

            Button {
                startWork(ticket)
            } label: {
                Label(isDispatching ? "Starting..." : "Start Work", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isDispatching)
            .accessibilityIdentifier("intent.ticket-detail.start-work")

            if branchCreated == nil {
                Button {
                    createBranchForTicket(ticket)
                } label: {
                    Label("Branch Only", systemImage: "arrow.triangle.branch")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("intent.ticket-detail.branch-only")
            }

            Button(role: .destructive) {
                withAnimation(AnvilAnimation.standard) {
                    viewModel.deleteTicket(ticket.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Delete ticket")
            .accessibilityIdentifier("intent.ticket-detail.delete")

            Text(ticket.id)
                .font(AnvilFont.code)
                .foregroundStyle(.tertiary)
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

    // MARK: - Start Work (Branch + Agent)

    private func startWork(_ ticket: Ticket) {
        isDispatching = true

        let branchName = generateBranchName(from: ticket)

        // Create the branch if a git adapter is available, but proceed either way
        // so that "Start Work" always dispatches an agent session.
        Task {
            if branchCreated == nil, let adapter = container.getOrCreateGitAdapter() {
                await appState.createBranch(branchName, using: adapter)
                branchCreated = branchName
            }

            // Move ticket to "in progress" on the board
            viewModel.moveTicket(ticket.id, toStatus: "in progress")

            // Create a new agent session pre-loaded with ticket context
            appState.agentViewModel.dispatchFromTicket(
                ticketId: ticket.id,
                title: ticket.title,
                description: ticket.description
            )

            // Switch to agent mode so the user sees the conversation
            appState.switchSpace(.build)

            isDispatching = false
        }
    }

    // MARK: - Header

    private func headerSection(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            // Editable title
            TextField("Title", text: $viewModel.editingTitle, onCommit: {
                viewModel.updateTitle(viewModel.editingTitle)
            })
            .textFieldStyle(.roundedBorder)
            .font(AnvilFont.heading)
            .foregroundStyle(.primary)
            .accessibilityLabel("Ticket title")
            .accessibilityIdentifier("intent.ticket-detail.title")

            // Metadata row (read-only display)
            HStack(spacing: AnvilSpacing.lg) {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: IntentViewModel.statusIcon(ticket.status))
                        .font(.system(size: 12))
                        .foregroundStyle(IntentViewModel.statusColor(ticket.status))
                    AnvilBadge(
                        text: ticket.status.capitalized,
                        color: IntentViewModel.statusColor(ticket.status)
                    )
                }

                HStack(spacing: AnvilSpacing.xxs) {
                    priorityIndicator(ticket.priority)
                    Text(IntentViewModel.priorityLabel(ticket.priority))
                        .font(AnvilFont.label)
                        .foregroundStyle(IntentViewModel.priorityColor(ticket.priority))
                }

                if let assignee = ticket.assignee {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text(String(assignee.prefix(1)).uppercased())
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            )
                        Text(assignee)
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
                    }
                }

                if let sp = ticket.storyPoints {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "diamond")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text("\(sp) pts")
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
                    }
                }

                if let due = ticket.dueDate {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(due, style: .date)
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Metadata Editors

    private func metadataEditors(_ ticket: Ticket) -> some View {
        Form {
            LabeledContent("Status") {
                Picker("Status", selection: Binding(
                    get: { ticket.status },
                    set: { viewModel.updateStatus(ticket.id, status: $0) }
                )) {
                    ForEach(viewModel.allStatuses, id: \.self) { Text($0.capitalized).tag($0) }
                }
                .labelsHidden()
                .accessibilityLabel("Ticket status")
            }
            LabeledContent("Priority") {
                Picker("Priority", selection: Binding(
                    get: { ticket.priority },
                    set: { viewModel.updatePriority(ticket.id, priority: $0) }
                )) {
                    ForEach([TicketPriority.critical, .high, .medium, .low, .none], id: \.rawValue) {
                        Text(IntentViewModel.priorityLabel($0)).tag($0)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Ticket priority")
            }
            LabeledContent("Assignee") {
                Picker("Assignee", selection: Binding(
                    get: { ticket.assignee ?? "" },
                    set: { viewModel.updateAssignee(ticket.id, assignee: $0.isEmpty ? nil : $0) }
                )) {
                    Text("Unassigned").tag("")
                    ForEach(viewModel.allAssignees, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .accessibilityLabel("Ticket assignee")
            }
            LabeledContent("Due Date") {
                HStack(spacing: 4) {
                    DatePicker("", selection: Binding(
                        get: { ticket.dueDate ?? Date.now },
                        set: { viewModel.updateDueDate(ticket.id, dueDate: $0) }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel("Due date")
                    if ticket.dueDate != nil {
                        Button { viewModel.updateDueDate(ticket.id, dueDate: nil) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Description

    private func descriptionSection(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("Description")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    isEditingDescription.toggle()
                    if isEditingDescription {
                        viewModel.editingDescription = ticket.description
                    }
                } label: {
                    Text(isEditingDescription ? "Done" : "Edit")
                        .font(AnvilFont.label)
                }
                .buttonStyle(.borderless)
            }

            if isEditingDescription {
                TextEditor(text: $viewModel.editingDescription)
                    .font(AnvilFont.body)
                    .foregroundStyle(.secondary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(AnvilSpacing.sm)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                    )
                    .onChange(of: viewModel.editingDescription) { _, newValue in
                        viewModel.updateDescription(newValue)
                    }
            } else if ticket.description.isEmpty {
                Text("No description provided.")
                    .font(AnvilFont.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(ticket.description)
                    .font(AnvilFont.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Subtasks

    private func subtaskSection(_ ticket: Ticket) -> some View {
        let items = viewModel.subtasksFor(ticket.id)
        let progress = viewModel.subtaskProgress(ticket.id)

        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("Subtasks")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if progress.total > 0 {
                    Text("\(progress.completed)/\(progress.total)")
                        .font(AnvilFont.label)
                        .foregroundStyle(progress.completed == progress.total ? Color.green : Color.secondary)
                }

                Spacer()
            }

            // Progress bar
            if progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                    .progressViewStyle(.linear)
                    .tint(progress.completed == progress.total ? .green : Color.accentColor)
            }

            // Subtask items
            ForEach(items) { subtask in
                HStack(spacing: AnvilSpacing.sm) {
                    Button {
                        withAnimation(AnvilAnimation.standard) {
                            viewModel.toggleSubtask(ticketId: ticket.id, subtaskId: subtask.id)
                        }
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(subtask.isCompleted ? .green : .tertiary)
                    }
                    .buttonStyle(.plain)

                    Text(subtask.title)
                        .font(AnvilFont.body)
                        .foregroundStyle(subtask.isCompleted ? .tertiary : .primary)
                        .strikethrough(subtask.isCompleted)

                    Spacer()

                    Button {
                        viewModel.deleteSubtask(ticketId: ticket.id, subtaskId: subtask.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.5)
                }
                .padding(.vertical, AnvilSpacing.xxxs)
            }

            // Add subtask
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)

                TextField("Add subtask...", text: $viewModel.newSubtaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.body)
                    .onSubmit {
                        viewModel.addSubtask(to: ticket.id, title: viewModel.newSubtaskTitle)
                        viewModel.newSubtaskTitle = ""
                    }
            }
            .padding(.vertical, AnvilSpacing.xxxs)
        }
    }

    // MARK: - Labels

    private func labelsSection(_ ticket: Ticket) -> some View {
        Group {
            if !ticket.labels.isEmpty {
                VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    Text("Labels")
                        .font(.headline)
                        .foregroundStyle(.primary)

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
        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("Related")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showingLinkPopover.toggle()
                } label: {
                    Label("Link Ticket", systemImage: "link.badge.plus")
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showingLinkPopover) {
                    linkTicketPopover(ticket)
                }
            }

            if relations.isEmpty {
                Text("No linked tickets")
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                ForEach(relations) { relation in
                    relationRow(relation, currentId: ticket.id)
                }
            }
        }
    }

    // MARK: - Activity

    private func activitySection(_ ticket: Ticket) -> some View {
        let ticketComments = viewModel.commentsFor(ticket.id)

        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("Activity")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(ticketComments.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            ForEach(ticketComments) { comment in
                commentRow(comment, ticketId: ticket.id)
            }

            // New comment input
            HStack(alignment: .top, spacing: AnvilSpacing.sm) {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("Y")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    )

                VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                    TextField("Add a comment...", text: $viewModel.newCommentText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.body)
                        .lineLimit(1...5)

                    if !viewModel.newCommentText.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                viewModel.addComment(to: ticket.id, body: viewModel.newCommentText)
                                viewModel.newCommentText = ""
                            } label: {
                                Label("Comment", systemImage: "paperplane")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(AnvilSpacing.sm)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func commentRow(_ comment: TicketComment, ticketId: String) -> some View {
        HStack(alignment: .top, spacing: AnvilSpacing.sm) {
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(comment.author.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                )

            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                HStack {
                    Text(comment.author)
                        .font(AnvilFont.label)
                        .foregroundStyle(.primary)

                    Text(comment.createdAt, style: .relative)
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Button {
                        viewModel.deleteComment(ticketId: ticketId, commentId: comment.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.5)
                }

                Text(comment.body)
                    .font(AnvilFont.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
            }
            .padding(AnvilSpacing.sm)
        }
    }

    // MARK: - Link Ticket Popover

    private func linkTicketPopover(_ ticket: Ticket) -> some View {
        let candidates = viewModel.tickets.filter { $0.id != ticket.id }
        let filtered = linkTargetSearch.isEmpty
            ? candidates
            : candidates.filter {
                $0.id.localizedCaseInsensitiveContains(linkTargetSearch) ||
                $0.title.localizedCaseInsensitiveContains(linkTargetSearch)
            }

        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Link Ticket")
                .font(AnvilFont.subheading)
                .foregroundStyle(.primary)

            Picker("Relation Type", selection: $linkRelationType) {
                ForEach([TicketRelationType.blocks, .blockedBy, .parent, .child, .related, .duplicate], id: \.rawValue) { type in
                    Text(relationLabel(type, isSource: true)).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField("Search tickets...", text: $linkTargetSearch)
                .textFieldStyle(.roundedBorder)
                .font(AnvilFont.body)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered.prefix(10)) { candidate in
                        Button {
                            viewModel.addRelation(type: linkRelationType, sourceId: ticket.id, targetId: candidate.id)
                            linkTargetSearch = ""
                            showingLinkPopover = false
                        } label: {
                            HStack(spacing: AnvilSpacing.sm) {
                                Text(candidate.id)
                                    .font(AnvilFont.code)
                                    .foregroundStyle(Color.accentColor)
                                Text(candidate.title)
                                    .font(AnvilFont.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, AnvilSpacing.xs)
                            .padding(.horizontal, AnvilSpacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(AnvilSpacing.lg)
        .frame(width: 400)
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
                .foregroundStyle(.tertiary)

            if let other = otherTicket {
                Button {
                    viewModel.selectTicket(other.id)
                } label: {
                    Text(other.id)
                        .font(AnvilFont.code)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Text(other.title)
                    .font(AnvilFont.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(otherId)
                    .font(AnvilFont.code)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                viewModel.removeRelation(id: relation.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Remove link")
        }
        .padding(AnvilSpacing.sm)
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
        case "auth", "security":         AnvilColor.accentRed
        case "observability":            AnvilColor.accentBlue
        case "migration":                AnvilColor.accentAmber
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
        case .related:            Color.secondary
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
