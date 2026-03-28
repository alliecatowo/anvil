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

                    Divider().overlay(AnvilColor.borderSubtle)

                    // Content
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxl) {
                        headerSection(ticket)
                        metadataEditors(ticket)
                        descriptionSection(ticket)
                        subtaskSection(ticket)
                        labelsSection(ticket)
                        relatedSection(ticket)
                        commentsSection(ticket)
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

            if let created = branchCreated {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentGreen)
                    Text(created)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentGreen)
                }
            }

            AnvilButton(
                isDispatching ? "Starting..." : "Start Work",
                icon: "bolt.fill",
                style: .primary
            ) {
                startWork(ticket)
            }
            .disabled(isDispatching)

            if branchCreated == nil {
                AnvilButton("Branch Only", icon: "arrow.triangle.branch", style: .ghost) {
                    createBranchForTicket(ticket)
                }
            }

            Button(role: .destructive) {
                withAnimation(AnvilAnimation.standard) {
                    viewModel.deleteTicket(ticket.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(AnvilColor.accentRed.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete ticket")

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
            appState.switchMode(.agent)

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
            .textFieldStyle(.plain)
            .font(AnvilFont.heading)
            .foregroundStyle(AnvilColor.textPrimary)

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

    // MARK: - Metadata Editors

    private func metadataEditors(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("PROPERTIES")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)

            HStack(spacing: AnvilSpacing.xl) {
                // Status picker
                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("Status")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Picker("", selection: Binding(
                        get: { ticket.status },
                        set: { viewModel.updateStatus(ticket.id, status: $0) }
                    )) {
                        ForEach(viewModel.allStatuses, id: \.self) { status in
                            Text(status.capitalized).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }

                // Priority picker
                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("Priority")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Picker("", selection: Binding(
                        get: { ticket.priority },
                        set: { viewModel.updatePriority(ticket.id, priority: $0) }
                    )) {
                        ForEach([TicketPriority.critical, .high, .medium, .low, .none], id: \.rawValue) { p in
                            Text(IntentViewModel.priorityLabel(p)).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                // Assignee picker
                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("Assignee")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Picker("", selection: Binding(
                        get: { ticket.assignee ?? "" },
                        set: { viewModel.updateAssignee(ticket.id, assignee: $0.isEmpty ? nil : $0) }
                    )) {
                        Text("Unassigned").tag("")
                        ForEach(viewModel.allAssignees, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }

                // Due date picker
                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("Due Date")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    HStack(spacing: AnvilSpacing.xs) {
                        DatePicker("", selection: Binding(
                            get: { ticket.dueDate ?? Date.now },
                            set: { viewModel.updateDueDate(ticket.id, dueDate: $0) }
                        ), displayedComponents: .date)
                        .labelsHidden()

                        if ticket.dueDate != nil {
                            Button {
                                viewModel.updateDueDate(ticket.id, dueDate: nil)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AnvilColor.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear due date")
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(AnvilSpacing.md)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
    }

    // MARK: - Description

    private func descriptionSection(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("DESCRIPTION")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.3)

                Spacer()

                Button {
                    isEditingDescription.toggle()
                    if isEditingDescription {
                        viewModel.editingDescription = ticket.description
                    }
                } label: {
                    Text(isEditingDescription ? "Done" : "Edit")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentBlue)
                }
                .buttonStyle(.plain)
            }

            if isEditingDescription {
                TextEditor(text: $viewModel.editingDescription)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(AnvilSpacing.sm)
                    .background(AnvilColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AnvilColor.accentBlue.opacity(0.4), lineWidth: 1)
                    )
                    .onChange(of: viewModel.editingDescription) { _, newValue in
                        viewModel.updateDescription(newValue)
                    }
            } else if ticket.description.isEmpty {
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

    // MARK: - Subtasks

    private func subtaskSection(_ ticket: Ticket) -> some View {
        let items = viewModel.subtasksFor(ticket.id)
        let progress = viewModel.subtaskProgress(ticket.id)

        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("SUBTASKS")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.3)

                if progress.total > 0 {
                    Text("\(progress.completed)/\(progress.total)")
                        .font(AnvilFont.label)
                        .foregroundStyle(progress.completed == progress.total ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                }

                Spacer()
            }

            // Progress bar
            if progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                    .progressViewStyle(.linear)
                    .tint(progress.completed == progress.total ? AnvilColor.accentGreen : AnvilColor.accentBlue)
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
                            .foregroundStyle(subtask.isCompleted ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Text(subtask.title)
                        .font(AnvilFont.body)
                        .foregroundStyle(subtask.isCompleted ? AnvilColor.textTertiary : AnvilColor.textPrimary)
                        .strikethrough(subtask.isCompleted)

                    Spacer()

                    Button {
                        viewModel.deleteSubtask(ticketId: ticket.id, subtaskId: subtask.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AnvilColor.textTertiary)
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
                    .foregroundStyle(AnvilColor.textTertiary)

                TextField("Add subtask...", text: $viewModel.newSubtaskTitle)
                    .textFieldStyle(.plain)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
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
        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("RELATED")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.3)

                Spacer()

                AnvilButton("Link Ticket", icon: "link.badge.plus", style: .ghost) {
                    showingLinkPopover.toggle()
                }
                .popover(isPresented: $showingLinkPopover) {
                    linkTicketPopover(ticket)
                }
            }

            if relations.isEmpty {
                Text("No linked tickets")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .italic()
            } else {
                ForEach(relations) { relation in
                    relationRow(relation, currentId: ticket.id)
                }
            }
        }
    }

    // MARK: - Comments

    private func commentsSection(_ ticket: Ticket) -> some View {
        let ticketComments = viewModel.commentsFor(ticket.id)

        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("COMMENTS")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.3)

                Text("\(ticketComments.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(AnvilColor.backgroundElevated)
                    .clipShape(Capsule())
            }

            ForEach(ticketComments) { comment in
                commentRow(comment, ticketId: ticket.id)
            }

            // New comment input
            HStack(alignment: .top, spacing: AnvilSpacing.sm) {
                Circle()
                    .fill(AnvilColor.accentBlue.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("Y")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AnvilColor.accentBlue)
                    )

                VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                    TextField("Add a comment...", text: $viewModel.newCommentText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1...5)

                    if !viewModel.newCommentText.isEmpty {
                        HStack {
                            Spacer()
                            AnvilButton("Comment", icon: "paperplane", style: .primary) {
                                viewModel.addComment(to: ticket.id, body: viewModel.newCommentText)
                                viewModel.newCommentText = ""
                            }
                        }
                    }
                }
                .padding(AnvilSpacing.sm)
                .background(AnvilColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    private func commentRow(_ comment: TicketComment, ticketId: String) -> some View {
        HStack(alignment: .top, spacing: AnvilSpacing.sm) {
            Circle()
                .fill(AnvilColor.backgroundElevated)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(comment.author.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AnvilColor.textSecondary)
                )

            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                HStack {
                    Text(comment.author)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textPrimary)

                    Text(comment.createdAt, style: .relative)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Spacer()

                    Button {
                        viewModel.deleteComment(ticketId: ticketId, commentId: comment.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.5)
                }

                Text(comment.body)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
            }
            .padding(AnvilSpacing.sm)
            .background(AnvilColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
                .foregroundStyle(AnvilColor.textPrimary)

            HStack(spacing: AnvilSpacing.xs) {
                ForEach([TicketRelationType.blocks, .blockedBy, .parent, .child, .related, .duplicate], id: \.rawValue) { type in
                    Button {
                        linkRelationType = type
                    } label: {
                        Text(relationLabel(type, isSource: true))
                            .font(AnvilFont.label)
                            .foregroundStyle(linkRelationType == type ? AnvilColor.textPrimary : AnvilColor.textTertiary)
                            .padding(.horizontal, AnvilSpacing.sm)
                            .padding(.vertical, AnvilSpacing.xxs)
                            .background(linkRelationType == type ? relationColor(type).opacity(0.2) : AnvilColor.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Search tickets...", text: $linkTargetSearch)
                .textFieldStyle(.plain)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
                .padding(AnvilSpacing.sm)
                .background(AnvilColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

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
                                    .foregroundStyle(AnvilColor.accentBlue)
                                Text(candidate.title)
                                    .font(AnvilFont.body)
                                    .foregroundStyle(AnvilColor.textSecondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, AnvilSpacing.xs)
                            .padding(.horizontal, AnvilSpacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(AnvilColor.borderSubtle)
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
                .foregroundStyle(AnvilColor.textTertiary)

            if let other = otherTicket {
                Button {
                    viewModel.selectTicket(other.id)
                } label: {
                    Text(other.id)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentBlue)
                }
                .buttonStyle(.plain)

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

            Button {
                viewModel.removeRelation(id: relation.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Remove link")
        }
        .padding(AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
