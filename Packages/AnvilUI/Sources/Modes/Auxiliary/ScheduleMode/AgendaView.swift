import SwiftUI

struct AgendaView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().overlay(AnvilColor.borderSubtle)

            // Entries
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.entries) { entry in
                        agendaRow(entry)
                        Divider().overlay(AnvilColor.borderSubtle)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                Text("Today's Schedule")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Text(todayString())
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            HStack(spacing: AnvilSpacing.md) {
                summaryPill(icon: "video", label: "\(viewModel.meetingCount) meetings")
                summaryPill(icon: "brain.head.profile", label: "\(viewModel.focusMinutes / 60)h focus")
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
    }

    private func summaryPill(icon: String, label: String) -> some View {
        HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(AnvilFont.label)
        }
        .foregroundStyle(AnvilColor.textSecondary)
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xxs)
        .background(AnvilColor.backgroundTertiary)
        .clipShape(Capsule())
    }

    // MARK: - Agenda Row

    private func agendaRow(_ entry: ScheduleEntry) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Time column
            VStack(alignment: .trailing, spacing: AnvilSpacing.xxs) {
                Text(timeFormatter.string(from: entry.start))
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text(entry.duration)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .frame(width: 72, alignment: .trailing)

            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.kindColor)
                .frame(width: 3)

            // Content
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: entry.kindIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.kindColor)

                    Text(entry.title)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    AnvilBadge(text: entry.kindLabel, color: entry.kindColor)
                }

                HStack(spacing: AnvilSpacing.sm) {
                    if let subtitle = entry.subtitle {
                        Text(subtitle)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .lineLimit(1)
                    }

                    if let ticket = entry.linkedTicket {
                        Text(ticket)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.accentBlue)
                    }
                }

                if !entry.attendees.isEmpty {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "person.2")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text(entry.attendees.joined(separator: ", "))
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.md)
        .background(viewModel.selectedEntryID == entry.id ? AnvilColor.selectionBackground : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedEntryID = entry.id
        }
    }

    // MARK: - Helpers

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}
