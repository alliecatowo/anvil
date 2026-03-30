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
        if appState.currentSpace == .build {
            return buildHeaderTitle
        }
        return "Inspector"
    }

    private var buildHeaderTitle: String {
        switch appState.buildActiveSource {
        case .sessions:
            return appState.agentViewModel.selectedSession?.displayName ?? "Build Session"
        case .files:
            if appState.isSourceControlVisible {
                return "Source Control"
            }
            if appState.splitEditorState.activePane.viewModel.isSymbolOutlineVisible {
                return "Outline"
            }
            return appState.editorViewModel.selectedFile?.name ?? "File Details"
        case .data:
            return appState.databaseViewModel.connectionTitle
        case .tests:
            return "Tests"
        case .problems:
            return "Problems"
        case .output:
            return "Output"
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if appState.currentSpace == .plan, appState.intentViewModel.selectedTicket != nil {
            TicketInspectorSummaryView(viewModel: appState.intentViewModel)
        } else if appState.currentSpace == .build {
            buildInspectorContent
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

    @ViewBuilder
    private var buildInspectorContent: some View {
        switch appState.buildActiveSource {
        case .sessions:
            BuildSessionInspectorView(viewModel: appState.agentViewModel)
        case .files:
            if appState.isSourceControlVisible {
                SourceControlPanel()
            } else if appState.splitEditorState.activePane.viewModel.isSymbolOutlineVisible {
                SymbolOutline(viewModel: appState.splitEditorState.activePane.viewModel)
            } else {
                EditorInspectorSummaryView(viewModel: appState.editorViewModel)
            }
        case .data:
            DatabaseInspectorSummaryView(viewModel: appState.databaseViewModel)
        case .tests:
            TestingInspectorSummaryView(viewModel: appState.testingViewModel)
        case .problems, .output:
            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                    InspectorSection(title: "Details") {
                        Text("No details available.")
                            .font(AnvilFont.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(AnvilSpacing.md)
            }
        }
    }
}

// MARK: - Ticket Inspector Summary (shown when detail is open in the main canvas)

struct TicketInspectorSummaryView: View {
    @ObservedObject var viewModel: IntentViewModel

    var body: some View {
        if let ticket = viewModel.selectedTicket {
            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                    InspectorSection(title: "Selected Ticket") {
                        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                            Text(ticket.title)
                                .font(AnvilFont.subheading)
                                .foregroundStyle(AnvilColor.textPrimary)
                                .lineLimit(2)

                            Text(ticket.id)
                                .font(AnvilFont.code)
                                .foregroundStyle(AnvilColor.textTertiary)

                            HStack(spacing: AnvilSpacing.sm) {
                                AnvilBadge(text: ticket.status.capitalized, color: IntentViewModel.statusColor(ticket.status))
                                Text(IntentViewModel.priorityLabel(ticket.priority))
                                    .font(AnvilFont.label)
                                    .foregroundStyle(IntentViewModel.priorityColor(ticket.priority))
                            }

                            if let assignee = ticket.assignee {
                                Text("Assigned to \(assignee)")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.textSecondary)
                            }
                        }
                    }

                    InspectorSection(title: "Canvas") {
                        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                            Text("This ticket is open in the main canvas.")
                                .font(AnvilFont.body)
                                .foregroundStyle(AnvilColor.textSecondary)

                            AnvilButton("Back to List", icon: "chevron.left", style: .ghost) {
                                viewModel.closeTicketDetailInMainPane()
                            }
                        }
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
                style: .cta
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

struct BuildSessionInspectorView: View {
    @ObservedObject var viewModel: AgentViewModel

    var body: some View {
        if let session = viewModel.selectedSession {
            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                    InspectorSection(title: "Session") {
                        HStack(spacing: AnvilSpacing.xs) {
                            AnvilBadge(text: session.status.rawValue.capitalized, color: statusColor(for: session.status))
                            if session.isBackground {
                                AnvilBadge(text: "Background", color: AnvilColor.accentPurple)
                            }
                        }

                        metadataRow("Model", session.model)
                        metadataRow("Provider", providerName(for: session.providerId))

                        if let ticketId = session.workItemId {
                            metadataRow("Ticket", ticketId)
                        }

                        if let worktreePath = session.worktreePath {
                            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                                Text("Worktree")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(.secondary)
                                Text(worktreePath)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(AnvilColor.textSecondary)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                            }
                        }
                    }

                    InspectorSection(title: "Usage") {
                        metadataRow("Input", session.tokenUsage.inputTokens.formatted())
                        metadataRow("Output", session.tokenUsage.outputTokens.formatted())
                        metadataRow("Total", session.tokenUsage.totalTokens.formatted())
                        metadataRow("Cost", formatCost(session.cost))

                        if let budget = session.costBudget, budget > 0 {
                            metadataRow("Budget", formatCost(budget))
                            ProgressView(value: min(session.budgetUsage ?? 0, 1.0))
                                .tint((session.budgetUsage ?? 0) >= 1.0 ? AnvilColor.accentRed : AnvilColor.accentBlue)
                            Text("\(Int((session.budgetUsage ?? 0) * 100))% of budget")
                                .font(AnvilFont.label)
                                .foregroundStyle(.secondary)
                        }
                    }

                    InspectorSection(title: "Activity") {
                        let userCount = session.messages.filter { $0.role == .user }.count
                        let assistantCount = session.messages.filter { $0.role == .assistant }.count
                        metadataRow("Messages", session.messages.count.formatted())
                        metadataRow("User", userCount.formatted())
                        metadataRow("Assistant", assistantCount.formatted())
                        metadataRow("Started", session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        metadataRow("Updated", session.lastActivityAt.formatted(date: .omitted, time: .shortened))

                        if let latest = session.messages.last {
                            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                                Text("Latest")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(.secondary)
                                Text(latest.content)
                                    .font(AnvilFont.body)
                                    .foregroundStyle(AnvilColor.textSecondary)
                                    .lineLimit(6)
                            }
                        }
                    }

                    if let plan = session.plan {
                        InspectorSection(title: "Plan") {
                            let completed = plan.steps.filter { $0.status == .completed || $0.status == .skipped }.count
                            metadataRow("Status", plan.status.rawValue.capitalized)
                            metadataRow("Steps", "\(completed)/\(plan.steps.count)")
                            ProgressView(value: plan.progress)
                                .tint(AnvilColor.accentBlue)
                            if let active = plan.activeStep {
                                Text("Active: \(active.title)")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.textSecondary)
                            }
                        }
                    }

                    InspectorSection(title: "Context") {
                        if viewModel.contextAttachments.isEmpty {
                            Text("No active context attachments.")
                                .font(AnvilFont.body)
                                .foregroundStyle(.tertiary)
                        } else {
                            ForEach(viewModel.contextAttachments.prefix(8), id: \.id) { attachment in
                                HStack(spacing: AnvilSpacing.xs) {
                                    Image(systemName: attachment.icon)
                                        .font(.system(size: 11))
                                        .foregroundStyle(attachment.color)
                                    Text(attachment.label)
                                        .font(AnvilFont.body)
                                        .foregroundStyle(AnvilColor.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                        }

                        if !viewModel.queuedMessages.isEmpty {
                            metadataRow("Queued", viewModel.queuedMessages.count.formatted())
                        }
                    }

                    InspectorSection(title: "Actions") {
                        HStack(spacing: AnvilSpacing.sm) {
                            Button("Focus Session") {
                                viewModel.showConversation()
                            }
                            .buttonStyle(.bordered)

                            Button("Dashboard") {
                                viewModel.showDashboard()
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: AnvilSpacing.sm) {
                            Button("Copy Markdown") {
                                viewModel.exportSessionToClipboard(session.id)
                            }
                            .buttonStyle(.bordered)

                            Button("Export JSON…") {
                                viewModel.exportSessionToFile(session.id, format: .json)
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("New Session") {
                            viewModel.startNewSession(prompt: "", model: viewModel.selectedModelId)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(AnvilSpacing.md)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                    InspectorSection(title: "Session") {
                        Text("Select or create a Build session to inspect details.")
                            .font(AnvilFont.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(AnvilSpacing.md)
            }
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatCost(_ cost: Decimal) -> String {
        "$\(NSDecimalNumber(decimal: cost).doubleValue.formatted(.number.precision(.fractionLength(2))))"
    }

    private func statusColor(for status: AgentSessionStatus) -> Color {
        switch status {
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentBlue
        case .failed: AnvilColor.accentRed
        case .paused: AnvilColor.accentAmber
        case .idle, .cancelled: AnvilColor.textTertiary
        }
    }

    private func providerName(for providerId: String) -> String {
        switch providerId {
        case "claude-cli": "Claude CLI"
        case "codex-acp": "Codex ACP"
        case "zed-acp": "Zed ACP"
        default: providerId
        }
    }
}

struct EditorInspectorSummaryView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                if let file = viewModel.selectedFile {
                    InspectorSection(title: "File") {
                        metadataRow("Name", file.name)
                        metadataRow("Language", file.language.uppercased())
                        metadataRow("Path", file.relativePath)
                        metadataRow("Lines", file.content.components(separatedBy: "\n").count.formatted())
                        metadataRow("Open Tabs", viewModel.openFiles.count.formatted())
                        metadataRow("Read-only", viewModel.isFileReadOnly(file.id) ? "Yes" : "No")
                    }

                    InspectorSection(title: "Cursor") {
                        metadataRow("Line", viewModel.cursorLine.formatted())
                        metadataRow("Column", viewModel.cursorColumn.formatted())
                        metadataRow("Symbols", viewModel.symbols.count.formatted())
                    }

                    InspectorSection(title: "Editor") {
                        metadataRow("Word Wrap", viewModel.isWordWrapEnabled ? "On" : "Off")
                        metadataRow("Minimap", viewModel.isMinimapVisible ? "On" : "Off")
                        metadataRow("Git Gutter", viewModel.showGitGutter ? "On" : "Off")
                        metadataRow("Bracket Match", viewModel.showBracketMatching ? "On" : "Off")
                        metadataRow("Indent Guides", viewModel.showIndentGuides ? "On" : "Off")
                        metadataRow("Code Folding", viewModel.codeFoldingEnabled ? "On" : "Off")
                    }

                    InspectorSection(title: "Diagnostics") {
                        let counts = viewModel.diagnosticCount(forPath: file.path)
                        metadataRow("Errors", counts.errors.formatted())
                        metadataRow("Warnings", counts.warnings.formatted())
                    }
                } else {
                    InspectorSection(title: "File") {
                        Text("Open a file in Build > Files to inspect it.")
                            .font(AnvilFont.body)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(AnvilSpacing.md)
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct TerminalInspectorSummaryView: View {
    @ObservedObject var viewModel: TerminalViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                InspectorSection(title: "Terminal") {
                    metadataRow("Sessions", viewModel.sessions.count.formatted())
                    if let session = viewModel.selectedSession {
                        metadataRow("Title", session.title)
                        metadataRow("Status", session.isRunning ? "Running" : "Exited")
                        if let workingDirectory = session.workingDirectory {
                            metadataRow("Directory", workingDirectory)
                        }
                    } else {
                        Text("No active terminal session.")
                            .font(AnvilFont.body)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(AnvilSpacing.md)
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

struct DatabaseInspectorSummaryView: View {
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                InspectorSection(title: "Database") {
                    metadataRow("Connected", viewModel.isConnected ? "Yes" : "No")
                    metadataRow("Provider", viewModel.selectedProvider?.title ?? "None")
                    metadataRow("Connection", viewModel.connectionTitle)
                    if !viewModel.connectionSubtitle.isEmpty {
                        metadataRow("Location", viewModel.connectionSubtitle)
                    }
                }

                if viewModel.isConnected {
                    InspectorSection(title: "Schema") {
                        metadataRow("Tables", viewModel.tables.count.formatted())
                        metadataRow("Views", viewModel.views.count.formatted())
                        if let selected = viewModel.selectedObject {
                            metadataRow("Selected", selected.name)
                        }
                    }

                    InspectorSection(title: "Query") {
                        metadataRow("History", viewModel.queryHistory.count.formatted())
                        metadataRow("Rows", viewModel.totalRowCount.formatted())
                        metadataRow("Page", "\(viewModel.currentPage + 1)/\(viewModel.totalPages)")
                    }
                }
            }
            .padding(AnvilSpacing.md)
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

struct TestingInspectorSummaryView: View {
    @ObservedObject var viewModel: TestingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                InspectorSection(title: "Tests") {
                    metadataRow("Running", viewModel.isRunning ? "Yes" : "No")
                    metadataRow("Suites", viewModel.suites.count.formatted())
                    metadataRow("Total", viewModel.totalTests.formatted())
                    metadataRow("Passed", viewModel.passedTests.formatted())
                    metadataRow("Failed", viewModel.failedTests.formatted())
                    metadataRow("Filter", viewModel.showFilter.rawValue)
                }
            }
            .padding(AnvilSpacing.md)
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.trailing)
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
