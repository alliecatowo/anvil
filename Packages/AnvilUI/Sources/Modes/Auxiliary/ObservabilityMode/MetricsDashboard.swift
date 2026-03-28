import SwiftUI

struct MetricsDashboard: View {
    @ObservedObject var viewModel: ObservabilityViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.xl) {
                Text("Metrics")
                    .font(AnvilFont.heading)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ],
                    spacing: AnvilSpacing.lg
                ) {
                    ForEach(viewModel.metrics) { card in
                        metricCard(card)
                    }
                }
            }
            .padding(AnvilSpacing.xl)
        }
    }

    // MARK: - Metric Card

    private func metricCard(_ card: MetricCard) -> some View {
        AnvilCard {
            VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                // Title
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                // Value
                Text(card.value)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(card.color)

                // Trend + subtitle
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: card.trend.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(card.trend.color)

                    Text(card.subtitle)
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
