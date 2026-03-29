import SwiftUI
import AnvilDomain

// MARK: - Kanban Card

/// A single ticket card used in the kanban board view.
/// Features hover scale + shadow interaction, priority dot, assignee initials bubble,
/// subtask progress, and story points badge.
struct KanbanCard: View {
    let ticket: Ticket
    @ObservedObject var viewModel: IntentViewModel
    @State private var isHovered = false

    var body: some View {
        let isSelected = viewModel.selectedTicketId == ticket.id

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
                    assigneeBubble(assignee)
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
        .padding(AnvilSpacing.sm)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.85) : .clear, lineWidth: 1.5)
        )
        .shadow(
            color: .black.opacity(isHovered ? 0.14 : 0.08),
            radius: isHovered ? 8 : 4,
            y: isHovered ? 3 : 1
        )
        .scaleEffect(isHovered ? 1.02 : (isSelected ? 1.01 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in isHovered = hovering }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ticket.title), \(IntentViewModel.priorityLabel(ticket.priority)) priority, \(ticket.id)")
        .accessibilityAddTraits(.isButton)
    }

    private func assigneeBubble(_ name: String) -> some View {
        Circle()
            .fill(AnvilColor.backgroundElevated)
            .frame(width: 16, height: 16)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(AnvilColor.textSecondary)
            )
            .accessibilityHidden(true)
    }
}
