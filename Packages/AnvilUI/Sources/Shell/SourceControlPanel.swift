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
            do {
                let changes = try await withTimeout(seconds: 5) {
                    try await adapter.workingTreeChanges()
                }
                stagedFiles = changes.staged
                unstagedFiles = changes.unstaged
                untrackedFiles = changes.untracked
            } catch {
                // Timeout or git error — just clear loading state
                syncError = "Could not load git status"
            }
        }
    }

    /// Run an async operation with a timeout.
    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CancellationError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
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

            Divider()

            // Commit message input
            commitInput

            Divider()

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
                    SCPStashSection(viewModel: viewModel)

                    // Tags section
                    SCPTagSection(viewModel: viewModel)

                    // History section (cherry-pick / revert)
                    SCPHistorySection(viewModel: viewModel)

                    // Remotes section
                    SCPRemoteSection(viewModel: viewModel)

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
        .background(.background)
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
            SCPBranchBar(viewModel: viewModel)

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
    }

    // MARK: - Commit Input

    private var commitInput: some View {
        VStack(spacing: AnvilSpacing.sm) {
            // Message input
            VStack(spacing: 0) {
                TextField(viewModel.isAmend ? "Amend commit message" : "Commit message", text: $viewModel.commitMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
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
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))

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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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
            .background(.background)
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
