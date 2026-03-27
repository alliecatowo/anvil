import SwiftUI
import AnvilDomain

struct EnvVarManagerView: View {
    @ObservedObject var viewModel: ShipViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Environment Variables")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                if let env = viewModel.selectedEnvironment {
                    AnvilBadge(text: env.environment.name, color: AnvilColor.accentBlue)
                }
            }
            .padding(AnvilSpacing.lg)

            Divider().overlay(AnvilColor.borderSubtle)

            if let envID = viewModel.selectedEnvironmentID {
                // Add new var form
                addVariableForm(environmentID: envID)

                Divider().overlay(AnvilColor.borderSubtle)

                // Variable list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header row
                        HStack {
                            Text("KEY")
                                .frame(width: 200, alignment: .leading)
                            Text("VALUE")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("")
                                .frame(width: 60)
                        }
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .padding(.horizontal, AnvilSpacing.lg)
                        .padding(.vertical, AnvilSpacing.sm)
                        .background(AnvilColor.backgroundSecondary)

                        ForEach(viewModel.envVarsForSelected) { envVar in
                            envVarRow(envVar, environmentID: envID)
                            Divider().overlay(AnvilColor.borderSubtle)
                        }

                        if viewModel.envVarsForSelected.isEmpty {
                            VStack(spacing: AnvilSpacing.sm) {
                                Image(systemName: "key")
                                    .font(.system(size: 24, weight: .thin))
                                    .foregroundStyle(AnvilColor.textTertiary)
                                Text("No environment variables")
                                    .font(AnvilFont.body)
                                    .foregroundStyle(AnvilColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AnvilSpacing.xxxl)
                        }
                    }
                }
            } else {
                // No environment selected
                VStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(AnvilColor.textTertiary)
                    Text("Select an environment to manage variables")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Add Variable Form

    private func addVariableForm(environmentID: String) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            AnvilTextField("KEY", text: $viewModel.newEnvKey)
                .frame(width: 200)

            AnvilTextField("Value", text: $viewModel.newEnvValue)

            Toggle("Secret", isOn: $viewModel.newEnvIsSecret)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .toggleStyle(.switch)
                .controlSize(.small)

            AnvilButton("Add", icon: "plus", style: .primary) {
                viewModel.addEnvVar(to: environmentID)
            }
        }
        .padding(AnvilSpacing.lg)
    }

    // MARK: - Variable Row

    private func envVarRow(_ envVar: EnvVar, environmentID: String) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Key
            Text(envVar.key)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .frame(width: 200, alignment: .leading)
                .lineLimit(1)

            // Value (masked if secret)
            if envVar.isSecret {
                HStack(spacing: AnvilSpacing.xxs) {
                    Text(String(repeating: "\u{2022}", count: 12))
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.accentAmber)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(envVar.value)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }

            // Actions
            HStack(spacing: AnvilSpacing.xs) {
                Button {
                    // Edit stub
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.deleteEnvVar(id: envVar.id, from: environmentID)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentRed.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 60)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
    }
}
