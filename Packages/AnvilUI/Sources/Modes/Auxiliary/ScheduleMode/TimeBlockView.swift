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
            VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
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
        HStack(spacing: 0) {
            // Left color bar
            RoundedRectangle(cornerRadius: 4)
                .fill(entry.kindColor)
                .frame(width: 4)

            // Card content
            VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                // Header
                HStack {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: entry.kindIcon)
                            .font(.system(size: 14))
                            .foregroundStyle(entry.kindColor)

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
                        Text(ticket)
                            .font(AnvilFont.code)
                    }
                    .foregroundStyle(AnvilColor.accentBlue)
                }

                // Attendees
                if !entry.attendees.isEmpty {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "person.2")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        ForEach(entry.attendees, id: \.self) { name in
                            Text(name)
                                .font(AnvilFont.label)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, AnvilSpacing.xs)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
            .padding(AnvilSpacing.cardPadding)
        }
        .background {
            GroupBox { Color.clear }
        }
    }
}
