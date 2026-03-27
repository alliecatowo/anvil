import SwiftUI
import AnvilDomain

struct DeployDashboardView: View {
    @ObservedObject var viewModel: ShipViewModel

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.xl) {
                // Header
                Text("Deploy Dashboard")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)

                // Environment cards grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AnvilSpacing.lg) {
                    ForEach(viewModel.environments) { card in
                        environmentCard(card)
                    }
                }

                // Recent deployments table
                if !viewModel.deploymentsForSelected.isEmpty {
                    recentDeploymentsSection
                }
            }
            .padding(AnvilSpacing.xl)
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Environment Card

    private func environmentCard(_ card: EnvironmentCard) -> some View {
        AnvilCard {
            VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                // Header row: name + status badge
                HStack {
                    Text(card.environment.name)
                        .font(AnvilFont.subheading)
                        .foregroundStyle(AnvilColor.textPrimary)

                    Spacer()

                    AnvilBadge(text: card.status.label, color: card.status.color)
                }

                // Status indicator dot + branch
                HStack(spacing: AnvilSpacing.xs) {
                    Circle()
                        .fill(card.status.color)
                        .frame(width: 8, height: 8)

                    Text(card.environment.branch ?? "—")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .lineLimit(1)
                }

                // URL
                if let url = card.currentURL {
                    Text(url)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentBlue)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Last deploy time
                if let lastDeploy = card.lastDeployTime {
                    Text("Last deploy: \(timeFormatter.string(from: lastDeploy))")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                // Action buttons
                HStack(spacing: AnvilSpacing.sm) {
                    AnvilButton("Deploy", icon: "arrow.up.circle", style: .primary) {
                        viewModel.deploy(environmentID: card.id)
                    }

                    AnvilButton("Rollback", icon: "arrow.uturn.backward", style: .secondary) {
                        if let deployment = viewModel.deployments.first(where: { $0.environmentId == card.id }) {
                            viewModel.rollback(deploymentID: deployment.id)
                        }
                    }
                }
            }
        }
        .onTapGesture {
            viewModel.selectedEnvironmentID = card.id
        }
    }

    // MARK: - Recent Deployments

    private var recentDeploymentsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Recent Deployments")
                .font(AnvilFont.subheading)
                .foregroundStyle(AnvilColor.textPrimary)

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("COMMIT")
                        .frame(width: 100, alignment: .leading)
                    Text("STATUS")
                        .frame(width: 100, alignment: .leading)
                    Text("ENVIRONMENT")
                        .frame(width: 120, alignment: .leading)
                    Text("TIME")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
                .background(AnvilColor.backgroundSecondary)

                // Rows
                ForEach(viewModel.deployments) { deployment in
                    deploymentTableRow(deployment)

                    Divider().overlay(AnvilColor.borderSubtle)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                    .stroke(AnvilColor.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func deploymentTableRow(_ deployment: Deployment) -> some View {
        HStack {
            // Commit
            Text(deployment.commitHash ?? "—")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .frame(width: 100, alignment: .leading)

            // Status
            HStack(spacing: AnvilSpacing.xxs) {
                Circle()
                    .fill(statusColor(deployment.status))
                    .frame(width: 6, height: 6)
                Text(deployment.status.rawValue.capitalized)
                    .font(AnvilFont.label)
                    .foregroundStyle(statusColor(deployment.status))
            }
            .frame(width: 100, alignment: .leading)

            // Environment
            Text(environmentName(for: deployment.environmentId))
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .frame(width: 120, alignment: .leading)

            // Time
            Text(timeFormatter.string(from: deployment.createdAt))
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
    }

    // MARK: - Helpers

    private func statusColor(_ status: DeploymentStatus) -> Color {
        switch status {
        case .ready: AnvilColor.accentGreen
        case .building, .deploying, .queued: AnvilColor.accentAmber
        case .failed: AnvilColor.accentRed
        case .cancelled: AnvilColor.textTertiary
        }
    }

    private func environmentName(for id: String) -> String {
        viewModel.environments.first { $0.id == id }?.environment.name ?? id
    }
}
