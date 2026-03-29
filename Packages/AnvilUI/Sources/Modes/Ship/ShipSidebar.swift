import SwiftUI
import AnvilDomain

struct ShipSidebar: View {
    @ObservedObject var viewModel: ShipViewModel

    var body: some View {
        List {
            AnvilSidebarSection(title: "Environments", icon: "server.rack", count: viewModel.environments.count) {
                ForEach(viewModel.environments) { env in
                    environmentRow(env)
                }
            }

            if !viewModel.deploymentsForSelected.isEmpty {
                AnvilSidebarSection(title: "Deployments", icon: "arrow.up.circle", count: viewModel.deploymentsForSelected.count) {
                    ForEach(viewModel.deploymentsForSelected.prefix(10)) { deployment in
                        deploymentRow(deployment)
                    }
                }
            }

            if viewModel.isDeploying, let envID = viewModel.deployingEnvironmentID {
                Section {
                    sidebarDeployProgress(envID: envID)
                } header: {
                    AnvilSidebarSectionHeader(
                        title: "Deploying",
                        icon: "arrow.triangle.2.circlepath",
                        count: nil
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func environmentRow(_ card: EnvironmentCard) -> some View {
        VStack(spacing: AnvilSpacing.xxs) {
            Button {
                viewModel.selectedEnvironmentID = card.id
            } label: {
                AnvilListItem(
                    icon: environmentIcon(card.status),
                    title: card.environment.name,
                    subtitle: "\(card.currentVersion) • \(card.environment.branch ?? "--")",
                    tag: card.overallHealth.label,
                    tagColor: card.overallHealth.color,
                    isSelected: viewModel.selectedEnvironmentID == card.id,
                    isCompact: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(card.environment.name), \(card.status.label), \(card.currentVersion)")

            if viewModel.selectedEnvironmentID == card.id {
                HStack(spacing: AnvilSpacing.sm) {
                    Button("Deploy") {
                        viewModel.deploy(environmentID: card.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isDeploying)
                    .accessibilityLabel("Deploy to \(card.environment.name)")

                    Button("Logs") {
                        viewModel.selectedTab = .logs
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    if let lastDeploy = card.lastDeployTime {
                        Text(relativeTime(lastDeploy))
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
    }

    private func deploymentRow(_ deployment: Deployment) -> some View {
        AnvilListItem(
            icon: deploymentIcon(deployment.status),
            title: deployment.commitHash ?? "unknown",
            subtitle: deploymentSubtitle(deployment),
            tag: deployment.status.rawValue.capitalized,
            tagColor: deploymentColor(deployment.status),
            timestamp: relativeTime(deployment.createdAt),
            isCompact: false
        )
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

    private func deploymentSubtitle(_ deployment: Deployment) -> String? {
        guard let envID = viewModel.selectedEnvironmentID,
              let entry = viewModel.deployHistory[envID]?.first(where: { $0.id == deployment.id }) else {
            return nil
        }
        return entry.version
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
