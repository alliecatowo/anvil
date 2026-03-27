import SwiftUI
import AnvilDomain

struct IntentSidebar: View {
    @ObservedObject var viewModel: IntentViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search
            AnvilSearchField(text: $viewModel.searchText, placeholder: "Search tickets...")

            Divider().overlay(AnvilColor.borderSubtle)

            // View mode picker
            HStack(spacing: AnvilSpacing.xxs) {
                ForEach(IntentViewMode.allCases, id: \.rawValue) { mode in
                    Button {
                        viewModel.viewMode = mode
                        viewModel.selectTicket(nil)
                    } label: {
                        Text(mode.rawValue)
                            .font(AnvilFont.label)
                            .foregroundStyle(
                                viewModel.viewMode == mode
                                    ? AnvilColor.textPrimary
                                    : AnvilColor.textTertiary
                            )
                            .padding(.horizontal, AnvilSpacing.sm)
                            .padding(.vertical, AnvilSpacing.xxs)
                            .background(
                                viewModel.viewMode == mode
                                    ? AnvilColor.backgroundTertiary
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)

            Divider().overlay(AnvilColor.borderSubtle)

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
                            }
                        } header: {
                            sectionHeader(group, count: tickets.count)
                        }
                    }
                }
            }
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
                        // Avatar placeholder
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
