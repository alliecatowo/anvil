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
                            ForEach(viewModel.deploymentsForSelected.prefix(10)) { deployment in
                                deploymentRow(deployment)
                            }
                        } header: {
                            sectionHeader("Deployments", icon: "arrow.up.circle", count: viewModel.deploymentsForSelected.count)
                        }
                    }
                }
            }

            Spacer()

            // Deploy progress at bottom of sidebar
            if viewModel.isDeploying, let envID = viewModel.deployingEnvironmentID {
                Divider().overlay(AnvilColor.borderSubtle)
                sidebarDeployProgress(envID: envID)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ShipTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.selectedTab = tab
                    }
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
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xs)
    }

    // MARK: - Environment Row

    private func environmentRow(_ card: EnvironmentCard) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AnvilSpacing.sm) {
                if viewModel.selectedEnvironmentID == card.id {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AnvilColor.accentBlue)
                        .frame(width: 3)
                }

                // Status icon
                Image(systemName: environmentIcon(card.status))
                    .font(.system(size: 14))
                    .foregroundStyle(card.status.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(card.environment.name)
                            .font(AnvilFont.sidebarItem)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        AnvilBadge(text: card.status.label, color: card.status.color)
                    }

                    HStack(spacing: AnvilSpacing.xs) {
                        // Version
                        Text(card.currentVersion)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.accentPurple)

                        Text("|")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)

                        // Branch
                        Text(card.environment.branch ?? "--")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        // Health dot
                        Image(systemName: card.overallHealth.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(card.overallHealth.color)
                    }
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .frame(minHeight: AnvilSpacing.richListItemHeight)
            .background(viewModel.selectedEnvironmentID == card.id ? AnvilColor.selectionBackground : .clear)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(AnvilAnimation.standard) {
                    viewModel.selectedEnvironmentID = card.id
                }
            }

            // Deploy button row (shown when selected)
            if viewModel.selectedEnvironmentID == card.id {
                HStack(spacing: AnvilSpacing.sm) {
                    Button {
                        viewModel.deploy(environmentID: card.id)
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 10))
                            Text("Deploy")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AnvilSpacing.xxs)
                        .background(AnvilColor.accentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isDeploying)

                    if let lastDeploy = card.lastDeployTime {
                        Text(relativeTime(lastDeploy))
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
                .padding(.horizontal, AnvilSpacing.lg)
                .padding(.bottom, AnvilSpacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
                HStack(spacing: AnvilSpacing.xxs) {
                    Text(deployment.commitHash ?? "unknown")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    // Find version from history
                    if let envID = viewModel.selectedEnvironmentID,
                       let entry = viewModel.deployHistory[envID]?.first(where: { $0.id == deployment.id }) {
                        Text(entry.version)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentPurple)
                    }
                }

                Text(deployment.status.rawValue.capitalized)
                    .font(AnvilFont.label)
                    .foregroundStyle(deploymentColor(deployment.status))
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

    // MARK: - Sidebar Deploy Progress

    private func sidebarDeployProgress(envID: String) -> some View {
        VStack(spacing: AnvilSpacing.xs) {
            HStack(spacing: AnvilSpacing.sm) {
                AnvilLoadingIndicator(size: 12)

                Text("Deploying...")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.accentAmber)

                Spacer()

                Text("\(Int(viewModel.deployProgress * 100))%")
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.accentAmber)
            }

            ProgressView(value: viewModel.deployProgress)
                .progressViewStyle(.linear)
                .tint(AnvilColor.accentAmber)
        }
        .padding(AnvilSpacing.md)
        .background(AnvilColor.accentAmber.opacity(0.05))
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
