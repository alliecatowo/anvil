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

    var body: some View {
        VStack(spacing: 0) {
            // Search
            AnvilSearchField(text: $searchText, placeholder: "Filter branches...")

            Divider().overlay(AnvilColor.borderSubtle)

            // Branch list
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Current branch header
                    sectionHeader("CURRENT")

                    branchRow(name: appState.currentBranch, isCurrent: true)

                    // Other local branches
                    let otherBranches = filteredBranches.filter { !$0.isCurrent }
                    if !otherBranches.isEmpty {
                        sectionHeader("LOCAL BRANCHES")

                        ForEach(otherBranches) { branch in
                            branchRow(name: branch.name, isCurrent: false)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)

            Divider().overlay(AnvilColor.borderSubtle)

            // Create new branch
            if isCreatingBranch {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentGreen)

                    TextField("new-branch-name", text: $newBranchName)
                        .textFieldStyle(.plain)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textPrimary)
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
        .frame(width: 280)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AnvilColor.borderMedium, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
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

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)
            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary)
    }

    private func branchRow(name: String, isCurrent: Bool) -> some View {
        Button {
            if !isCurrent {
                switchToBranch(name)
            }
        } label: {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: isCurrent ? "checkmark.circle.fill" : "arrow.triangle.branch")
                    .font(.system(size: 12))
                    .foregroundStyle(isCurrent ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                    .frame(width: 16)

                Text(name)
                    .font(AnvilFont.code)
                    .foregroundStyle(isCurrent ? AnvilColor.accentGreen : AnvilColor.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .frame(height: AnvilSpacing.listItemHeight)
            .background(isCurrent ? AnvilColor.accentGreen.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
