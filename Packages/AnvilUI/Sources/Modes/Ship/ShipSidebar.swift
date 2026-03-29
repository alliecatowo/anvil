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

            if viewModel.isDeploying, viewModel.deployingEnvironmentID != nil {
                Section {
                    sidebarDeployProgress()
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
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
    }

    // MARK: - Sidebar Deploy Progress

    private func sidebarDeployProgress() -> some View {
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
}
