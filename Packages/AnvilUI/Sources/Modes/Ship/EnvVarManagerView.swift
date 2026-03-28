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
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(AnvilSpacing.lg)

            Divider()

            if let envID = viewModel.selectedEnvironmentID {
                // Add new var form
                addVariableForm(environmentID: envID)

                Divider()

                // Variable list
                List {
                    ForEach(viewModel.envVarsForSelected) { envVar in
                        if viewModel.editingEnvVarID == envVar.id {
                            editingRow(envVar, environmentID: envID)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        } else {
                            envVarRow(envVar, environmentID: envID)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        }
                    }

                    if viewModel.envVarsForSelected.isEmpty {
                        VStack(spacing: AnvilSpacing.sm) {
                            Image(systemName: "key")
                                .font(.system(size: 24, weight: .thin))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                            Text("No environment variables")
                                .font(AnvilFont.body)
                                .foregroundStyle(.secondary)
                            Text("Add variables using the form above")
                                .font(AnvilFont.label)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AnvilSpacing.xxxl)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.inset)
            } else {
                // No environment selected
                VStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text("Select an environment to manage variables")
                        .font(AnvilFont.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.background)
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
                .accessibilityLabel("Variable key")

            AnvilTextField("Value", text: $viewModel.newEnvValue)
                .accessibilityLabel("Variable value")

            Toggle("Secret", isOn: $viewModel.newEnvIsSecret)
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel("Mark as secret")
                .accessibilityAddTraits(.isButton)

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
                .frame(width: 200, alignment: .leading)
                .lineLimit(1)

            // Value (masked if secret)
            if envVar.isSecret {
                HStack(spacing: AnvilSpacing.xxs) {
                    Text(String(repeating: "\u{2022}", count: 12))
                        .font(AnvilFont.code)
                        .foregroundStyle(.tertiary)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.accentAmber)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(envVar.value)
                    .font(AnvilFont.code)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(envVar.isSecret ? AnvilColor.accentAmber : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 60, alignment: .center)
            .accessibilityLabel(envVar.isSecret ? "Show value" : "Hide value")
            .accessibilityAddTraits(.isButton)

            // Actions
            HStack(spacing: AnvilSpacing.xs) {
                Button {
                    viewModel.startEditingEnvVar(envVar)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Edit variable")
                .accessibilityLabel("Edit \(envVar.key)")
                .accessibilityAddTraits(.isButton)

                Button {
                    viewModel.requestDeleteEnvVar(id: envVar.id, from: environmentID)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentRed.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete variable")
                .accessibilityLabel("Delete \(envVar.key)")
                .accessibilityAddTraits(.isButton)
            }
            .frame(width: 80)
        }
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
                .accessibilityLabel("Save variable")
                .accessibilityAddTraits(.isButton)

                Button {
                    viewModel.cancelEditing()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AnvilColor.accentRed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel editing")
                .accessibilityAddTraits(.isButton)
            }
            .frame(width: 80)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - Env Compare Sheet

    private var envCompareSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Compare Environments")
                    .font(AnvilFont.heading)

                Spacer()

                Button {
                    viewModel.showingEnvCompare = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close comparison")
                .accessibilityAddTraits(.isButton)
            }
            .padding(AnvilSpacing.lg)

            // Environment selectors
            HStack(spacing: AnvilSpacing.lg) {
                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("SOURCE")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                    Picker("Source", selection: Binding(
                        get: { viewModel.compareSourceID ?? "" },
                        set: { viewModel.compareSourceID = $0 }
                    )) {
                        ForEach(viewModel.environments) { env in
                            Text(env.environment.name).tag(env.id)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Source environment")
                }

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("TARGET")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                    Picker("Target", selection: Binding(
                        get: { viewModel.compareTargetID ?? "" },
                        set: { viewModel.compareTargetID = $0 }
                    )) {
                        ForEach(viewModel.environments) { env in
                            Text(env.environment.name).tag(env.id)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Target environment")
                }

                Spacer()

                let diffCount = viewModel.envCompareData.filter(\.isDifferent).count
                Text("\(diffCount) difference\(diffCount == 1 ? "" : "s")")
                    .font(AnvilFont.label)
                    .foregroundStyle(diffCount > 0 ? AnvilColor.accentAmber : AnvilColor.accentGreen)
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.bottom, AnvilSpacing.md)

            Divider()

            // Compare table
            List {
                ForEach(Array(viewModel.envCompareData.enumerated()), id: \.offset) { _, row in
                    compareRow(row)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(.background)
    }

    private func compareRow(_ row: (key: String, sourceValue: String?, targetValue: String?, isDifferent: Bool)) -> some View {
        HStack {
            Text(row.key)
                .font(AnvilFont.code)
                .frame(width: 200, alignment: .leading)

            Text(row.sourceValue ?? "--")
                .font(AnvilFont.code)
                .foregroundStyle(row.sourceValue == nil ? .tertiary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .background(
                    row.isDifferent && row.sourceValue != nil
                        ? AnvilColor.diffRemovedBackground
                        : Color.clear
                )

            Text(row.targetValue ?? "--")
                .font(AnvilFont.code)
                .foregroundStyle(row.targetValue == nil ? .tertiary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .background(
                    row.isDifferent && row.targetValue != nil
                        ? AnvilColor.diffAddedBackground
                        : Color.clear
                )
        }
    }

    private var sourceEnvName: String {
        viewModel.environments.first(where: { $0.id == viewModel.compareSourceID })?.environment.name ?? "Source"
    }

    private var targetEnvName: String {
        viewModel.environments.first(where: { $0.id == viewModel.compareTargetID })?.environment.name ?? "Target"
    }
}
