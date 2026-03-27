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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.errors) { error in
                    errorRow(error)
                    Divider().overlay(AnvilColor.borderSubtle)
                }
            }
        }
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
                        .foregroundStyle(AnvilColor.textPrimary)
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
                            .foregroundStyle(AnvilColor.textTertiary)
                    }

                    Text("·")
                        .foregroundStyle(AnvilColor.textTertiary)

                    // First seen
                    Text("First: \(timeFormatter.localizedString(for: item.event.firstSeen, relativeTo: .now))")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Text("·")
                        .foregroundStyle(AnvilColor.textTertiary)

                    // Last seen
                    Text("Last: \(timeFormatter.localizedString(for: item.event.lastSeen, relativeTo: .now))")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.md)
        .background(viewModel.selectedErrorID == item.id ? AnvilColor.selectionBackground : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedErrorID = item.id
        }
    }
}
