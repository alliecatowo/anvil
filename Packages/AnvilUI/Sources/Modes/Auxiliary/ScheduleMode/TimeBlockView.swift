import SwiftUI

struct TimeBlockView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                Text("Time Blocks")
                    .font(AnvilFont.heading)

                ForEach(viewModel.entries) { entry in
                    timeBlockCard(entry)
                }
            }
            .padding(AnvilSpacing.xl)
        }
    }

    // MARK: - Time Block Card

    private func timeBlockCard(_ entry: ScheduleEntry) -> some View {
        Button {
            viewModel.selectedEntryID = entry.id
        } label: {
            HStack(spacing: 0) {
                // Left color bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(entry.kindColor)
                    .frame(width: 4)
                    .accessibilityHidden(true)

                // Card content
                VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    // Header
                    HStack {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: entry.kindIcon)
                                .font(.system(size: 14))
                                .foregroundStyle(entry.kindColor)
                                .accessibilityHidden(true)

                            Text(entry.title)
                                .font(AnvilFont.subheading)
                                .lineLimit(1)
                        }

                        Spacer()

                        AnvilBadge(text: entry.kindLabel, color: entry.kindColor)
                    }

                    // Time range + duration
                    HStack(spacing: AnvilSpacing.md) {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)

                            Text("\(timeFormatter.string(from: entry.start)) – \(timeFormatter.string(from: entry.end))")
                                .font(AnvilFont.code)
                                .foregroundStyle(.secondary)
                        }

                        Text(entry.duration)
                            .font(AnvilFont.label)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, AnvilSpacing.xs)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }

                    // Subtitle
                    if let subtitle = entry.subtitle {
                        Text(subtitle)
                            .font(AnvilFont.body)
                            .foregroundStyle(.secondary)
                    }

                    // Linked ticket
                    if let ticket = entry.linkedTicket {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text(ticket)
                                .font(AnvilFont.code)
                        }
                        .foregroundStyle(AnvilColor.accentBlue)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Linked ticket: \(ticket)")
                    }

                    // Attendees
                    if !entry.attendees.isEmpty {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: "person.2")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)

                            ForEach(entry.attendees, id: \.self) { name in
                                Text(name)
                                    .font(AnvilFont.label)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, AnvilSpacing.xs)
                                    .padding(.vertical, 1)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Attendees: \(entry.attendees.joined(separator: ", "))")
                    }
                }
                .padding(AnvilSpacing.cardPadding)
            }
            .background {
                GroupBox { Color.clear }
            }
            .background(viewModel.selectedEntryID == entry.id ? Color.accentColor.opacity(0.14) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(entry.kindLabel), \(timeFormatter.string(from: entry.start)) to \(timeFormatter.string(from: entry.end)), \(entry.duration)")
        .accessibilityAddTraits(.isButton)
    }
}
