import SwiftUI
import AnvilDomain

struct ObservabilityMode: View {
    @StateObject private var viewModel = ObservabilityViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Left panel: error feed
            VStack(spacing: 0) {
                tabSelector
                Divider().overlay(AnvilColor.borderSubtle)
                errorFeedOrMetrics
            }
            .frame(width: 480)
            .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Right panel: detail or metrics dashboard
            Group {
                switch viewModel.selectedTab {
                case .errors:
                    if let selected = viewModel.selectedError {
                        ErrorDetailView(error: selected)
                    } else {
                        noSelectionPlaceholder
                    }
                case .metrics:
                    MetricsDashboard(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ObservabilityTab.allCases, id: \.rawValue) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    HStack(spacing: AnvilSpacing.xs) {
                        Text(tab.rawValue)
                            .font(AnvilFont.label)
                            .foregroundStyle(
                                viewModel.selectedTab == tab
                                    ? AnvilColor.textPrimary
                                    : AnvilColor.textTertiary
                            )

                        if tab == .errors && viewModel.criticalCount > 0 {
                            AnvilBadge(
                                text: "\(viewModel.criticalCount)",
                                color: AnvilColor.accentRed
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AnvilSpacing.sm)
                    .background(
                        viewModel.selectedTab == tab
                            ? AnvilColor.backgroundTertiary
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xs)
    }

    // MARK: - Conditional Content

    @ViewBuilder
    private var errorFeedOrMetrics: some View {
        switch viewModel.selectedTab {
        case .errors:
            ErrorFeed(viewModel: viewModel)
        case .metrics:
            // Show a summary list in the left panel when metrics tab is active
            metricsQuickList
        }
    }

    private var metricsQuickList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.metrics) { metric in
                    HStack(spacing: AnvilSpacing.sm) {
                        Image(systemName: metric.trend.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(metric.trend.color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                                .font(AnvilFont.sidebarItem)
                                .foregroundStyle(AnvilColor.textPrimary)
                            Text(metric.value)
                                .font(AnvilFont.code)
                                .foregroundStyle(AnvilColor.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.sm)
                    .frame(height: AnvilSpacing.richListItemHeight)

                    Divider().overlay(AnvilColor.borderSubtle)
                }
            }
        }
    }

    private var noSelectionPlaceholder: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)

            Text("Select an error to view details")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
        }
    }
}
