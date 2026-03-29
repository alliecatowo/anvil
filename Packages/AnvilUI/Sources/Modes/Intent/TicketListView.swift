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

                Picker("Group by", selection: $viewModel.grouping) {
                    ForEach(TicketGrouping.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .accessibilityLabel("Group tickets by")
            }

            HStack(spacing: AnvilSpacing.xxs) {
                Text("Sort:")
                    .foregroundStyle(.secondary)

                Picker("Sort by", selection: $viewModel.sortField) {
                    ForEach(TicketSortField.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                .accessibilityLabel("Sort tickets by")
            }

            Spacer()

            filterIndicator

            if viewModel.selectedTicketId != nil {
                Button {
                    viewModel.openSelectedTicketInMainPane()
                } label: {
                    Label("Open", systemImage: "arrow.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Open selected ticket in main pane")
                .accessibilityIdentifier("intent.open-main-pane")
            }

            Text("\(viewModel.filteredTickets.count) tickets")
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(viewModel.filteredTickets.count) tickets shown")
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
                        .accessibilityHidden(true)
                    Text("Clear Filters")
                }
                .foregroundStyle(.orange)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Clear all filters")
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Ticket Table

    private var ticketTable: some View {
        Table(viewModel.filteredTickets, selection: $viewModel.selectedTicketIds) {
            TableColumn("Title") { ticket in
                HStack(spacing: AnvilSpacing.sm) {
                    Circle()
                        .fill(IntentViewModel.priorityColor(ticket.priority))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    Image(systemName: IntentViewModel.statusIcon(ticket.status))
                        .font(.system(size: 13))
                        .foregroundStyle(IntentViewModel.statusColor(ticket.status))
                        .frame(width: 18)
                        .accessibilityHidden(true)

                    Text(ticket.id)
                        .font(AnvilFont.code)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)

                    Text(ticket.title)
                        .font(AnvilFont.body)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(ticket.title), \(ticket.id)")
                .accessibilityIdentifier("intent.ticket-row.\(ticket.id)")
            }
            .width(min: 200, ideal: 400)

            TableColumn("Status") { ticket in
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: IntentViewModel.statusIcon(ticket.status))
                        .font(.system(size: 11))
                        .foregroundStyle(IntentViewModel.statusColor(ticket.status))
                    Text(ticket.status.capitalized)
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: \(ticket.status)")
            }
            .width(min: 80, ideal: 110)

            TableColumn("Priority") { ticket in
                HStack(spacing: AnvilSpacing.xxs) {
                    Circle()
                        .fill(IntentViewModel.priorityColor(ticket.priority))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(IntentViewModel.priorityLabel(ticket.priority))
                        .font(AnvilFont.label)
                        .foregroundStyle(IntentViewModel.priorityColor(ticket.priority))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(IntentViewModel.priorityLabel(ticket.priority)) priority")
            }
            .width(min: 80, ideal: 110)

            TableColumn("Assignee") { ticket in
                assigneeCell(ticket.assignee)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Updated") { ticket in
                Text(ticket.updatedAt, style: .relative)
                    .font(AnvilFont.label)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Updated \(ticket.updatedAt, style: .relative)")
            }
            .width(min: 60, ideal: 90)
        }
        .contextMenu(forSelectionType: Ticket.ID.self) { ids in
            if ids.isEmpty {
                // Background context menu (no selection)
            } else {
                bulkContextMenu(ids: ids)
            }
        } primaryAction: { ids in
            // Double-click opens ticket detail in the main content area.
            if let first = ids.first {
                viewModel.selectTicket(first, openInMainPane: true)
            }
        }
        .onChange(of: viewModel.selectedTicketIds) { _, newValue in
            // Sync single-select selection with the main detail view.
            if newValue.count == 1, let id = newValue.first {
                viewModel.selectTicket(id)
            }
        }
    }

    // MARK: - Bulk Context Menu

    @ViewBuilder
    private func bulkContextMenu(ids: Set<String>) -> some View {
        let count = ids.count

        Menu("Status") {
            ForEach(viewModel.allStatuses, id: \.self) { status in
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        for id in ids {
                            viewModel.updateStatus(id, status: status)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: IntentViewModel.statusIcon(status))
                        Text(status.capitalized)
                    }
                }
            }
        }

        Menu("Priority") {
            ForEach([TicketPriority.critical, .high, .medium, .low, .none], id: \.rawValue) { priority in
                Button {
                    for id in ids {
                        viewModel.updatePriority(id, priority: priority)
                    }
                } label: {
                    Text(IntentViewModel.priorityLabel(priority))
                }
            }
        }

        Menu("Assignee") {
            Button {
                for id in ids {
                    viewModel.updateAssignee(id, assignee: nil)
                }
            } label: {
                Text("Unassigned")
            }
            Divider()
            ForEach(viewModel.allAssignees, id: \.self) { name in
                Button {
                    for id in ids {
                        viewModel.updateAssignee(id, assignee: name)
                    }
                } label: {
                    Text(name)
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            withAnimation(AnvilAnimation.standard) {
                for id in ids {
                    viewModel.deleteTicket(id)
                }
                viewModel.selectedTicketIds.removeAll()
            }
        } label: {
            Label(count > 1 ? "Delete \(count) Tickets" : "Delete Ticket", systemImage: "trash")
        }
    }

    // MARK: - Cells

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
                        .accessibilityHidden(true)
                    Text(name)
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Assignee: \(name)")
            } else {
                Text("--")
                    .font(AnvilFont.label)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Unassigned")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Spacer()
            Image(systemName: "ticket")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No tickets match your filters")
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)

            AnvilButton("Clear Filters", icon: "xmark", style: .ghost) {
                viewModel.clearFilters()
            }
            .accessibilityLabel("Clear all filters")
            .accessibilityAddTraits(.isButton)
            Spacer()
        }
    }
}
