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

                if viewModel.environments.count > 1 {
                    AnvilButton("Compare Environments", icon: "arrow.left.arrow.right", style: .secondary) {
                        viewModel.openEnvCompare()
                    }
                }

                if let env = viewModel.selectedEnvironment {
                    AnvilBadge(text: env.environment.name, color: AnvilColor.accentBlue)

                    Text("\(viewModel.envVarsForSelected.count) vars")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
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
                            Text("SECRET")
                                .frame(width: 60, alignment: .center)
                            Text("")
                                .frame(width: 80)
                        }
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .padding(.horizontal, AnvilSpacing.lg)
                        .padding(.vertical, AnvilSpacing.sm)
                        .background(AnvilColor.backgroundSecondary)

                        ForEach(viewModel.envVarsForSelected) { envVar in
                            if viewModel.editingEnvVarID == envVar.id {
                                editingRow(envVar, environmentID: envID)
                            } else {
                                envVarRow(envVar, environmentID: envID)
                            }
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
                                Text("Add variables using the form above")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.textTertiary)
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
        .alert("Delete Variable", isPresented: $viewModel.showingDeleteConfirm) {
            Button("Delete", role: .destructive) { viewModel.confirmDeleteEnvVar() }
            Button("Cancel", role: .cancel) { viewModel.cancelDeleteEnvVar() }
        } message: {
            if let varID = viewModel.pendingDeleteEnvVarID,
               let envID = viewModel.pendingDeleteEnvID,
               let envVar = viewModel.envVars[envID]?.first(where: { $0.id == varID }) {
                Text("Remove \(envVar.key) from this environment? This cannot be undone.")
            } else {
                Text("Are you sure you want to delete this variable?")
            }
        }
        .sheet(isPresented: $viewModel.showingEnvCompare) {
            envCompareSheet
        }
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

    // MARK: - Variable Row (read mode)

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
                    .textSelection(.enabled)
            }

            // Secret toggle
            Button {
                viewModel.toggleEnvVarSecret(id: envVar.id, in: environmentID)
            } label: {
                Image(systemName: envVar.isSecret ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(envVar.isSecret ? AnvilColor.accentAmber : AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .frame(width: 60, alignment: .center)

            // Actions
            HStack(spacing: AnvilSpacing.xs) {
                Button {
                    viewModel.startEditingEnvVar(envVar)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Edit variable")

                Button {
                    viewModel.requestDeleteEnvVar(id: envVar.id, from: environmentID)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentRed.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete variable")
            }
            .frame(width: 80)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
    }

    // MARK: - Variable Row (edit mode)

    private func editingRow(_ envVar: EnvVar, environmentID: String) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Key (editable)
            AnvilTextField("KEY", text: $viewModel.editingKey)
                .frame(width: 200)

            // Value (editable)
            AnvilTextField(envVar.isSecret ? "Enter new value..." : "Value", text: $viewModel.editingValue)

            // Placeholder for secret column
            Spacer()
                .frame(width: 60)

            // Save / Cancel
            HStack(spacing: AnvilSpacing.xs) {
                Button {
                    viewModel.saveEditingEnvVar(in: environmentID)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AnvilColor.accentGreen)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.cancelEditing()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AnvilColor.accentRed)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 80)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.accentBlue.opacity(0.05))
    }

    // MARK: - Env Compare Sheet

    private var envCompareSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Compare Environments")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                Button {
                    viewModel.showingEnvCompare = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(AnvilSpacing.lg)

            // Environment selectors
            HStack(spacing: AnvilSpacing.lg) {
                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("SOURCE")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                    Picker("Source", selection: Binding(
                        get: { viewModel.compareSourceID ?? "" },
                        set: { viewModel.compareSourceID = $0 }
                    )) {
                        ForEach(viewModel.environments) { env in
                            Text(env.environment.name).tag(env.id)
                        }
                    }
                    .labelsHidden()
                }

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(AnvilColor.textTertiary)

                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("TARGET")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                    Picker("Target", selection: Binding(
                        get: { viewModel.compareTargetID ?? "" },
                        set: { viewModel.compareTargetID = $0 }
                    )) {
                        ForEach(viewModel.environments) { env in
                            Text(env.environment.name).tag(env.id)
                        }
                    }
                    .labelsHidden()
                }

                Spacer()

                let diffCount = viewModel.envCompareData.filter(\.isDifferent).count
                Text("\(diffCount) difference\(diffCount == 1 ? "" : "s")")
                    .font(AnvilFont.label)
                    .foregroundStyle(diffCount > 0 ? AnvilColor.accentAmber : AnvilColor.accentGreen)
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.bottom, AnvilSpacing.md)

            Divider().overlay(AnvilColor.borderSubtle)

            // Compare table
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("KEY")
                            .frame(width: 200, alignment: .leading)
                        Text(sourceEnvName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(targetEnvName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(.horizontal, AnvilSpacing.lg)
                    .padding(.vertical, AnvilSpacing.sm)
                    .background(AnvilColor.backgroundSecondary)

                    ForEach(Array(viewModel.envCompareData.enumerated()), id: \.offset) { _, row in
                        compareRow(row)
                        Divider().overlay(AnvilColor.borderSubtle)
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(AnvilColor.backgroundPrimary)
    }

    private func compareRow(_ row: (key: String, sourceValue: String?, targetValue: String?, isDifferent: Bool)) -> some View {
        HStack {
            Text(row.key)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .frame(width: 200, alignment: .leading)

            Text(row.sourceValue ?? "--")
                .font(AnvilFont.code)
                .foregroundStyle(row.sourceValue == nil ? AnvilColor.textTertiary : AnvilColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .background(
                    row.isDifferent && row.sourceValue != nil
                        ? AnvilColor.diffRemovedBackground
                        : Color.clear
                )

            Text(row.targetValue ?? "--")
                .font(AnvilFont.code)
                .foregroundStyle(row.targetValue == nil ? AnvilColor.textTertiary : AnvilColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .background(
                    row.isDifferent && row.targetValue != nil
                        ? AnvilColor.diffAddedBackground
                        : Color.clear
                )
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(row.isDifferent ? AnvilColor.accentAmber.opacity(0.03) : AnvilColor.backgroundTertiary)
    }

    private var sourceEnvName: String {
        viewModel.environments.first(where: { $0.id == viewModel.compareSourceID })?.environment.name ?? "Source"
    }

    private var targetEnvName: String {
        viewModel.environments.first(where: { $0.id == viewModel.compareTargetID })?.environment.name ?? "Target"
    }
}
