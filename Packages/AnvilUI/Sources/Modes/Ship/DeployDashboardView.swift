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

    private let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.xl) {
                // Header
                HStack {
                    Text("Deploy Dashboard")
                        .font(AnvilFont.heading)
                        .foregroundStyle(AnvilColor.textPrimary)

                    Spacer()

                    if viewModel.isDeploying, let envID = viewModel.deployingEnvironmentID {
                        deployProgressIndicator(envID: envID)
                    }
                }

                // Environment cards grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AnvilSpacing.lg) {
                    ForEach(viewModel.environments) { card in
                        environmentCard(card)
                    }
                }

                // Selected environment detail
                if let selected = viewModel.selectedEnvironment {
                    currentDeploymentSection(selected)
                    healthChecksSection(selected)
                }

                // Deploy history
                if !viewModel.deployHistoryForSelected.isEmpty {
                    deployHistorySection
                }

                // Recent deployments table (all environments)
                if viewModel.selectedEnvironmentID == nil, !viewModel.deployments.isEmpty {
                    recentDeploymentsSection
                }
            }
            .padding(AnvilSpacing.xl)
        }
        .background(AnvilColor.backgroundPrimary)
        .alert("Confirm Rollback", isPresented: $viewModel.showingRollbackConfirm) {
            Button("Rollback", role: .destructive) { viewModel.confirmRollback() }
            Button("Cancel", role: .cancel) { viewModel.cancelRollback() }
        } message: {
            if let deployID = viewModel.pendingRollbackDeployID,
               let envID = viewModel.pendingRollbackEnvID,
               let entry = viewModel.deployHistory[envID]?.first(where: { $0.id == deployID }) {
                Text("Roll back \(environmentName(for: envID)) to \(entry.version) (commit \(entry.deployment.commitHash ?? "unknown"))?")
            } else {
                Text("Are you sure you want to rollback?")
            }
        }
    }

    // MARK: - Deploy Progress

    private func deployProgressIndicator(envID: String) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            AnvilLoadingIndicator(size: 14)

            Text("Deploying to \(environmentName(for: envID))...")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.accentAmber)

            ProgressView(value: viewModel.deployProgress)
                .progressViewStyle(.linear)
                .frame(width: 120)
                .tint(AnvilColor.accentAmber)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.accentAmber.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Environment Card

    private func environmentCard(_ card: EnvironmentCard) -> some View {
        let isSelected = viewModel.selectedEnvironmentID == card.id

        return AnvilCard {
            VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                // Header row: name + status badge
                HStack {
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxxs) {
                        Text(card.environment.name)
                            .font(AnvilFont.subheading)
                            .foregroundStyle(AnvilColor.textPrimary)

                        Text(card.currentVersion)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.accentPurple)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: AnvilSpacing.xxxs) {
                        AnvilBadge(text: card.status.label, color: card.status.color)
                        AnvilBadge(text: card.overallHealth.label, color: card.overallHealth.color)
                    }
                }

                // Branch + commit
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.textTertiary)

                    Text(card.environment.branch ?? "--")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .lineLimit(1)

                    Text("@")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Text(card.currentCommit)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentBlue)
                }

                // URL
                if let url = card.currentURL {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text(url)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.accentBlue)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Last deploy time
                if let lastDeploy = card.lastDeployTime {
                    Text("Deployed \(relativeTime(lastDeploy))")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                // Action buttons
                HStack(spacing: AnvilSpacing.sm) {
                    AnvilButton("Deploy", icon: "arrow.up.circle", style: .primary) {
                        viewModel.deploy(environmentID: card.id)
                    }

                    AnvilButton("Logs", icon: "doc.text", style: .secondary) {
                        viewModel.selectedEnvironmentID = card.id
                        viewModel.selectedTab = .logs
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(isSelected ? AnvilColor.accentBlue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            withAnimation(AnvilAnimation.standard) {
                viewModel.selectedEnvironmentID = card.id
            }
        }
    }

    // MARK: - Current Deployment Info

    private func currentDeploymentSection(_ card: EnvironmentCard) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            HStack {
                Text("Current Deployment")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                if card.environment.isProduction {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AnvilColor.accentAmber)
                        Text("Production")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentAmber)
                    }
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, AnvilSpacing.xxxs)
                    .background(AnvilColor.accentAmber.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            AnvilCard {
                HStack(spacing: AnvilSpacing.xxl) {
                    // Version
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                        Text("VERSION")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text(card.currentVersion)
                            .font(AnvilFont.subheading)
                            .foregroundStyle(AnvilColor.accentPurple)
                    }

                    Divider().frame(height: 40).overlay(AnvilColor.borderSubtle)

                    // Commit
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                        Text("COMMIT")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text(card.currentCommit)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                    }

                    Divider().frame(height: 40).overlay(AnvilColor.borderSubtle)

                    // Branch
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                        Text("BRANCH")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text(card.environment.branch ?? "--")
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                    }

                    Divider().frame(height: 40).overlay(AnvilColor.borderSubtle)

                    // Deploy Time
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                        Text("DEPLOYED")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        if let time = card.lastDeployTime {
                            Text(dateTimeFormatter.string(from: time))
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textPrimary)
                        } else {
                            Text("--")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textTertiary)
                        }
                    }

                    Divider().frame(height: 40).overlay(AnvilColor.borderSubtle)

                    // Status
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                        Text("STATUS")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        HStack(spacing: AnvilSpacing.xxs) {
                            Circle()
                                .fill(card.status.color)
                                .frame(width: 8, height: 8)
                            Text(card.status.label)
                                .font(AnvilFont.label)
                                .foregroundStyle(card.status.color)
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Health Checks

    private func healthChecksSection(_ card: EnvironmentCard) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            HStack {
                Text("Health Checks")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: card.overallHealth.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(card.overallHealth.color)
                    Text(card.overallHealth.label)
                        .font(AnvilFont.label)
                        .foregroundStyle(card.overallHealth.color)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AnvilSpacing.md) {
                ForEach(card.healthChecks) { check in
                    healthCheckCard(check)
                }
            }
        }
    }

    private func healthCheckCard(_ check: HealthCheck) -> some View {
        AnvilCard {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: check.status.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(check.status.color)

                VStack(alignment: .leading, spacing: AnvilSpacing.xxxs) {
                    Text(check.name)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    Text("\(check.responseTime)ms")
                        .font(AnvilFont.code)
                        .foregroundStyle(check.responseTime > 100 ? AnvilColor.accentAmber : AnvilColor.textSecondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Deploy History

    private var deployHistorySection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Deploy History")
                .font(AnvilFont.subheading)
                .foregroundStyle(AnvilColor.textPrimary)

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("VERSION")
                        .frame(width: 120, alignment: .leading)
                    Text("COMMIT")
                        .frame(width: 80, alignment: .leading)
                    Text("STATUS")
                        .frame(width: 90, alignment: .leading)
                    Text("TRIGGERED BY")
                        .frame(width: 140, alignment: .leading)
                    Text("BRANCH")
                        .frame(width: 120, alignment: .leading)
                    Text("DURATION")
                        .frame(width: 80, alignment: .leading)
                    Text("TIME")
                        .frame(width: 140, alignment: .leading)
                    Text("")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
                .background(AnvilColor.backgroundSecondary)

                ForEach(viewModel.deployHistoryForSelected) { entry in
                    deployHistoryRow(entry)
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

    private func deployHistoryRow(_ entry: DeployHistoryEntry) -> some View {
        HStack {
            Text(entry.version)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.accentPurple)
                .frame(width: 120, alignment: .leading)

            Text(entry.deployment.commitHash ?? "--")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .frame(width: 80, alignment: .leading)

            HStack(spacing: AnvilSpacing.xxs) {
                Circle()
                    .fill(statusColor(entry.deployment.status))
                    .frame(width: 6, height: 6)
                Text(entry.deployment.status.rawValue.capitalized)
                    .font(AnvilFont.label)
                    .foregroundStyle(statusColor(entry.deployment.status))
            }
            .frame(width: 90, alignment: .leading)

            Text(entry.triggeredBy)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(entry.branch)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textSecondary)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text(entry.duration > 0 ? entry.durationString : "--")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 80, alignment: .leading)

            Text(dateTimeFormatter.string(from: entry.deployment.createdAt))
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 140, alignment: .leading)

            // Rollback button -- only for completed deploys that are not the current one
            if entry.deployment.status == .ready,
               entry.id != viewModel.deployHistoryForSelected.first?.id {
                Button {
                    if let envID = viewModel.selectedEnvironmentID {
                        viewModel.requestRollback(deploymentID: entry.id, environmentID: envID)
                    }
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                        Text("Rollback")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentAmber)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, AnvilSpacing.xxxs)
                    .background(AnvilColor.accentAmber.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(width: 80, alignment: .trailing)
            } else {
                Spacer()
                    .frame(width: 80)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
    }

    // MARK: - Recent Deployments (all environments)

    private var recentDeploymentsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Recent Deployments")
                .font(AnvilFont.subheading)
                .foregroundStyle(AnvilColor.textPrimary)

            VStack(spacing: 0) {
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

                ForEach(viewModel.deployments.prefix(10)) { deployment in
                    allEnvDeploymentRow(deployment)
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

    private func allEnvDeploymentRow(_ deployment: Deployment) -> some View {
        HStack {
            Text(deployment.commitHash ?? "--")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .frame(width: 100, alignment: .leading)

            HStack(spacing: AnvilSpacing.xxs) {
                Circle()
                    .fill(statusColor(deployment.status))
                    .frame(width: 6, height: 6)
                Text(deployment.status.rawValue.capitalized)
                    .font(AnvilFont.label)
                    .foregroundStyle(statusColor(deployment.status))
            }
            .frame(width: 100, alignment: .leading)

            Text(environmentName(for: deployment.environmentId))
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .frame(width: 120, alignment: .leading)

            Text(dateTimeFormatter.string(from: deployment.createdAt))
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

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
