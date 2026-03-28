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

            Divider()

            // Entries
            List {
                ForEach(viewModel.entries) { entry in
                    agendaRow(entry)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                Text("Today's Schedule")
                    .font(AnvilFont.subheading)

                Text(todayString())
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
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
                .accessibilityHidden(true)
            Text(label)
                .font(AnvilFont.label)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xxs)
        .background(.quaternary, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    // MARK: - Agenda Row

    private func agendaRow(_ entry: ScheduleEntry) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Time column
            VStack(alignment: .trailing, spacing: AnvilSpacing.xxs) {
                Text(timeFormatter.string(from: entry.start))
                    .font(AnvilFont.code)
                Text(entry.duration)
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 72, alignment: .trailing)

            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.kindColor)
                .frame(width: 3)
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: entry.kindIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.kindColor)
                        .accessibilityHidden(true)

                    Text(entry.title)
                        .font(AnvilFont.sidebarItem)
                        .lineLimit(1)

                    Spacer()

                    AnvilBadge(text: entry.kindLabel, color: entry.kindColor)
                }

                HStack(spacing: AnvilSpacing.sm) {
                    if let subtitle = entry.subtitle {
                        Text(subtitle)
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        Text(entry.attendees.joined(separator: ", "))
                            .font(AnvilFont.label)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Attendees: \(entry.attendees.joined(separator: ", "))")
                }
            }
        }
        .contentShape(Rectangle())
        .listRowBackground(viewModel.selectedEntryID == entry.id ? Color.accentColor.opacity(0.14) : Color.clear)
        .onTapGesture {
            viewModel.selectedEntryID = entry.id
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(timeFormatter.string(from: entry.start)), \(entry.duration), \(entry.kindLabel)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helpers

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}
