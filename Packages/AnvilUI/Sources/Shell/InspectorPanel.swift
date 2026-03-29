import SwiftUI
import AnvilDomain
import AnvilGit

public struct InspectorPanel: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(headerTitle)
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    appState.toggleInspector()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Inspector")
                .accessibilityIdentifier("intent.inspector.close")
            }
            .padding(AnvilSpacing.md)

            Divider()

            // Content
            inspectorContent
        }
        .background(.regularMaterial)
    }

    private var headerTitle: String {
        if appState.currentSpace == .plan, let ticket = appState.intentViewModel.selectedTicket {
            return ticket.id
        }
        return "Inspector"
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if appState.currentSpace == .plan, appState.intentViewModel.selectedTicket != nil {
            TicketInspectorView(viewModel: appState.intentViewModel)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                    InspectorSection(title: "Details") {
                        Text("Select an item to inspect")
                            .font(AnvilFont.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(AnvilSpacing.md)
            }
        }
    }
}

// MARK: - Ticket Inspector (shown inside the Inspector panel)

struct TicketInspectorView: View {
    @ObservedObject var viewModel: IntentViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    @State private var branchCreated: String?
    @State private var isDispatching = false
    @State private var isEditingDescription = false

    var body: some View {
        if let ticket = viewModel.selectedTicket {
            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                    // Title
                    TextField("Title", text: $viewModel.editingTitle, onCommit: {
                        viewModel.updateTitle(viewModel.editingTitle)
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .accessibilityLabel("Ticket title")

                    // Actions
                    actionsSection(ticket)

                    Divider()

                    // Metadata
                    metadataSection(ticket)

                    Divider()

                    // Description
                    descriptionSection(ticket)

                    Divider()

                    // Subtasks
                    subtaskSection(ticket)

                    // Labels
                    if !ticket.labels.isEmpty {
                        Divider()
                        labelsSection(ticket)
                    }
                }
                .padding(AnvilSpacing.md)
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionsSection(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
        HStack(spacing: AnvilSpacing.sm) {
            AnvilButton(
                isDispatching ? "Starting..." : "Start Work",
                icon: "bolt.fill",
                style: .primary
            ) {
                startWork(ticket)
            }
            .disabled(isDispatching)

            if branchCreated == nil {
                AnvilButton("Branch", icon: "arrow.triangle.branch", style: .ghost) {
                    createBranchForTicket(ticket)
                }
            }

            AnvilButton("Open", icon: "arrow.right.square", style: .ghost) {
                viewModel.openSelectedTicketInMainPane()
            }
            .accessibilityIdentifier("intent.inspector.open-main-pane")

            Spacer()

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
        }

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
        }
    }

    // MARK: - Metadata

    private func metadataSection(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            InspectorSection(title: "Details") {
                VStack(spacing: AnvilSpacing.sm) {
                    inspectorRow("Status") {
                        Picker("Status", selection: Binding(
                            get: { ticket.status },
                            set: { viewModel.updateStatus(ticket.id, status: $0) }
                        )) {
                            ForEach(viewModel.allStatuses, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Ticket status")
                    }

                    inspectorRow("Priority") {
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

                    inspectorRow("Assignee") {
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

                    inspectorRow("Due Date") {
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

                    if let sp = ticket.storyPoints {
                        inspectorRow("Points") {
                            Text("\(sp)")
                                .font(AnvilFont.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func inspectorRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            content()
        }
    }

    // MARK: - Description

    private func descriptionSection(_ ticket: Ticket) -> some View {
        InspectorSection(title: "Description") {
            if isEditingDescription {
                TextEditor(text: $viewModel.editingDescription)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(AnvilSpacing.xs)
                    .background(AnvilColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onChange(of: viewModel.editingDescription) { _, newValue in
                        viewModel.updateDescription(newValue)
                    }
            } else if ticket.description.isEmpty {
                Text("No description.")
                    .font(AnvilFont.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(ticket.description)
                    .font(AnvilFont.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
            }

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
    }

    // MARK: - Subtasks

    private func subtaskSection(_ ticket: Ticket) -> some View {
        let items = viewModel.subtasksFor(ticket.id)
        let progress = viewModel.subtaskProgress(ticket.id)

        return InspectorSection(title: "Subtasks") {
            if progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                    .progressViewStyle(.linear)
                    .tint(progress.completed == progress.total ? AnvilColor.accentGreen : AnvilColor.accentBlue)

                Text("\(progress.completed)/\(progress.total)")
                    .font(AnvilFont.label)
                    .foregroundStyle(.secondary)
            }

            ForEach(items) { subtask in
                HStack(spacing: AnvilSpacing.xs) {
                    Button {
                        withAnimation(AnvilAnimation.standard) {
                            viewModel.toggleSubtask(ticketId: ticket.id, subtaskId: subtask.id)
                        }
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundStyle(subtask.isCompleted ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Text(subtask.title)
                        .font(AnvilFont.body)
                        .foregroundStyle(subtask.isCompleted ? AnvilColor.textTertiary : AnvilColor.textPrimary)
                        .strikethrough(subtask.isCompleted)
                        .lineLimit(2)

                    Spacer()
                }
            }

            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(AnvilColor.textTertiary)

                TextField("Add subtask...", text: $viewModel.newSubtaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.body)
                    .onSubmit {
                        viewModel.addSubtask(to: ticket.id, title: viewModel.newSubtaskTitle)
                        viewModel.newSubtaskTitle = ""
                    }
            }
        }
    }

    // MARK: - Labels

    private func labelsSection(_ ticket: Ticket) -> some View {
        InspectorSection(title: "Labels") {
            FlowLayout(spacing: AnvilSpacing.xs) {
                ForEach(ticket.labels, id: \.self) { label in
                    AnvilBadge(text: label, color: AnvilColor.textTertiary)
                }
            }
        }
    }

    // MARK: - Branch / Start Work

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

    private func startWork(_ ticket: Ticket) {
        isDispatching = true

        let branchName = generateBranchName(from: ticket)

        Task {
            if branchCreated == nil, let adapter = container.getOrCreateGitAdapter() {
                await appState.createBranch(branchName, using: adapter)
                branchCreated = branchName
            }

            viewModel.moveTicket(ticket.id, toStatus: "in progress")

            appState.agentViewModel.dispatchFromTicket(
                ticketId: ticket.id,
                title: ticket.title,
                description: ticket.description
            )

            appState.switchSpace(.build)

            isDispatching = false
        }
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            content
        }
    }
}
