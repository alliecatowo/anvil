import SwiftUI
import AnvilDomain

struct IntentSidebar: View {
    @ObservedObject var viewModel: IntentViewModel
    @EnvironmentObject private var appState: AppState
    @State private var quickAddText = ""
    @State private var isQuickAdding = false
    @FocusState private var isQuickAddFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            AnvilSidebarHeaderRow(
                title: "Tickets",
                icon: "checklist",
                count: viewModel.filteredTickets.count
            ) {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        isQuickAdding = true
                        isQuickAddFocused = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .accessibilityLabel("New Ticket")
            }

            AnvilSidebarSegmentedPicker(
                label: "Plan View Mode",
                items: IntentViewMode.allCases.map {
                    AnvilSidebarSegmentedPicker<IntentViewMode>.SidebarPickerItem(
                        id: $0,
                        title: $0.rawValue,
                        icon: nil
                    )
                },
                selection: $viewModel.viewMode
            )
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.bottom, AnvilSpacing.xs)
            .onChange(of: viewModel.viewMode) { _, _ in
                viewModel.closeTicketDetailInMainPane()
            }

            AnvilSidebarSearchBar(text: $viewModel.searchText, placeholder: "Search tickets...")
            Divider()

            List {
                if isQuickAdding {
                    quickAddField
                }

                AnvilSidebarSection(title: "Sprint", icon: "arrow.triangle.2.circlepath") {
                    Button {
                        viewModel.viewMode = .board
                        viewModel.closeTicketDetailInMainPane()
                    } label: {
                        cycleHeader
                    }
                    .buttonStyle(.plain)
                }

                AnvilSidebarSection(title: "Saved Filters", icon: "line.3.horizontal.decrease.circle") {
                    savedFilterRow(
                        title: "My Tickets",
                        icon: "person.fill",
                        count: viewModel.myTickets.count
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterMine()
                        }
                    }

                    savedFilterRow(
                        title: "Blocked",
                        icon: "exclamationmark.triangle",
                        count: viewModel.blockedTickets.count
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterBlocked()
                        }
                    }

                    savedFilterRow(
                        title: "Due Soon",
                        icon: "clock.badge.exclamationmark",
                        count: viewModel.dueSoonTickets.count
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterDueSoon()
                        }
                    }
                }

                ForEach(viewModel.groupedTickets, id: \.0) { group, tickets in
                    AnvilSidebarSection(title: group, icon: "line.3.horizontal.decrease.circle", count: tickets.count) {
                        ForEach(tickets) { ticket in
                            ticketRow(ticket)
                                .contextMenu {
                                    ticketContextMenu(ticket)
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Quick Add Field

    private var quickAddField: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "plus.circle")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.accentBlue)

            TextField("New ticket title...", text: $quickAddText)
                .textFieldStyle(.roundedBorder)
                .font(AnvilFont.sidebarItem)
                .focused($isQuickAddFocused)
                .onSubmit {
                    if !quickAddText.isEmpty {
                        withAnimation(AnvilAnimation.standard) {
                            viewModel.createTicket(title: quickAddText)
                        }
                        quickAddText = ""
                    }
                }
                .onKeyPress(.escape) {
                    quickAddText = ""
                    isQuickAdding = false
                    return .handled
                }

            if !quickAddText.isEmpty {
                Button {
                    quickAddText = ""
                    isQuickAdding = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel Quick Add")
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func ticketContextMenu(_ ticket: Ticket) -> some View {
        // Status submenu
        Menu("Status") {
            ForEach(viewModel.allStatuses, id: \.self) { status in
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.updateStatus(ticket.id, status: status)
                    }
                } label: {
                    HStack {
                        Image(systemName: IntentViewModel.statusIcon(status))
                        Text(status.capitalized)
                        if ticket.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        // Priority submenu
        Menu("Priority") {
            ForEach([TicketPriority.critical, .high, .medium, .low, .none], id: \.rawValue) { priority in
                Button {
                    viewModel.updatePriority(ticket.id, priority: priority)
                } label: {
                    HStack {
                        Text(IntentViewModel.priorityLabel(priority))
                        if ticket.priority == priority {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        // Assignee submenu
        Menu("Assignee") {
            Button {
                viewModel.updateAssignee(ticket.id, assignee: nil)
            } label: {
                HStack {
                    Text("Unassigned")
                    if ticket.assignee == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(viewModel.allAssignees, id: \.self) { name in
                Button {
                    viewModel.updateAssignee(ticket.id, assignee: name)
                } label: {
                    HStack {
                        Text(name)
                        if ticket.assignee == name {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            withAnimation(AnvilAnimation.standard) {
                viewModel.deleteTicket(ticket.id)
            }
        } label: {
            Label("Delete Ticket", systemImage: "trash")
        }
    }

    // MARK: - Cycle Header

    private var cycleHeader: some View {
        AnvilListItem(
            icon: "arrow.triangle.2.circlepath",
            title: viewModel.currentCycle.name,
            subtitle: "Current cycle",
            tag: viewModel.currentCycle.velocity.map { "\($0) pts" },
            tagColor: AnvilColor.accentBlue,
            isCompact: false
        )
    }

    // MARK: - Saved Filter Row

    private func savedFilterRow(title: String, icon: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AnvilListItem(
                icon: icon,
                title: title,
                subtitle: "Saved filter",
                tag: count > 0 ? "\(count)" : nil,
                tagColor: AnvilColor.accentBlue,
                isCompact: false
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) tickets")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Ticket Row

    private func ticketRow(_ ticket: Ticket) -> some View {
        Button {
            viewModel.selectTicket(ticket.id, openInMainPane: true)
        } label: {
            TicketRowContent(
                ticket: ticket,
                isSelected: viewModel.selectedTicketId == ticket.id,
                subtaskProgress: viewModel.subtaskProgress(ticket.id),
                dueDate: ticket.dueDate
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ticket.title), \(ticket.id)")
        .accessibilityAddTraits(.isButton)
    }

    private func applySavedFilter(_ action: () -> Void) {
        viewModel.viewMode = .list
        action()
        viewModel.closeTicketDetailInMainPane()
        if let first = viewModel.filteredTickets.first {
            viewModel.selectTicket(first.id)
        } else {
            viewModel.selectTicket(nil)
        }
    }
}

private struct TicketRowContent: View {
    let ticket: Ticket
    let isSelected: Bool
    let subtaskProgress: (completed: Int, total: Int)
    let dueDate: Date?

    @State private var isHovered = false
    @GestureState private var isPressed = false

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Priority color strip
            RoundedRectangle(cornerRadius: 2)
                .fill(IntentViewModel.priorityColor(ticket.priority))
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(ticket.title)
                        .font(AnvilFont.sidebarItem)
                        .lineLimit(1)

                    Spacer()

                    if let sp = ticket.storyPoints {
                        Text("\(sp)")
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                HStack(spacing: AnvilSpacing.xs) {
                    Text(ticket.id)
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)

                    if let assignee = ticket.assignee {
                        Circle()
                            .fill(AnvilColor.backgroundElevated)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Text(String(assignee.prefix(1)).uppercased())
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            )
                            .accessibilityHidden(true)
                        Text(assignee)
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .accessibilityLabel("Assigned to \(assignee)")
                    }

                    Spacer()

                    if subtaskProgress.total > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                                .font(.system(size: 9))
                            Text("\(subtaskProgress.completed)/\(subtaskProgress.total)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(subtaskProgress.completed == subtaskProgress.total ? AnvilColor.accentGreen : .secondary)
                    }

                    if let due = dueDate {
                        dueDateLabel(due)
                    }
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.14)
                : (isHovered ? Color.primary.opacity(0.06) : .clear)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, pressed, _ in pressed = true }
        )
        .onHover { isHovered = $0 }
    }

    // MARK: - Due Date

    private func dueDateLabel(_ date: Date) -> some View {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        let color: Color = days < 0
            ? AnvilColor.accentRed
            : days <= 2 ? AnvilColor.accentAmber : AnvilColor.textTertiary

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        return Text(formatter.localizedString(for: date, relativeTo: .now))
            .font(AnvilFont.label)
            .foregroundStyle(color)
    }
}
