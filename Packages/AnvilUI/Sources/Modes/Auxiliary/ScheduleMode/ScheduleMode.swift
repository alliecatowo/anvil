import SwiftUI
import AnvilDomain

struct ScheduleMode: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                tabSelector
                Divider()

                Group {
                    switch viewModel.selectedTab {
                    case .agenda:
                        AgendaView(viewModel: viewModel)
                    case .blocks:
                        TimeBlockView(viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScheduleDetailView(viewModel: viewModel)
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 420, maxHeight: .infinity)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleTab.allCases, id: \.rawValue) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(AnvilFont.label)
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? .primary
                                : .tertiary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AnvilSpacing.sm)
                        .background(
                            viewModel.selectedTab == tab
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.rawValue) tab")
                .accessibilityAddTraits(viewModel.selectedTab == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xs)
    }
}

private struct ScheduleDetailView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        Group {
            if let entry = viewModel.selectedEntry {
                ScheduleEntryDetailView(entry: entry)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.tertiary.opacity(0.5))

            Text("Select a schedule entry")
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScheduleEntryDetailView: View {
    let entry: ScheduleEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                HStack(alignment: .top, spacing: AnvilSpacing.md) {
                    Image(systemName: entry.kindIcon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(entry.kindColor)

                    VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                        Text(entry.title)
                            .font(AnvilFont.heading)
                            .foregroundStyle(AnvilColor.textPrimary)

                        Text("\(timeRange) • \(entry.kindLabel)")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }

                    Spacer()

                    AnvilBadge(text: entry.kindLabel, color: entry.kindColor)
                }

                if let subtitle = entry.subtitle {
                    section(title: "Notes") {
                        Text(subtitle)
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                }

                section(title: "Time") {
                    VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                        Text("Starts \(timeFormatter.string(from: entry.start))")
                            .font(AnvilFont.body)
                        Text("Ends \(timeFormatter.string(from: entry.end))")
                            .font(AnvilFont.body)
                        Text("Duration \(entry.duration)")
                            .font(AnvilFont.body)
                    }
                    .foregroundStyle(AnvilColor.textSecondary)
                }

                if let ticket = entry.linkedTicket {
                    section(title: "Linked Ticket") {
                        Text(ticket)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.accentBlue)
                    }
                }

                if !entry.attendees.isEmpty {
                    section(title: "Attendees") {
                        Text(entry.attendees.joined(separator: ", "))
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                }
            }
            .padding(AnvilSpacing.lg)
        }
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    private var timeRange: String {
        "\(timeFormatter.string(from: entry.start)) – \(timeFormatter.string(from: entry.end))"
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text(title)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            content()
        }
    }
}
