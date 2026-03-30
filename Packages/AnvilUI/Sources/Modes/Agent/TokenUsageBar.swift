import SwiftUI
import AnvilDomain

/// Displays token usage as a visual progress bar with context window limit.
/// Shows input/output/cache breakdown and cost.
struct TokenUsageBar: View {
    let usage: TokenUsage
    let cost: Decimal
    let contextLimit: Int

    private var totalTokens: Int { usage.totalTokens }
    private var usageRatio: Double { contextLimit > 0 ? Double(totalTokens) / Double(contextLimit) : 0 }
    private var isNearLimit: Bool { usageRatio > 0.8 }
    private var isOverLimit: Bool { usageRatio > 0.95 }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                // Header row
                HStack {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .accessibilityHidden(true)
                        Text("Token Usage")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }

                    Spacer()

                    // Total and cost
                    HStack(spacing: AnvilSpacing.sm) {
                        Text(formatTokenCount(totalTokens))
                            .font(AnvilFont.statusBar)
                            .foregroundStyle(usageColor)

                        Text("/")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text(formatTokenCount(contextLimit))
                            .font(AnvilFont.statusBar)
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("$\(NSDecimalNumber(decimal: cost).doubleValue, specifier: "%.3f")")
                            .font(AnvilFont.statusBar)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)

                        // Stacked segments
                        HStack(spacing: 0) {
                            let inputWidth = segmentWidth(geo.size.width, tokens: usage.inputTokens)
                            let outputWidth = segmentWidth(geo.size.width, tokens: usage.outputTokens)
                            let cacheWidth = segmentWidth(geo.size.width, tokens: usage.cacheReadTokens + usage.cacheWriteTokens)

                            if usage.inputTokens > 0 {
                                Rectangle()
                                    .fill(AnvilColor.accentBlue)
                                    .frame(width: inputWidth)
                            }
                            if usage.outputTokens > 0 {
                                Rectangle()
                                    .fill(AnvilColor.accentPurple)
                                    .frame(width: outputWidth)
                            }
                            if usage.cacheReadTokens + usage.cacheWriteTokens > 0 {
                                Rectangle()
                                    .fill(AnvilColor.accentTeal)
                                    .frame(width: cacheWidth)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .frame(height: 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Token usage: \(formatTokenCount(totalTokens)) of \(formatTokenCount(contextLimit)) tokens used, \(Int(usageRatio * 100)) percent")

                // Legend
                HStack(spacing: AnvilSpacing.md) {
                    legendItem(color: AnvilColor.accentBlue, label: "Input", count: usage.inputTokens)
                    legendItem(color: AnvilColor.accentPurple, label: "Output", count: usage.outputTokens)
                    if usage.cacheReadTokens + usage.cacheWriteTokens > 0 {
                        legendItem(color: AnvilColor.accentTeal, label: "Cache", count: usage.cacheReadTokens + usage.cacheWriteTokens)
                    }

                    Spacer()

                    // Warning when near limit
                    if isOverLimit {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text("Context limit reached")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentRed)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Warning: context limit reached")
                    } else if isNearLimit {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text("Approaching limit (\(Int(usageRatio * 100))%)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentAmber)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Warning: approaching context limit at \(Int(usageRatio * 100)) percent")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func segmentWidth(_ totalWidth: CGFloat, tokens: Int) -> CGFloat {
        guard contextLimit > 0 else { return 0 }
        return totalWidth * CGFloat(tokens) / CGFloat(contextLimit)
    }

    private var usageColor: Color {
        if isOverLimit { return AnvilColor.accentRed }
        if isNearLimit { return AnvilColor.accentAmber }
        return AnvilColor.textPrimary
    }

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: AnvilSpacing.xxxs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text("\(label): \(formatTokenCount(count))")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(formatTokenCount(count)) tokens")
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
