import SwiftUI
import AnvilDomain

struct ShipSidebar: View {
    @ObservedObject var viewModel: ShipViewModel

    var body: some View {
        VStack(spacing: 0) {
            tabSelector

            Divider()

            List {
                Section {
                    ForEach(viewModel.environments) { env in
                        environmentRow(env)
                    }
                } header: {
                    sectionHeader(overviewSections[0])
                }

                if !viewModel.deploymentsForSelected.isEmpty {
                    Section {
                        ForEach(viewModel.deploymentsForSelected.prefix(10)) { deployment in
                            deploymentRow(deployment)
                        }
                    } header: {
                        sectionHeader(overviewSections[1])
                    }
                }
            }
            .listStyle(.sidebar)

            Spacer()

            if viewModel.isDeploying, let envID = viewModel.deployingEnvironmentID {
                Divider()
                sidebarDeployProgress(envID: envID)
            }
        }
    }

    private struct SidebarSectionDescriptor: Identifiable {
        let id: String
        let title: String
        let icon: String
        let count: Int
    }

    // Minimal adapter target for upcoming shared sidebar abstraction.
    private var overviewSections: [SidebarSectionDescriptor] {
        [
            SidebarSectionDescriptor(id: "environments", title: "Environments", icon: "server.rack", count: viewModel.environments.count),
            SidebarSectionDescriptor(id: "deployments", title: "Deployments", icon: "arrow.up.circle", count: viewModel.deploymentsForSelected.count)
        ]
    }

    private var tabSelector: some View {
        Picker("Ship View", selection: $viewModel.selectedTab) {
            ForEach(ShipTab.allCases, id: \.rawValue) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xs)
    }

    private func environmentRow(_ card: EnvironmentCard) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: environmentIcon(card.status))
                    .foregroundStyle(card.status.color)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.environment.name)
                        .font(AnvilFont.sidebarItem)
                        .lineLimit(1)
                    Text("\(card.currentVersion) • \(card.environment.branch ?? "--")")
                        .font(AnvilFont.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Label(card.overallHealth.label, systemImage: card.overallHealth.icon)
                    .font(AnvilFont.label)
                    .foregroundStyle(card.overallHealth.color)
                    .accessibilityLabel("Health: \(card.overallHealth.label)")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(card.environment.name), \(card.status.label), \(card.currentVersion)")
            .accessibilityAddTraits(.isButton)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedEnvironmentID = card.id
            }

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
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(viewModel.selectedEnvironmentID == card.id ? AnvilColor.selectionBackground : .clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
    }

    private func deploymentRow(_ deployment: Deployment) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Label("", systemImage: deploymentIcon(deployment.status))
                .labelStyle(.iconOnly)
                .foregroundStyle(deploymentColor(deployment.status))
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AnvilSpacing.xxs) {
                    Text(deployment.commitHash ?? "unknown")
                        .font(AnvilFont.code)
                        .lineLimit(1)

                    // Find version from history
                    if let envID = viewModel.selectedEnvironmentID,
                       let entry = viewModel.deployHistory[envID]?.first(where: { $0.id == deployment.id }) {
                        Text(entry.version)
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
                    }
                }

                Label(deployment.status.rawValue.capitalized, systemImage: deploymentIcon(deployment.status))
                    .font(AnvilFont.label)
                    .labelStyle(.titleOnly)
                    .foregroundStyle(deploymentColor(deployment.status))
            }

            Spacer()

            Text(relativeTime(deployment.createdAt))
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(deployment.commitHash ?? "unknown"), \(deployment.status.rawValue), \(relativeTime(deployment.createdAt))")
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: AnvilSpacing.richListItemHeight)
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
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

    private func sectionHeader(_ descriptor: SidebarSectionDescriptor) -> some View {
        HStack {
            Image(systemName: descriptor.icon)
                .font(.system(size: 10))
                .foregroundStyle(AnvilColor.textTertiary)

            Text(descriptor.title)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            Spacer()

            Text("\(descriptor.count)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .textCase(nil)
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
