import SwiftUI
import AnvilDomain

struct IntentSidebar: View {
    @ObservedObject var viewModel: IntentViewModel
    @State private var quickAddText = ""
    @State private var isQuickAdding = false
    @FocusState private var isQuickAddFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search
            AnvilSearchField(text: $viewModel.searchText, placeholder: "Search tickets...")

            Divider().overlay(AnvilColor.borderSubtle)

            // View mode picker + New Ticket
            HStack(spacing: AnvilSpacing.sm) {
                Picker("View", selection: $viewModel.viewMode) {
                    ForEach(IntentViewMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.viewMode) { _, _ in
                    viewModel.selectTicket(nil)
                }

                Spacer()

                Button {
                    withAnimation(AnvilAnimation.standard) {
                        isQuickAdding = true
                        isQuickAddFocused = true
                    }
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("New")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, AnvilSpacing.xxs)
                    .background(AnvilColor.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSidebar.opacity(0.45))

            Divider().overlay(AnvilColor.borderSubtle)

            // Inline quick-add
            if isQuickAdding {
                quickAddField

                Divider().overlay(AnvilColor.borderSubtle)
            }

            // Cycle info
            cycleHeader

            Divider().overlay(AnvilColor.borderSubtle)

            // Ticket list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(viewModel.groupedTickets, id: \.0) { group, tickets in
                        Section {
                            ForEach(tickets) { ticket in
                                ticketRow(ticket)
                                    .contextMenu {
                                        ticketContextMenu(ticket)
                                    }
                            }
                        } header: {
                            sectionHeader(group, count: tickets.count)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick Add Field

    private var quickAddField: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "plus.circle")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.accentBlue)

            TextField("New ticket title...", text: $quickAddText)
                .textFieldStyle(.plain)
                .font(AnvilFont.sidebarItem)
                .foregroundStyle(AnvilColor.textPrimary)
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
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(.thinMaterial)
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
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentBlue)

            Text(viewModel.currentCycle.name)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textPrimary)

            Spacer()

            if let velocity = viewModel.currentCycle.velocity {
                Text("\(velocity) pts")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundSidebar.opacity(0.35))
    }

    // MARK: - Ticket Row

    private func ticketRow(_ ticket: Ticket) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Priority color strip
            RoundedRectangle(cornerRadius: 2)
                .fill(IntentViewModel.priorityColor(ticket.priority))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(ticket.title)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let sp = ticket.storyPoints {
                        Text("\(sp)")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AnvilColor.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                HStack(spacing: AnvilSpacing.xs) {
                    Text(ticket.id)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    if let assignee = ticket.assignee {
                        Circle()
                            .fill(AnvilColor.backgroundElevated)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Text(String(assignee.prefix(1)).uppercased())
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(AnvilColor.textSecondary)
                            )
                        Text(assignee)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Subtask progress
                    let progress = viewModel.subtaskProgress(ticket.id)
                    if progress.total > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                                .font(.system(size: 9))
                            Text("\(progress.completed)/\(progress.total)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(progress.completed == progress.total ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                    }

                    if let due = ticket.dueDate {
                        dueDateLabel(due)
                    }
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: AnvilSpacing.richListItemHeight)
        .background(
            viewModel.selectedTicketId == ticket.id
                ? AnvilColor.selectionBackground
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectTicket(ticket.id) }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .tracking(0.3)

            Spacer()

            Text("\(count)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary)
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
