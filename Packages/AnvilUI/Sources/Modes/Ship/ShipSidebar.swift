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
        .scrollContentBackground(.hidden)
    }

    private func environmentRow(_ card: EnvironmentCard) -> some View {
        AnvilSidebarRowButton(
            title: card.environment.name,
            icon: environmentIcon(card.status),
            subtitle: "\(card.currentVersion) \u{2022} \(card.environment.branch ?? "--")",
            isActive: viewModel.selectedEnvironmentID == card.id
        ) {
            viewModel.selectedEnvironmentID = card.id
        } trailing: {
            AnvilBadge(text: card.overallHealth.label, color: card.overallHealth.color)
        }
        .accessibilityLabel("\(card.environment.name), \(card.status.label), \(card.currentVersion)")
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
