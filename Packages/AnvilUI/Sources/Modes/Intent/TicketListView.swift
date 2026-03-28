import SwiftUI
import AnvilDomain

struct TicketListView: View {
    @ObservedObject var viewModel: IntentViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

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
                    .foregroundStyle(.secondary)

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
                    .foregroundStyle(.secondary)

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
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(.bar)
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
                    Text("Clear Filters")
                }
                .foregroundStyle(.orange)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Ticket Table

    private var ticketTable: some View {
        List {
            ForEach(viewModel.groupedTickets, id: \.0) { group, tickets in
                Section {
                    ForEach(tickets) { ticket in
                        ticketRow(ticket)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(
                                viewModel.selectedTicketId == ticket.id
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.clear
                            )
                    }
                } header: {
                    groupHeader(group, count: tickets.count)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Group Header

    private func groupHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Text("\(count)")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.regularMaterial)
                .clipShape(Capsule())

            Spacer()
        }
        .textCase(nil)
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
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(ticket.title)
                .font(AnvilFont.body)
                .lineLimit(1)

            Spacer()

            labelsView(for: ticket)
            storyPointsBadge(ticket.storyPoints)
            assigneeCell(ticket.assignee)
            dueDateCell(ticket.dueDate)
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
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.regularMaterial)
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
                                .foregroundStyle(.secondary)
                        )
                    Text(name)
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("--")
                    .font(AnvilFont.label)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

            Text("No tickets match your filters")
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)

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
