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
                    .foregroundStyle(AnvilColor.textPrimary)

                ForEach(viewModel.entries) { entry in
                    timeBlockCard(entry)
                }
            }
            .padding(AnvilSpacing.xl)
        }
        .background(AnvilColor.backgroundPrimary)
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
                            .foregroundStyle(AnvilColor.textPrimary)
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
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("\(timeFormatter.string(from: entry.start)) – \(timeFormatter.string(from: entry.end))")
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }

                    Text(entry.duration)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .padding(.horizontal, AnvilSpacing.xs)
                        .padding(.vertical, 1)
                        .background(AnvilColor.backgroundElevated)
                        .clipShape(Capsule())
                }

                // Subtitle
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
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
                            .foregroundStyle(AnvilColor.textTertiary)

                        ForEach(entry.attendees, id: \.self) { name in
                            Text(name)
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textSecondary)
                                .padding(.horizontal, AnvilSpacing.xs)
                                .padding(.vertical, 1)
                                .background(AnvilColor.backgroundElevated)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(AnvilSpacing.cardPadding)
        }
        .background(AnvilColor.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(entry.kindColor.opacity(0.3), lineWidth: 1)
        )
    }
}
