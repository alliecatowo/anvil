import SwiftUI
import AnvilDomain

struct BoardView: View {
    @ObservedObject var viewModel: IntentViewModel
    @State private var draggingTicketId: String?
    @State private var creatingInColumnId: String?
    @State private var newTicketTitle = ""
    @FocusState private var isNewTicketFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Board header
            boardHeader

            Divider()

            // Columns
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: AnvilSpacing.md) {
                    ForEach(viewModel.board.columns) { column in
                        columnView(column)
                    }
                }
                .padding(AnvilSpacing.lg)
            }
        }
    }

    // MARK: - Board Header

    private var boardHeader: some View {
        HStack {
            Text(viewModel.board.name)
                .font(AnvilFont.subheading)
                .foregroundStyle(AnvilColor.textPrimary)

            Spacer()

            Text(viewModel.currentCycle.name)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.md)
        .background(AnvilColor.backgroundToolbar)
    }

    // MARK: - Column

    private func columnView(_ column: BoardColumn) -> some View {
        let tickets = viewModel.ticketsForColumn(column)
        let overWip = column.wipLimit.map { tickets.count > $0 } ?? false

        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Column header
            HStack {
                Text(column.name)
                    .font(.headline)

                Text("\(tickets.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                if let limit = column.wipLimit {
                    Text("/ \(limit)")
                        .font(AnvilFont.label)
                        .foregroundStyle(overWip ? AnvilColor.accentRed : AnvilColor.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.sm)

            // WIP warning
            if overWip {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .accessibilityHidden(true)
                    Text("Over WIP limit")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.accentRed)
                .padding(.horizontal, AnvilSpacing.sm)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Warning: Over WIP limit")
            }

            // Cards
            ForEach(tickets) { ticket in
                boardCard(ticket)
                    .draggable(ticket.id) {
                        // Drag preview
                        boardCardPreview(ticket)
                    }
                    .opacity(draggingTicketId == ticket.id ? 0.4 : 1.0)
            }

            // Inline ticket creation
            if creatingInColumnId == column.id {
                VStack(spacing: AnvilSpacing.xs) {
                    TextField("Ticket title", text: $newTicketTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.sidebarItem)
                        .focused($isNewTicketFocused)
                        .onSubmit {
                            withAnimation(AnvilAnimation.standard) {
                                viewModel.createTicket(title: newTicketTitle, status: column.status)
                            }
                            newTicketTitle = ""
                            creatingInColumnId = nil
                        }
                        .onKeyPress(.escape) {
                            newTicketTitle = ""
                            creatingInColumnId = nil
                            return .handled
                        }

                    HStack(spacing: AnvilSpacing.xs) {
                        Text("Enter to create")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Spacer()
                        Button("Cancel") {
                            newTicketTitle = ""
                            creatingInColumnId = nil
                        }
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Add ticket button
                Button {
                    creatingInColumnId = column.id
                    newTicketTitle = ""
                    isNewTicketFocused = true
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("Add ticket")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                        .strokeBorder(AnvilColor.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            }
        }
        .frame(width: 240)
        .padding(AnvilSpacing.sm)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .dropDestination(for: String.self) { items, _ in
            guard let ticketId = items.first else { return false }
            withAnimation(AnvilAnimation.standard) {
                viewModel.moveTicket(ticketId, toStatus: column.status)
            }
            draggingTicketId = nil
            return true
        } isTargeted: { isTargeted in
            // Could add highlighting here in the future
        }
    }

    // MARK: - Board Card

    private func boardCard(_ ticket: Ticket) -> some View {
        AnvilCard {
            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                // Priority + ID
                HStack {
                    Circle()
                        .fill(IntentViewModel.priorityColor(ticket.priority))
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("\(IntentViewModel.priorityLabel(ticket.priority)) priority")

                    Text(ticket.id)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Spacer()

                    if let sp = ticket.storyPoints {
                        Text("\(sp)")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                // Title
                Text(ticket.title)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(2)

                // Subtask progress
                let progress = viewModel.subtaskProgress(ticket.id)
                if progress.total > 0 {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "checklist")
                            .font(.system(size: 9))
                        Text("\(progress.completed)/\(progress.total)")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(progress.completed == progress.total ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                }

                // Assignee + due date
                HStack {
                    if let assignee = ticket.assignee {
                        Circle()
                            .fill(AnvilColor.backgroundElevated)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(String(assignee.prefix(1)).uppercased())
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(AnvilColor.textSecondary)
                            )
                            .accessibilityHidden(true)
                        Text(assignee)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .lineLimit(1)
                            .accessibilityLabel("Assigned to \(assignee)")
                    }

                    Spacer()

                    if let due = ticket.dueDate {
                        Text(due, style: .date)
                            .font(AnvilFont.label)
                            .foregroundStyle(IntentViewModel.dueDateColor(due))
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectTicket(ticket.id) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ticket.title), \(IntentViewModel.priorityLabel(ticket.priority)) priority, \(ticket.id)")
        .accessibilityAddTraits(.isButton)
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

    /// Compact preview shown while dragging a card.
    private func boardCardPreview(_ ticket: Ticket) -> some View {
        HStack(spacing: AnvilSpacing.xs) {
            Circle()
                .fill(IntentViewModel.priorityColor(ticket.priority))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(ticket.id)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
            Text(ticket.title)
                .font(AnvilFont.sidebarItem)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)
        }
        .padding(AnvilSpacing.sm)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
    }
}
