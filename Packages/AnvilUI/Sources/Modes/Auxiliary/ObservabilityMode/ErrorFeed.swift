import SwiftUI
import AnvilDomain

struct ErrorFeed: View {
    @ObservedObject var viewModel: ObservabilityViewModel

    private let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        List {
            ForEach(viewModel.errors) { error in
                errorRow(error)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Error Row

    private func errorRow(_ item: ErrorItem) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Severity icon
            Image(systemName: item.severity.icon)
                .font(.system(size: 14))
                .foregroundStyle(item.severity.color)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                HStack {
                    Text(item.event.title)
                        .font(AnvilFont.sidebarItem)
                        .lineLimit(1)

                    Spacer()

                    // Count badge
                    AnvilBadge(
                        text: "\(item.event.occurrences)",
                        color: item.severity.color
                    )
                }

                HStack(spacing: AnvilSpacing.sm) {
                    // Service tag
                    if let service = item.event.tags["service"] {
                        Text(service)
                            .font(AnvilFont.code)
                            .foregroundStyle(.tertiary)
                    }

                    Text("·")
                        .foregroundStyle(.tertiary)

                    // First seen
                    Text("First: \(timeFormatter.localizedString(for: item.event.firstSeen, relativeTo: .now))")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    // Last seen
                    Text("Last: \(timeFormatter.localizedString(for: item.event.lastSeen, relativeTo: .now))")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
        .listRowBackground(viewModel.selectedErrorID == item.id ? Color.accentColor.opacity(0.14) : Color.clear)
        .onTapGesture {
            viewModel.selectedErrorID = item.id
        }
    }
}
