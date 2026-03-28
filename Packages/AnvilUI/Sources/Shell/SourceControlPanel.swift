import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit

// MARK: - ViewModel

@MainActor
final class SourceControlViewModel: ObservableObject {

    @Published var stagedFiles: [GitFileChange] = []
    @Published var unstagedFiles: [GitFileChange] = []
    @Published var untrackedFiles: [GitFileChange] = []
    @Published var isLoading = false
    @Published var commitMessage = ""
    @Published var syncError: String?
    @Published var isSyncing = false
    @Published var isAmend = false
    @Published var stashes: [Stash] = []
    @Published var isStashSectionExpanded = true
    @Published var stashMessage = ""
    @Published var tags: [Tag] = []
    @Published var isTagSectionExpanded = false
    @Published var newTagName = ""
    @Published var newTagMessage = ""
    @Published var recentCommits: [Commit] = []
    @Published var isHistorySectionExpanded = false
    @Published var actionError: String?
    @Published var isBranchPickerVisible = false
    @Published var branchSearchText = ""
    @Published var newBranchName = ""
    @Published var isCreatingBranch = false
    @Published var branchError: String?
    @Published var isGeneratingCommitMessage = false
    @Published var generateError: String?

    // MARK: - AI Commit Message

    func generateCommitMessage(using adapter: GitSourceControlAdapter, container: DependencyContainer) {
        guard !isGeneratingCommitMessage else { return }
        guard !stagedFiles.isEmpty else {
            generateError = "Stage changes first"
            return
        }
        isGeneratingCommitMessage = true
        generateError = nil
        Task { @MainActor in
            defer { isGeneratingCommitMessage = false }
            do {
                let diff = try await adapter.stagedDiff()
                guard !diff.isEmpty else {
                    generateError = "No staged diff to describe"
                    return
                }
                let client = await container.getOrCreateACPClient()
                guard let provider = await client.provider() else {
                    generateError = "No AI provider configured"
                    return
                }
                let diffText = Self.renderDiff(diff)
                let useCase = container.makeGenerateCommitMessageUseCase()
                let message = try await useCase.execute(diff: diffText, provider: provider)
                commitMessage = message
            } catch {
                generateError = error.localizedDescription
            }
        }
    }

    /// Convert structured FileDiff array into unified diff text for the AI prompt.
    static func renderDiff(_ diffs: [FileDiff]) -> String {
        diffs.map { file in
            let oldPath = file.oldPath ?? file.filePath
            var lines = ["--- a/\(oldPath)", "+++ b/\(file.filePath)"]
            for hunk in file.hunks {
                lines.append("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@")
                lines.append(contentsOf: hunk.lines.map { line in
                    switch line.type {
                    case .context: " \(line.content)"
                    case .added: "+\(line.content)"
                    case .removed: "-\(line.content)"
                    }
                })
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    // MARK: - Branch Operations

    func switchBranch(_ name: String, using adapter: GitSourceControlAdapter, appState: AppState) {
        branchError = nil
        Task { @MainActor in
            do {
                try await adapter.switchBranch(name: name)
                isBranchPickerVisible = false
                branchSearchText = ""
                refresh(using: adapter)
                await appState.loadGitStatus(from: adapter)
            } catch {
                branchError = "Switch failed: \(error.localizedDescription)"
            }
        }
    }

    func createBranch(using adapter: GitSourceControlAdapter, appState: AppState) {
        let name = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isCreatingBranch = true
        branchError = nil
        Task { @MainActor in
            defer { isCreatingBranch = false }
            do {
                _ = try await adapter.createBranch(name: name, from: nil)
                newBranchName = ""
                isBranchPickerVisible = false
                branchSearchText = ""
                refresh(using: adapter)
                await appState.loadGitStatus(from: adapter)
            } catch {
                branchError = "Create failed: \(error.localizedDescription)"
            }
        }
    }

    func deleteBranch(_ name: String, force: Bool, using adapter: GitSourceControlAdapter, appState: AppState) {
        branchError = nil
        Task { @MainActor in
            do {
                try await adapter.deleteBranch(name: name, force: force)
                await appState.loadGitStatus(from: adapter)
            } catch {
                branchError = "Delete failed: \(error.localizedDescription)"
            }
        }
    }

    var totalChangeCount: Int {
        stagedFiles.count + unstagedFiles.count + untrackedFiles.count
    }

    var canCommit: Bool {
        let hasMessage = !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isAmend { return hasMessage }
        return !stagedFiles.isEmpty && hasMessage
    }

    /// First line of the commit message (subject).
    var subjectLine: String {
        commitMessage.components(separatedBy: "\n").first ?? ""
    }

    // MARK: - Load

    func refresh(using adapter: GitSourceControlAdapter) {
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            if let changes = try? await adapter.workingTreeChanges() {
                stagedFiles = changes.staged
                unstagedFiles = changes.unstaged
                untrackedFiles = changes.untracked
            }
        }
    }

    // MARK: - Stage / Unstage

    func stageFile(_ file: GitFileChange, using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            try? await adapter.stage(paths: [file.filePath])
            refresh(using: adapter)
        }
    }

    func unstageFile(_ file: GitFileChange, using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            try? await adapter.unstage(paths: [file.filePath])
            refresh(using: adapter)
        }
    }

    func stageAll(using adapter: GitSourceControlAdapter) {
        let paths = (unstagedFiles + untrackedFiles).map(\.filePath)
        guard !paths.isEmpty else { return }
        Task { @MainActor in
            try? await adapter.stage(paths: paths)
            refresh(using: adapter)
        }
    }

    func unstageAll(using adapter: GitSourceControlAdapter) {
        let paths = stagedFiles.map(\.filePath)
        guard !paths.isEmpty else { return }
        Task { @MainActor in
            try? await adapter.unstage(paths: paths)
            refresh(using: adapter)
        }
    }

    // MARK: - Commit

    func commit(using adapter: GitSourceControlAdapter, appState: AppState) {
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCommit else { return }
        let amendFlag = isAmend
        Task { @MainActor in
            _ = try? await adapter.commit(message: message, amend: amendFlag)
            commitMessage = ""
            isAmend = false
            refresh(using: adapter)
            refreshHistory(using: adapter)
            await appState.loadGitStatus(from: adapter)
        }
    }

    // MARK: - Remote Sync

    func fetch(using adapter: GitSourceControlAdapter, appState: AppState) {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        Task { @MainActor in
            defer { isSyncing = false }
            do {
                try await adapter.fetch()
                await appState.loadGitStatus(from: adapter)
            } catch {
                syncError = "Fetch failed: \(error.localizedDescription)"
            }
        }
    }

    func pull(using adapter: GitSourceControlAdapter, appState: AppState) {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        Task { @MainActor in
            defer { isSyncing = false }
            do {
                try await adapter.pull()
                refresh(using: adapter)
                await appState.loadGitStatus(from: adapter)
            } catch {
                syncError = "Pull failed: \(error.localizedDescription)"
            }
        }
    }

    func push(using adapter: GitSourceControlAdapter, appState: AppState) {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        Task { @MainActor in
            defer { isSyncing = false }
            do {
                // Check if upstream is set; if not, set it
                let branch = try? await adapter.currentBranch()
                let needsUpstream = branch?.upstream == nil
                try await adapter.push(setUpstream: needsUpstream)
                await appState.loadGitStatus(from: adapter)
            } catch {
                syncError = "Push failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Stash

    func refreshStashes(using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            stashes = (try? await adapter.stashList()) ?? []
        }
    }

    func stashChanges(using adapter: GitSourceControlAdapter) {
        let msg = stashMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            try? await adapter.stash(message: msg.isEmpty ? nil : msg)
            stashMessage = ""
            refresh(using: adapter)
            refreshStashes(using: adapter)
        }
    }

    func popStash(using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            try? await adapter.stashPop()
            refresh(using: adapter)
            refreshStashes(using: adapter)
        }
    }

    func applyStash(index: Int, using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            _ = try? await adapter.stashApply(index: index)
            refresh(using: adapter)
        }
    }

    func dropStash(index: Int, using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            try? await adapter.stashDrop(index: index)
            refreshStashes(using: adapter)
        }
    }

    // MARK: - Tags

    func refreshTags(using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            tags = (try? await adapter.tags()) ?? []
        }
    }

    func createTag(using adapter: GitSourceControlAdapter) {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let msg = newTagMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            _ = try? await adapter.createTag(name: name, message: msg.isEmpty ? nil : msg)
            newTagName = ""
            newTagMessage = ""
            refreshTags(using: adapter)
        }
    }

    func deleteTag(_ name: String, using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            try? await adapter.deleteTag(name: name)
            refreshTags(using: adapter)
        }
    }

    // MARK: - History & Git Actions

    func refreshHistory(using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            recentCommits = (try? await adapter.commits(branch: "HEAD", limit: 10)) ?? []
        }
    }

    func cherryPick(_ commitHash: String, using adapter: GitSourceControlAdapter) {
        actionError = nil
        Task { @MainActor in
            do {
                try await adapter.cherryPick(commit: commitHash)
                refresh(using: adapter)
                refreshHistory(using: adapter)
            } catch {
                actionError = "Cherry-pick failed: \(error.localizedDescription)"
            }
        }
    }

    func revertCommit(_ commitHash: String, using adapter: GitSourceControlAdapter) {
        actionError = nil
        Task { @MainActor in
            do {
                try await adapter.revert(commit: commitHash)
                refresh(using: adapter)
                refreshHistory(using: adapter)
            } catch {
                actionError = "Revert failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Remotes

    @Published var remotes: [GitRemote] = []
    @Published var isRemoteSectionExpanded = false
    @Published var newRemoteName = ""
    @Published var newRemoteURL = ""
    @Published var remoteError: String?

    func refreshRemotes(using adapter: GitSourceControlAdapter) {
        Task { @MainActor in
            remotes = (try? await adapter.listRemotes()) ?? []
        }
    }

    func addRemote(using adapter: GitSourceControlAdapter) {
        let name = newRemoteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !url.isEmpty else { return }
        remoteError = nil
        Task { @MainActor in
            do {
                try await adapter.addRemote(name: name, url: url)
                newRemoteName = ""
                newRemoteURL = ""
                refreshRemotes(using: adapter)
            } catch {
                remoteError = "Add remote failed: \(error.localizedDescription)"
            }
        }
    }

    func removeRemote(_ name: String, using adapter: GitSourceControlAdapter) {
        remoteError = nil
        Task { @MainActor in
            do {
                try await adapter.removeRemote(name: name)
                refreshRemotes(using: adapter)
            } catch {
                remoteError = "Remove failed: \(error.localizedDescription)"
            }
        }
    }

    func renameRemote(oldName: String, newName: String, using adapter: GitSourceControlAdapter) {
        remoteError = nil
        Task { @MainActor in
            do {
                try await adapter.renameRemote(oldName: oldName, newName: newName)
                refreshRemotes(using: adapter)
            } catch {
                remoteError = "Rename failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - View

struct SourceControlPanel: View {
    @StateObject private var viewModel = SourceControlViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        VStack(spacing: 0) {
            // Header
            panelHeader

            Divider().overlay(AnvilColor.borderSubtle)

            // Commit message input
            commitInput

            Divider().overlay(AnvilColor.borderSubtle)

            // File lists
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    // Staged changes
                    if !viewModel.stagedFiles.isEmpty {
                        fileSection(
                            title: "STAGED CHANGES",
                            icon: "checkmark.circle",
                            files: viewModel.stagedFiles,
                            actionIcon: "minus",
                            actionHelp: "Unstage",
                            headerAction: ("Unstage All", {
                                guard let adapter = container.getOrCreateGitAdapter() else { return }
                                viewModel.unstageAll(using: adapter)
                            }),
                            fileAction: { file in
                                guard let adapter = container.getOrCreateGitAdapter() else { return }
                                viewModel.unstageFile(file, using: adapter)
                            }
                        )
                    }

                    // Unstaged changes
                    if !viewModel.unstagedFiles.isEmpty {
                        fileSection(
                            title: "CHANGES",
                            icon: "pencil.circle",
                            files: viewModel.unstagedFiles,
                            actionIcon: "plus",
                            actionHelp: "Stage",
                            headerAction: ("Stage All", {
                                guard let adapter = container.getOrCreateGitAdapter() else { return }
                                viewModel.stageAll(using: adapter)
                            }),
                            fileAction: { file in
                                guard let adapter = container.getOrCreateGitAdapter() else { return }
                                viewModel.stageFile(file, using: adapter)
                            }
                        )
                    }

                    // Untracked files
                    if !viewModel.untrackedFiles.isEmpty {
                        fileSection(
                            title: "UNTRACKED",
                            icon: "questionmark.circle",
                            files: viewModel.untrackedFiles,
                            actionIcon: "plus",
                            actionHelp: "Stage",
                            headerAction: ("Stage All", {
                                guard let adapter = container.getOrCreateGitAdapter() else { return }
                                viewModel.stageAll(using: adapter)
                            }),
                            fileAction: { file in
                                guard let adapter = container.getOrCreateGitAdapter() else { return }
                                viewModel.stageFile(file, using: adapter)
                            }
                        )
                    }

                    // Stash section
                    stashSection

                    // Tags section
                    tagSection

                    // History section (cherry-pick / revert)
                    historySection

                    // Remotes section
                    remoteSection

                    // Empty state
                    if viewModel.totalChangeCount == 0 && viewModel.stashes.isEmpty && !viewModel.isLoading {
                        VStack(spacing: AnvilSpacing.md) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 28, weight: .thin))
                                .foregroundStyle(AnvilColor.accentGreen)

                            Text("Working tree clean")
                                .font(AnvilFont.body)
                                .foregroundStyle(AnvilColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AnvilSpacing.xxl)
                    }
                }
            }
        }
        .background(AnvilColor.backgroundSecondary)
        .onAppear {
            guard let adapter = container.getOrCreateGitAdapter() else { return }
            viewModel.refresh(using: adapter)
            viewModel.refreshStashes(using: adapter)
            viewModel.refreshTags(using: adapter)
            viewModel.refreshHistory(using: adapter)
            viewModel.refreshRemotes(using: adapter)
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14))
                Text("Source Control")
                    .font(AnvilFont.sidebarHeader)

                Spacer()

                if viewModel.isLoading || viewModel.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    guard let adapter = container.getOrCreateGitAdapter() else { return }
                    viewModel.refresh(using: adapter)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .foregroundStyle(AnvilColor.textPrimary)
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            // Branch picker bar
            branchBar

            // Sync actions bar
            syncBar

            // Error banner
            if let error = viewModel.branchError ?? viewModel.syncError {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(error)
                        .font(AnvilFont.label)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        viewModel.syncError = nil
                        viewModel.branchError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(AnvilColor.accentRed)
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .background(AnvilColor.accentRed.opacity(0.1))
            }
        }
    }

    // MARK: - Branch Bar

    private var branchBar: some View {
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
            .popover(isPresented: $viewModel.isBranchPickerVisible, arrowEdge: .bottom) {
                branchPickerPopover
            }

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
    }

    private var branchPickerPopover: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textTertiary)
                TextField("Search or create branch...", text: $viewModel.branchSearchText)
                    .textFieldStyle(.plain)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
            }
            .padding(AnvilSpacing.sm)
            .background(AnvilColor.backgroundPrimary)

            Divider().overlay(AnvilColor.borderSubtle)

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

                Divider().overlay(AnvilColor.borderSubtle)
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
                        branchRow(branch)
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
        .background(AnvilColor.backgroundSecondary)
    }

    private func branchRow(_ branch: Branch) -> some View {
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
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(branch.isCurrent ? AnvilColor.accentGreen.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !branch.isCurrent else { return }
            guard let adapter = container.getOrCreateGitAdapter() else { return }
            viewModel.switchBranch(branch.name, using: adapter, appState: appState)
        }
    }

    // MARK: - Sync Bar

    private var syncBar: some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Ahead/behind indicator
            let currentBranch = appState.branches.first { $0.isCurrent }
            if let branch = currentBranch {
                if branch.aheadCount > 0 || branch.behindCount > 0 {
                    HStack(spacing: AnvilSpacing.xs) {
                        if branch.aheadCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 9, weight: .bold))
                                Text("\(branch.aheadCount)")
                                    .font(AnvilFont.label)
                            }
                            .foregroundStyle(AnvilColor.accentGreen)
                        }
                        if branch.behindCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                Text("\(branch.behindCount)")
                                    .font(AnvilFont.label)
                            }
                            .foregroundStyle(AnvilColor.accentBlue)
                        }
                    }
                }
            }

            Spacer()

            // Fetch
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.fetch(using: adapter, appState: appState)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11))
                    Text("Fetch")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Fetch from remote")
            .disabled(viewModel.isSyncing)

            // Pull
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.pull(using: adapter, appState: appState)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11))
                    Text("Pull")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Pull from remote")
            .disabled(viewModel.isSyncing)

            // Push
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.push(using: adapter, appState: appState)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 11))
                    Text("Push")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Push to remote")
            .disabled(viewModel.isSyncing)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundTertiary)
    }

    // MARK: - Commit Input

    private var commitInput: some View {
        VStack(spacing: AnvilSpacing.sm) {
            // Message input
            VStack(spacing: 0) {
                TextField(viewModel.isAmend ? "Amend commit message" : "Commit message", text: $viewModel.commitMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1...6)
                    .padding(AnvilSpacing.sm)
                    .onSubmit {
                        if viewModel.canCommit {
                            guard let adapter = container.getOrCreateGitAdapter() else { return }
                            viewModel.commit(using: adapter, appState: appState)
                        }
                    }

                // Subject line character count
                if !viewModel.commitMessage.isEmpty {
                    HStack {
                        Spacer()
                        let count = viewModel.subjectLine.count
                        Text("\(count)/50")
                            .font(AnvilFont.label)
                            .foregroundStyle(count > 72 ? AnvilColor.accentRed : count > 50 ? AnvilColor.accentAmber : AnvilColor.textTertiary)
                    }
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.bottom, AnvilSpacing.xs)
                }
            }
            .background(AnvilColor.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(viewModel.isAmend ? AnvilColor.accentAmber.opacity(0.5) : AnvilColor.borderSubtle, lineWidth: 1)
            )

            // Action row
            HStack(spacing: AnvilSpacing.sm) {
                // Staged count
                Text("\(viewModel.stagedFiles.count) staged")
                    .font(AnvilFont.label)
                    .foregroundStyle(
                        viewModel.stagedFiles.isEmpty
                            ? AnvilColor.textTertiary
                            : AnvilColor.accentGreen
                    )

                // Amend toggle
                Button {
                    viewModel.isAmend.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: viewModel.isAmend ? "checkmark.square.fill" : "square")
                            .font(.system(size: 10))
                        Text("Amend")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(viewModel.isAmend ? AnvilColor.accentAmber : AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Amend the previous commit")

                // AI generate commit message
                Button {
                    guard let adapter = container.getOrCreateGitAdapter() else { return }
                    viewModel.generateCommitMessage(using: adapter, container: container)
                } label: {
                    if viewModel.isGeneratingCommitMessage {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AnvilColor.textTertiary)
                .disabled(viewModel.stagedFiles.isEmpty || viewModel.isGeneratingCommitMessage)
                .opacity(viewModel.stagedFiles.isEmpty || viewModel.isGeneratingCommitMessage ? 0.4 : 1.0)
                .help("Generate commit message with AI")

                Spacer()

                // Commit button
                AnvilButton(
                    viewModel.isAmend ? "Amend" : "Commit",
                    icon: "checkmark",
                    style: .primary
                ) {
                    guard let adapter = container.getOrCreateGitAdapter() else { return }
                    viewModel.commit(using: adapter, appState: appState)
                }
                .disabled(!viewModel.canCommit)
                .opacity(viewModel.canCommit ? 1.0 : 0.5)
            }

            // AI generation error
            if let error = viewModel.generateError {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(error)
                        .font(AnvilFont.label)
                    Spacer()
                    Button {
                        viewModel.generateError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(AnvilColor.accentAmber)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - File Section

    private func fileSection(
        title: String,
        icon: String,
        files: [GitFileChange],
        actionIcon: String,
        actionHelp: String,
        headerAction: (String, () -> Void),
        fileAction: @escaping (GitFileChange) -> Void
    ) -> some View {
        Section {
            ForEach(files) { file in
                fileRow(file, actionIcon: actionIcon, actionHelp: actionHelp, action: { fileAction(file) })
            }
        } header: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)

                Text(title)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .tracking(0.3)

                Spacer()

                Text("\(files.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                Button {
                    headerAction.1()
                } label: {
                    Text(headerAction.0)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentBlue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)
        }
    }

    private func fileRow(
        _ file: GitFileChange,
        actionIcon: String,
        actionHelp: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Status indicator
            Text(file.status.rawValue)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor(file.status))
                .frame(width: 16)

            // File name + directory
            VStack(alignment: .leading, spacing: 0) {
                Text(file.fileName)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                if !file.directory.isEmpty {
                    Text(file.directory)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Stage/Unstage button
            Button(action: action) {
                Image(systemName: actionIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help(actionHelp)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: - History Section

    private var historySection: some View {
        Section {
            if viewModel.isHistorySectionExpanded {
                // Action error
                if let error = viewModel.actionError {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                        Text(error)
                            .font(AnvilFont.label)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            viewModel.actionError = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(AnvilColor.accentRed)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.accentRed.opacity(0.1))
                }

                if viewModel.recentCommits.isEmpty {
                    HStack {
                        Text("No commits")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(viewModel.recentCommits) { commit in
                        commitRow(commit)
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isHistorySectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isHistorySectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 10)

                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("HISTORY")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .tracking(0.3)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.recentCommits.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)
        }
    }

    private func commitRow(_ commit: Commit) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Commit hash
            Text(commit.shortHash)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AnvilColor.accentBlue.opacity(0.8))
                .frame(width: 50, alignment: .leading)

            // Message
            VStack(alignment: .leading, spacing: 0) {
                Text(commit.message)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AnvilSpacing.xs) {
                    Text(commit.author)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                    Text(commit.date, style: .relative)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }

            Spacer()

            // Cherry-pick button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.cherryPick(commit.id, using: adapter)
            } label: {
                Image(systemName: "cherry")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentPurple)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Cherry-pick this commit")

            // Revert button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.revertCommit(commit.id, using: adapter)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentAmber)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Revert this commit")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: - Remote Section

    private var remoteSection: some View {
        Section {
            if viewModel.isRemoteSectionExpanded {
                // Error banner
                if let error = viewModel.remoteError {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                        Text(error)
                            .font(AnvilFont.label)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            viewModel.remoteError = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(AnvilColor.accentRed)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.accentRed.opacity(0.1))
                }

                // Add remote form
                VStack(spacing: AnvilSpacing.xs) {
                    HStack(spacing: AnvilSpacing.sm) {
                        TextField("Name", text: $viewModel.newRemoteName)
                            .textFieldStyle(.plain)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .padding(.horizontal, AnvilSpacing.xs)
                            .padding(.vertical, 4)
                            .background(AnvilColor.backgroundPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                            )
                            .frame(width: 100)

                        TextField("URL", text: $viewModel.newRemoteURL)
                            .textFieldStyle(.plain)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .padding(.horizontal, AnvilSpacing.xs)
                            .padding(.vertical, 4)
                            .background(AnvilColor.backgroundPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                            )

                        Button {
                            guard let adapter = container.getOrCreateGitAdapter() else { return }
                            viewModel.addRemote(using: adapter)
                        } label: {
                            Text("Add")
                                .font(AnvilFont.label)
                                .foregroundStyle(
                                    viewModel.newRemoteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    viewModel.newRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? AnvilColor.textTertiary
                                        : AnvilColor.accentBlue
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)

                // Remote list
                if viewModel.remotes.isEmpty {
                    HStack {
                        Text("No remotes configured")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(viewModel.remotes) { remote in
                        remoteRow(remote)
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isRemoteSectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isRemoteSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 10)

                        Image(systemName: "network")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("REMOTES")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .tracking(0.3)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.remotes.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)
        }
    }

    private func remoteRow(_ remote: GitRemote) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "network")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentBlue)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(remote.name)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text(remote.fetchURL)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Remove button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.removeRemote(remote.name, using: adapter)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentRed)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Remove remote")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: - Tag Section

    private var tagSection: some View {
        Section {
            if viewModel.isTagSectionExpanded {
                // Create tag row
                VStack(spacing: AnvilSpacing.xs) {
                    HStack(spacing: AnvilSpacing.sm) {
                        TextField("Tag name", text: $viewModel.newTagName)
                            .textFieldStyle(.plain)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .padding(.horizontal, AnvilSpacing.xs)
                            .padding(.vertical, 4)
                            .background(AnvilColor.backgroundPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                            )

                        Button {
                            guard let adapter = container.getOrCreateGitAdapter() else { return }
                            viewModel.createTag(using: adapter)
                        } label: {
                            Text("Create")
                                .font(AnvilFont.label)
                                .foregroundStyle(
                                    viewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? AnvilColor.textTertiary
                                        : AnvilColor.accentBlue
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    TextField("Annotation (optional)", text: $viewModel.newTagMessage)
                        .textFieldStyle(.plain)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .padding(.horizontal, AnvilSpacing.xs)
                        .padding(.vertical, 3)
                        .background(AnvilColor.backgroundPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                        )
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)

                // Tag list
                if viewModel.tags.isEmpty {
                    HStack {
                        Text("No tags")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(viewModel.tags) { tag in
                        tagRow(tag)
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isTagSectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isTagSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 10)

                        Image(systemName: "tag")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("TAGS")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .tracking(0.3)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.tags.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: tag.annotation != nil ? "tag.fill" : "tag")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentAmber)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(tag.name)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AnvilSpacing.xs) {
                    Text(tag.targetCommit.prefix(7))
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentBlue.opacity(0.7))

                    if let annotation = tag.annotation, !annotation.isEmpty {
                        Text(annotation)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let date = tag.date {
                Text(date, style: .relative)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Delete button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.deleteTag(tag.name, using: adapter)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentRed)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Delete tag")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: - Stash Section

    private var stashSection: some View {
        Section {
            if viewModel.isStashSectionExpanded {
                // Stash current changes row
                if viewModel.totalChangeCount > 0 {
                    HStack(spacing: AnvilSpacing.sm) {
                        TextField("Stash message (optional)", text: $viewModel.stashMessage)
                            .textFieldStyle(.plain)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .padding(.horizontal, AnvilSpacing.xs)
                            .padding(.vertical, 4)
                            .background(AnvilColor.backgroundPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                            )

                        Button {
                            guard let adapter = container.getOrCreateGitAdapter() else { return }
                            viewModel.stashChanges(using: adapter)
                        } label: {
                            Text("Stash")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.accentBlue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                }

                // Stash list
                if viewModel.stashes.isEmpty {
                    HStack {
                        Text("No stashes")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(viewModel.stashes) { stash in
                        stashRow(stash)
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isStashSectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isStashSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 10)

                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("STASHES")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .tracking(0.3)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.stashes.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                if !viewModel.stashes.isEmpty {
                    Button {
                        guard let adapter = container.getOrCreateGitAdapter() else { return }
                        viewModel.popStash(using: adapter)
                    } label: {
                        Text("Pop")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentBlue)
                    }
                    .buttonStyle(.plain)
                    .help("Pop most recent stash")
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)
        }
    }

    private func stashRow(_ stash: Stash) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(stash.message.isEmpty ? "stash@{\(stash.index)}" : stash.message)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text(stash.date, style: .relative)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            // Apply button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.applyStash(index: stash.index, using: adapter)
            } label: {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Apply this stash")

            // Drop button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.dropStash(index: stash.index, using: adapter)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentRed)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Drop this stash")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func statusColor(_ status: GitFileChangeStatus) -> Color {
        switch status {
        case .modified: AnvilColor.accentAmber
        case .added:    AnvilColor.accentGreen
        case .deleted:  AnvilColor.accentRed
        case .renamed:  AnvilColor.accentBlue
        case .copied:   AnvilColor.accentTeal
        case .untracked: AnvilColor.textTertiary
        case .unmerged: AnvilColor.accentRed
        }
    }
}
