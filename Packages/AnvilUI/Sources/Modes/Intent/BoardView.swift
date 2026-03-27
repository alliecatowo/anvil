import SwiftUI
import AnvilDomain

struct BoardView: View {
    @ObservedObject var viewModel: IntentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Board header
            boardHeader

            Divider().overlay(AnvilColor.borderSubtle)

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
        .background(AnvilColor.backgroundPrimary)
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
    }

    // MARK: - Column

    private func columnView(_ column: BoardColumn) -> some View {
        let tickets = viewModel.ticketsForColumn(column)
        let overWip = column.wipLimit.map { tickets.count > $0 } ?? false

        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Column header
            HStack {
                Text(column.name.uppercased())
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .tracking(0.3)

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
                    Text("Over WIP limit")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.accentRed)
                .padding(.horizontal, AnvilSpacing.sm)
            }

            // Cards
            ForEach(tickets) { ticket in
                boardCard(ticket)
            }

            // Drop hint
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .strokeBorder(AnvilColor.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(height: 48)
                .overlay(
                    Text("Drag here")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                )
        }
        .frame(width: 240)
        .padding(AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
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
                        Text(assignee)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let due = ticket.dueDate {
                        Text(due, style: .date)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectTicket(ticket.id) }
    }
}
