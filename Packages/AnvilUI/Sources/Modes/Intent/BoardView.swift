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
                .foregroundStyle(.primary)

            Spacer()

            Text(viewModel.currentCycle.name)
                .font(AnvilFont.label)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.md)
        .background(.bar)
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
                    .foregroundStyle(.tertiary)

                if let limit = column.wipLimit {
                    Text("/ \(limit)")
                        .font(AnvilFont.label)
                        .foregroundStyle(overWip ? Color.red : Color.secondary)
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
                .foregroundStyle(.red)
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
                        .accessibilityIdentifier("intent.board.new-ticket-title")
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
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button("Cancel") {
                            newTicketTitle = ""
                            creatingInColumnId = nil
                        }
                        .font(AnvilFont.label)
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
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("intent.board.add-ticket.\(column.id)")
                .background(
                    RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                        .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
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
        Button {
            viewModel.selectTicket(ticket.id)
        } label: {
            KanbanCard(ticket: ticket, viewModel: viewModel)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ticket.title), \(IntentViewModel.priorityLabel(ticket.priority)) priority, \(ticket.id)")
        .accessibilityIdentifier("intent.board.ticket-card.\(ticket.id)")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button {
                viewModel.selectTicket(ticket.id, openInMainPane: true)
            } label: {
                Label("Open in Main Pane", systemImage: "arrow.right.square")
            }
            .accessibilityIdentifier("intent.board.open-main-pane.\(ticket.id)")

            Divider()

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
                .foregroundStyle(.tertiary)
            Text(ticket.title)
                .font(AnvilFont.sidebarItem)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(AnvilSpacing.sm)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
    }
}
