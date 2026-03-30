import SwiftUI
import AnvilDomain

/// A popover-style branch picker for switching git branches.
struct BranchPicker: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var isCreatingBranch = false
    @State private var newBranchName = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Search
            AnvilSearchField(text: $searchText, placeholder: "Filter branches...")

            Divider()

            // Branch list
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if appState.branches.isEmpty {
                // Empty state
                VStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text("No branches found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Open a project to see branches.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List {
                    Section("Current") {
                        branchRow(branch: filteredBranches.first(where: { $0.isCurrent }))
                    }

                    let otherBranches = filteredBranches.filter { !$0.isCurrent }
                    if !otherBranches.isEmpty {
                        Section("Local branches") {
                            ForEach(otherBranches) { branch in
                                branchRow(branch: branch)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxHeight: 300)
            }

            Divider()

            // Create new branch
            if isCreatingBranch {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentGreen)

                    TextField("new-branch-name", text: $newBranchName)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.code)
                        .onSubmit {
                            createBranch()
                        }

                    Button {
                        createBranch()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AnvilColor.accentGreen)
                    }
                    .buttonStyle(.plain)
                    .disabled(newBranchName.isEmpty)

                    Button {
                        isCreatingBranch = false
                        newBranchName = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
            } else {
                Button {
                    isCreatingBranch = true
                } label: {
                    HStack(spacing: AnvilSpacing.sm) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                        Text("New Branch")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 320)
        .task {
            isLoading = true
            if let adapter = container.getOrCreateGitAdapter() {
                await appState.loadGitStatus(from: adapter)
            }
            isLoading = false
        }
    }

    // MARK: - Computed

    private var filteredBranches: [Branch] {
        if searchText.isEmpty {
            return appState.branches
        }
        let query = searchText.lowercased()
        return appState.branches.filter { $0.name.lowercased().contains(query) }
    }

    // MARK: - Actions

    private func switchToBranch(_ name: String) {
        guard let adapter = container.getOrCreateGitAdapter() else { return }
        Task {
            await appState.switchBranch(name, using: adapter)
            isPresented = false
        }
    }

    private func createBranch() {
        let name = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard let adapter = container.getOrCreateGitAdapter() else { return }
        Task {
            await appState.createBranch(name, using: adapter)
            isCreatingBranch = false
            newBranchName = ""
            isPresented = false
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func branchRow(branch: Branch?) -> some View {
        if let branch {
            let isCurrent = branch.isCurrent
            Button {
                if !isCurrent {
                    switchToBranch(branch.name)
                }
            } label: {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: isCurrent ? "checkmark.circle.fill" : "arrow.triangle.branch")
                        .font(.system(size: 12))
                        .foregroundStyle(isCurrent ? .green : .secondary)
                        .frame(width: 16)

                    Text(branch.name)
                        .font(AnvilFont.code)
                        .foregroundStyle(isCurrent ? .green : .primary)
                        .lineLimit(1)

                    Spacer()

                    if branch.aheadCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(branch.aheadCount)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.12), in: Capsule())
                    }

                    if branch.behindCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(branch.behindCount)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .frame(height: AnvilSpacing.listItemHeight)
                .background(isCurrent ? Color.green.opacity(0.08) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
