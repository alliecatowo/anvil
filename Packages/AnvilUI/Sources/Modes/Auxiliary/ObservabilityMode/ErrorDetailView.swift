import SwiftUI
import AnvilDomain

struct ErrorDetailView: View {
    let error: ErrorItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.xl) {
                // Header
                header

                // Stats row
                statsRow

                // Breadcrumbs
                if !error.breadcrumbs.isEmpty {
                    breadcrumbsSection
                }

                // Stack trace
                if let stackTrace = error.event.stackTrace {
                    stackTraceSection(stackTrace)
                }

                // Tags
                if !error.event.tags.isEmpty {
                    tagsSection
                }
            }
            .padding(AnvilSpacing.xl)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: error.severity.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(error.severity.color)

                AnvilBadge(text: error.severity.rawValue.capitalized, color: error.severity.color)
            }

            Text(error.event.title)
                .font(AnvilFont.heading)

            Text(error.event.message)
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: AnvilSpacing.xl) {
            statItem(label: "Occurrences", value: "\(error.event.occurrences)")
            statItem(label: "Affected Users", value: "\(error.affectedUsers)")
            statItem(label: "Status", value: error.event.isResolved ? "Resolved" : "Active")
        }
    }

    private func statItem(label: String, value: String) -> some View {
        AnvilCard {
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(AnvilFont.subheading)
            }
            .frame(minWidth: 100, alignment: .leading)
        }
    }

    // MARK: - Breadcrumbs

    private var breadcrumbsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Breadcrumbs")
                .font(AnvilFont.subheading)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(error.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    HStack(spacing: AnvilSpacing.sm) {
                        // Timeline dot + line
                        VStack(spacing: 0) {
                            Circle()
                                .fill(index == error.breadcrumbs.count - 1
                                    ? error.severity.color
                                    : Color.secondary)
                                .frame(width: 8, height: 8)

                            if index < error.breadcrumbs.count - 1 {
                                Rectangle()
                                    .fill(.quaternary)
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 20)

                        Text(crumb)
                            .font(AnvilFont.code)
                            .foregroundStyle(index == error.breadcrumbs.count - 1
                                ? .primary
                                : .secondary)
                            .padding(.vertical, AnvilSpacing.xs)
                    }
                }
            }
        }
    }

    // MARK: - Stack Trace

    private func stackTraceSection(_ trace: String) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Stack Trace")
                .font(AnvilFont.subheading)

            GroupBox {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(trace)
                        .font(AnvilFont.code)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Tags")
                .font(AnvilFont.subheading)

            HStack(spacing: AnvilSpacing.sm) {
                ForEach(error.event.tags.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack(spacing: AnvilSpacing.xxs) {
                        Text(key)
                            .font(AnvilFont.label)
                            .foregroundStyle(.tertiary)
                        Text(value)
                            .font(AnvilFont.label)
                    }
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, AnvilSpacing.xxs)
                    .background(.quaternary, in: Capsule())
                }
            }
        }
    }
}
