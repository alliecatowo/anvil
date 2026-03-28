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
                // Deploy progress (if active)
                if viewModel.isDeploying, let envID = viewModel.deployingEnvironmentID {
                    HStack {
                        Spacer()
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

        return GroupBox {
            VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                // Header row: name + status badge
                HStack {
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxxs) {
                        Text(card.environment.name)
                            .font(AnvilFont.subheading)

                        Text(card.currentVersion)
                            .font(AnvilFont.code)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: AnvilSpacing.xxxs) {
                        Label(card.status.label, systemImage: "circle.fill")
                            .font(AnvilFont.label)
                            .foregroundStyle(card.status.color)
                            .accessibilityLabel("Status: \(card.status.label)")
                        Label(card.overallHealth.label, systemImage: card.overallHealth.icon)
                            .font(AnvilFont.label)
                            .foregroundStyle(card.overallHealth.color)
                            .accessibilityLabel("Health: \(card.overallHealth.label)")
                    }
                }

                // Branch + commit
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text(card.environment.branch ?? "--")
                        .font(AnvilFont.code)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("@")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Text(card.currentCommit)
                        .font(AnvilFont.code)
                        .foregroundStyle(.secondary)
                }

                // URL
                if let url = card.currentURL {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .accessibilityHidden(true)
                        Text(url)
                            .font(AnvilFont.code)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Last deploy time
                if let lastDeploy = card.lastDeployTime {
                    Text("Deployed \(relativeTime(lastDeploy))")
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                }

                // Action buttons
                HStack(spacing: AnvilSpacing.sm) {
                    Button("Deploy", systemImage: "arrow.up.circle") {
                        viewModel.deploy(environmentID: card.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Deploy to \(card.environment.name)")

                    Button("Logs", systemImage: "doc.text") {
                        viewModel.selectedEnvironmentID = card.id
                        viewModel.selectedTab = .logs
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(isSelected ? AnvilColor.accentBlue : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(card.environment.name), \(card.status.label), version \(card.currentVersion)")
        .accessibilityAddTraits(.isButton)
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
                    Label("Production", systemImage: "lock.shield")
                        .font(AnvilFont.label)
                        .foregroundStyle(.orange)
                }
            }

            AnvilCard {
                VStack(spacing: AnvilSpacing.sm) {
                    LabeledContent("Version", value: card.currentVersion)
                    LabeledContent("Commit", value: card.currentCommit)
                    LabeledContent("Branch", value: card.environment.branch ?? "--")
                    LabeledContent("Deployed", value: card.lastDeployTime.map(dateTimeFormatter.string(from:)) ?? "--")
                    LabeledContent("Status") {
                        Label(card.status.label, systemImage: "circle.fill")
                            .foregroundStyle(card.status.color)
                    }
                    LabeledContent("Health") {
                        Label(card.overallHealth.label, systemImage: card.overallHealth.icon)
                            .foregroundStyle(card.overallHealth.color)
                    }
                }
                .font(AnvilFont.label)
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
        GroupBox {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: check.status.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(check.status.color)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AnvilSpacing.xxxs) {
                    Text(check.name)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    Text("\(check.responseTime)ms")
                        .font(AnvilFont.code)
                        .foregroundStyle(check.responseTime > 100 ? AnvilColor.accentAmber : .secondary)
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(check.name), \(check.status.label), \(check.responseTime) milliseconds")
    }

    // MARK: - Deploy History

    private var deployHistorySection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Deploy History")
                .font(AnvilFont.subheading)
                .foregroundStyle(AnvilColor.textPrimary)

            Table(viewModel.deployHistoryForSelected) {
                TableColumn("Version") { entry in
                    Text(entry.version)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentPurple)
                }
                TableColumn("Commit") { entry in
                    Text(entry.deployment.commitHash ?? "--")
                        .font(AnvilFont.code)
                }
                TableColumn("Status") { entry in
                    Label(entry.deployment.status.rawValue.capitalized, systemImage: "circle.fill")
                        .font(AnvilFont.label)
                        .foregroundStyle(statusColor(entry.deployment.status))
                }
                TableColumn("Triggered By") { entry in
                    Text(entry.triggeredBy)
                        .font(AnvilFont.label)
                }
                TableColumn("Branch") { entry in
                    Text(entry.branch)
                        .font(AnvilFont.code)
                        .lineLimit(1)
                }
                TableColumn("Duration") { entry in
                    Text(entry.duration > 0 ? entry.durationString : "--")
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                }
                TableColumn("Time") { entry in
                    Text(dateTimeFormatter.string(from: entry.deployment.createdAt))
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                }
                TableColumn("Action") { entry in
                    if entry.deployment.status == .ready,
                       entry.id != viewModel.deployHistoryForSelected.first?.id {
                        Button("Rollback") {
                            if let envID = viewModel.selectedEnvironmentID {
                                viewModel.requestRollback(deploymentID: entry.id, environmentID: envID)
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    // MARK: - Recent Deployments (all environments)

    private var recentDeploymentsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Recent Deployments")
                .font(AnvilFont.subheading)
                .foregroundStyle(AnvilColor.textPrimary)

            Table(Array(viewModel.deployments.prefix(10))) {
                TableColumn("Commit") { deployment in
                    Text(deployment.commitHash ?? "--")
                        .font(AnvilFont.code)
                }
                TableColumn("Status") { deployment in
                    Label(deployment.status.rawValue.capitalized, systemImage: "circle.fill")
                        .font(AnvilFont.label)
                        .foregroundStyle(statusColor(deployment.status))
                }
                TableColumn("Environment") { deployment in
                    Text(environmentName(for: deployment.environmentId))
                        .font(AnvilFont.label)
                }
                TableColumn("Time") { deployment in
                    Text(dateTimeFormatter.string(from: deployment.createdAt))
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
