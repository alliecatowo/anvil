import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit

// MARK: - Branch Bar

struct SCPBranchBar: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Button {
                viewModel.isBranchPickerVisible.toggle()
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text(appState.currentBranch)
                        .font(AnvilFont.code)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(AnvilColor.accentBlue)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, 4)
                .background(AnvilColor.accentBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current branch: \(appState.currentBranch)")
            .accessibilityAddTraits(.isButton)
            .popover(isPresented: $viewModel.isBranchPickerVisible, arrowEdge: .bottom) {
                SCPBranchPickerPopover(viewModel: viewModel)
            }

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
    }
}

// MARK: - Branch Picker Popover

struct SCPBranchPickerPopover: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textTertiary)
                TextField("Search or create branch...", text: $viewModel.branchSearchText)
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.code)
            }
            .padding(AnvilSpacing.sm)

            Divider()

            // Create branch option (shows when search text doesn't match existing)
            let trimmed = viewModel.branchSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let exactMatch = appState.branches.contains { $0.name == trimmed }
            if !trimmed.isEmpty && !exactMatch {
                Button {
                    viewModel.newBranchName = trimmed
                    guard let adapter = container.getOrCreateGitAdapter() else { return }
                    viewModel.createBranch(using: adapter, appState: appState)
                } label: {
                    HStack(spacing: AnvilSpacing.sm) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(AnvilColor.accentGreen)
                        Text("Create branch \"\(trimmed)\"")
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                        Spacer()
                        if viewModel.isCreatingBranch {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
            }

            // Branch list
            ScrollView {
                LazyVStack(spacing: 0) {
                    let filtered: [Branch] = {
                        let query = trimmed.lowercased()
                        if query.isEmpty { return appState.branches }
                        return appState.branches.filter { $0.name.lowercased().contains(query) }
                    }()

                    ForEach(filtered) { branch in
                        SCPBranchRow(viewModel: viewModel, branch: branch)
                    }

                    if filtered.isEmpty {
                        Text("No matching branches")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                            .padding(AnvilSpacing.md)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 320)
    }
}

// MARK: - Branch Row

struct SCPBranchRow: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    let branch: Branch

    var body: some View {
        Button {
            guard !branch.isCurrent else { return }
            guard let adapter = container.getOrCreateGitAdapter() else { return }
            viewModel.switchBranch(branch.name, using: adapter, appState: appState)
        } label: {
            HStack(spacing: AnvilSpacing.sm) {
                if branch.isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AnvilColor.accentGreen)
                        .frame(width: 14)
                } else {
                    Color.clear.frame(width: 14, height: 1)
                }

                Text(branch.name)
                    .font(AnvilFont.code)
                    .foregroundStyle(branch.isCurrent ? AnvilColor.accentGreen : AnvilColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                if let msg = branch.lastCommitMessage {
                    Text(msg)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)
                        .frame(maxWidth: 120, alignment: .trailing)
                }

                if !branch.isCurrent {
                    Button {
                        guard let adapter = container.getOrCreateGitAdapter() else { return }
                        viewModel.deleteBranch(branch.name, force: false, using: adapter, appState: appState)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundStyle(AnvilColor.accentRed.opacity(0.6))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Delete branch")
                    .accessibilityLabel("Delete branch \(branch.name)")
                    .accessibilityAddTraits(.isButton)
                    .allowsHitTesting(true)
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(branch.isCurrent ? AnvilColor.accentGreen.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Branch \(branch.name)\(branch.isCurrent ? ", current" : "")")
        .accessibilityAddTraits(branch.isCurrent ? .isStaticText : .isButton)
    }
}
