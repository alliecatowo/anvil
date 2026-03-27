import SwiftUI
import AnvilDomain

struct ShipSidebar: View {
    @ObservedObject var viewModel: ShipViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            tabSelector

            Divider().overlay(AnvilColor.borderSubtle)

            // Environment list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    Section {
                        ForEach(viewModel.environments) { env in
                            environmentRow(env)
                        }
                    } header: {
                        sectionHeader("Environments", icon: "server.rack", count: viewModel.environments.count)
                    }

                    if !viewModel.deploymentsForSelected.isEmpty {
                        Section {
                            ForEach(viewModel.deploymentsForSelected) { deployment in
                                deploymentRow(deployment)
                            }
                        } header: {
                            sectionHeader("Deployments", icon: "arrow.up.circle", count: viewModel.deploymentsForSelected.count)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ShipTab.allCases, id: \.rawValue) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(AnvilFont.label)
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? AnvilColor.textPrimary
                                : AnvilColor.textTertiary
                        )
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

    // MARK: - Environment Row

    private func environmentRow(_ card: EnvironmentCard) -> some View {
        AnvilListItem(
            icon: environmentIcon(card.status),
            title: card.environment.name,
            subtitle: card.environment.branch,
            tag: card.status.label,
            tagColor: card.status.color,
            isSelected: viewModel.selectedEnvironmentID == card.id,
            isCompact: false
        )
        .onTapGesture {
            viewModel.selectedEnvironmentID = card.id
        }
    }

    // MARK: - Deployment Row

    private func deploymentRow(_ deployment: Deployment) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: deploymentIcon(deployment.status))
                .font(.system(size: 12))
                .foregroundStyle(deploymentColor(deployment.status))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(deployment.commitHash ?? "unknown")
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text(deployment.status.rawValue.capitalized)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
            }

            Spacer()

            Text(relativeTime(deployment.createdAt))
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: AnvilSpacing.richListItemHeight)
        .contentShape(Rectangle())
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(AnvilColor.textTertiary)

            Text(title.uppercased())
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .tracking(0.3)

            Spacer()

            Text("\(count)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Helpers

    private func environmentIcon(_ status: EnvironmentDeployStatus) -> String {
        switch status {
        case .live: "checkmark.circle.fill"
        case .deploying: "arrow.triangle.2.circlepath"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private func deploymentIcon(_ status: DeploymentStatus) -> String {
        switch status {
        case .queued: "clock"
        case .building: "hammer"
        case .deploying: "arrow.up.circle"
        case .ready: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "minus.circle"
        }
    }

    private func deploymentColor(_ status: DeploymentStatus) -> Color {
        switch status {
        case .queued: AnvilColor.textTertiary
        case .building, .deploying: AnvilColor.accentAmber
        case .ready: AnvilColor.accentGreen
        case .failed: AnvilColor.accentRed
        case .cancelled: AnvilColor.textTertiary
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
