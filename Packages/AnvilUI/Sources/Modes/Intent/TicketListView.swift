import SwiftUI
import AnvilDomain

struct TicketListView: View {
    @ObservedObject var viewModel: IntentViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider().overlay(AnvilColor.borderSubtle)

            if viewModel.filteredTickets.isEmpty {
                emptyState
            } else {
                ticketTable
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: AnvilSpacing.md) {
            HStack(spacing: AnvilSpacing.xxs) {
                Text("Group:")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                Picker("", selection: $viewModel.grouping) {
                    ForEach(TicketGrouping.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            HStack(spacing: AnvilSpacing.xxs) {
                Text("Sort:")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                Picker("", selection: $viewModel.sortField) {
                    ForEach(TicketSortField.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }

            Spacer()

            filterIndicator

            Text("\(viewModel.filteredTickets.count) tickets")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundToolbar)
    }

    @ViewBuilder
    private var filterIndicator: some View {
        if viewModel.filterPriority != nil || viewModel.filterStatus != nil || viewModel.filterAssignee != nil {
            Button {
                viewModel.clearFilters()
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 12))
                    Text("Clear filters")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.accentAmber)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Ticket Table

    private var ticketTable: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(viewModel.groupedTickets, id: \.0) { group, tickets in
                    Section {
                        ForEach(tickets) { ticket in
                            VStack(spacing: 0) {
                                ticketRow(ticket)
                                Divider().overlay(AnvilColor.borderSubtle)
                            }
                        }
                    } header: {
                        groupHeader(group, count: tickets.count)
                    }
                }
            }
        }
    }

    // MARK: - Group Header

    private func groupHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .tracking(0.3)

            Text("\(count)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(AnvilColor.backgroundElevated)
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.xs)
        .background(.regularMaterial)
    }

    // MARK: - Ticket Row

    private func ticketRow(_ ticket: Ticket) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            Circle()
                .fill(IntentViewModel.priorityColor(ticket.priority))
                .frame(width: 8, height: 8)

            Image(systemName: IntentViewModel.statusIcon(ticket.status))
                .font(.system(size: 13))
                .foregroundStyle(IntentViewModel.statusColor(ticket.status))
                .frame(width: 18)

            Text(ticket.id)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 70, alignment: .leading)

            Text(ticket.title)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Spacer()

            labelsView(for: ticket)
            storyPointsBadge(ticket.storyPoints)
            assigneeCell(ticket.assignee)
            dueDateCell(ticket.dueDate)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(
            viewModel.selectedTicketId == ticket.id
                ? AnvilColor.selectionBackground
                : Color.clear
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(viewModel.selectedTicketId == ticket.id ? AnvilColor.selectionBorder : Color.clear)
                .frame(width: 3)
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectTicket(ticket.id) }
        .contextMenu {
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
    }

    private func labelsView(for ticket: Ticket) -> some View {
        HStack(spacing: AnvilSpacing.xxs) {
            ForEach(Array(ticket.labels.prefix(2)), id: \.self) { label in
                AnvilBadge(text: label, color: AnvilColor.textTertiary)
            }
        }
    }

    private func storyPointsBadge(_ points: Int?) -> some View {
        Group {
            if let sp = points {
                Text("\(sp)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 20, alignment: .center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(AnvilColor.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .frame(width: 28)
    }

    private func assigneeCell(_ assignee: String?) -> some View {
        Group {
            if let name = assignee {
                HStack(spacing: AnvilSpacing.xxs) {
                    Circle()
                        .fill(AnvilColor.backgroundElevated)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AnvilColor.textSecondary)
                        )
                    Text(name)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .lineLimit(1)
                }
            } else {
                Text("--")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .frame(width: 90, alignment: .leading)
    }

    private func dueDateCell(_ date: Date?) -> some View {
        Group {
            if let due = date {
                dueDateText(due)
            }
        }
        .frame(width: 70, alignment: .trailing)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Spacer()
            Image(systemName: "ticket")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)

            Text("No tickets match your filters")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)

            AnvilButton("Clear Filters", icon: "xmark", style: .ghost) {
                viewModel.clearFilters()
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func dueDateText(_ date: Date) -> some View {
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
