import SwiftUI
import AnvilDomain

struct IntentSidebar: View {
    @ObservedObject var viewModel: IntentViewModel
    @EnvironmentObject private var appState: AppState
    @State private var quickAddText = ""
    @State private var isQuickAdding = false
    @State private var expandedGroups: Set<String> = []
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
                .accessibilityIdentifier("intent.sidebar.new-ticket")
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

                // MARK: - Pinned Section

                if !viewModel.sidebarPins.isEmpty {
                    AnvilSidebarSection(title: "Pinned", icon: "pin.fill") {
                        ForEach(viewModel.pinnedFilters, id: \.rawValue) { filter in
                            pinnedFilterRow(filter)
                        }

                        ForEach(viewModel.pinnedTickets) { ticket in
                            pinnedTicketRow(ticket)
                        }
                    }
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
                        count: viewModel.myTickets.count,
                        filter: .myTickets
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterMine()
                        }
                    }

                    savedFilterRow(
                        title: "Blocked",
                        icon: "exclamationmark.triangle",
                        count: viewModel.blockedTickets.count,
                        filter: .blocked
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterBlocked()
                        }
                    }

                    savedFilterRow(
                        title: "Due Soon",
                        icon: "clock.badge.exclamationmark",
                        count: viewModel.dueSoonTickets.count,
                        filter: .dueSoon
                    ) {
                        applySavedFilter {
                            viewModel.applyFilterDueSoon()
                        }
                    }
                }

                ForEach(viewModel.groupedTickets, id: \.0) { group, tickets in
                    AnvilSidebarDisclosureSection(
                        title: group,
                        icon: "line.3.horizontal.decrease.circle",
                        count: tickets.count,
                        isExpanded: expandedBinding(for: group)
                    ) {
                        ForEach(tickets) { ticket in
                            ticketRow(ticket)
                                .contextMenu {
                                    ticketContextMenu(ticket)
                                }
                                .accessibilityIdentifier("intent.sidebar.ticket-row.\(ticket.id)")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onAppear {
                // Expand the first group by default
                if let firstGroup = viewModel.groupedTickets.first?.0 {
                    expandedGroups.insert(firstGroup)
                }
            }
        }
    }

    // MARK: - Expanded Binding

    private func expandedBinding(for group: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { expandedGroups.contains(group) },
            set: { isExpanded in
                if isExpanded {
                    expandedGroups.insert(group)
                } else {
                    expandedGroups.remove(group)
                }
            }
        )
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
                .accessibilityIdentifier("intent.sidebar.quick-add-title")
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
                .accessibilityIdentifier("intent.sidebar.quick-add-cancel")
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

    // MARK: - Pinned Rows

    private func pinnedFilterRow(_ filter: PlanSidebarFilter) -> some View {
        Button {
            applySavedFilter {
                switch filter {
                case .myTickets: viewModel.applyFilterMine()
                case .blocked: viewModel.applyFilterBlocked()
                case .dueSoon: viewModel.applyFilterDueSoon()
                }
            }
        } label: {
            AnvilListItem(
                icon: filter.icon,
                title: filter.title,
                isCompact: true
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                viewModel.togglePin(filter: filter)
            } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        }
    }

    private func pinnedTicketRow(_ ticket: Ticket) -> some View {
        Button {
            viewModel.selectTicket(ticket.id, openInMainPane: true)
        } label: {
            AnvilListItem(
                icon: IntentViewModel.statusIcon(ticket.status),
                title: ticket.title,
                isCompact: true
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                viewModel.togglePin(ticketId: ticket.id)
            } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        }
    }

    // MARK: - Saved Filter Row

    private func savedFilterRow(title: String, icon: String, count: Int, filter: PlanSidebarFilter, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                AnvilListItem(
                    icon: icon,
                    title: title,
                    subtitle: nil,
                    tag: count > 0 ? "\(count)" : nil,
                    tagColor: AnvilColor.accentBlue,
                    isCompact: false
                )

                PinButton(
                    isPinned: viewModel.isPinned(filter: filter),
                    action: { viewModel.togglePin(filter: filter) }
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) tickets")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Ticket Row

    private func ticketRow(_ ticket: Ticket) -> some View {
        let selected = viewModel.selectedTicketId == ticket.id
        return Button {
            viewModel.selectTicket(ticket.id, openInMainPane: true)
        } label: {
            TicketRowContent(
                ticket: ticket,
                isSelected: selected
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            selected ? Color.accentColor.opacity(0.14) : Color.clear
        )
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

// MARK: - Pin Button

private struct PinButton: View {
    let isPinned: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 11))
                .foregroundStyle(isPinned ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .opacity(isPinned || isHovered ? 1.0 : 0.0)
        .onHover { isHovered = $0 }
        .accessibilityLabel(isPinned ? "Unpin" : "Pin")
    }
}

// MARK: - Ticket Row Content

private struct TicketRowContent: View {
    let ticket: Ticket
    let isSelected: Bool

    @State private var isHovered = false

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

                    Spacer(minLength: AnvilSpacing.xxs)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .onHover { isHovered = $0 }
    }
}
