import SwiftUI
import AnvilDomain
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

    var totalChangeCount: Int {
        stagedFiles.count + unstagedFiles.count + untrackedFiles.count
    }

    var canCommit: Bool {
        !stagedFiles.isEmpty && !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        guard !message.isEmpty, !stagedFiles.isEmpty else { return }
        Task { @MainActor in
            _ = try? await adapter.commit(message: message)
            commitMessage = ""
            refresh(using: adapter)
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

            // Sync actions bar
            syncBar

            // Error banner
            if let error = viewModel.syncError {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(error)
                        .font(AnvilFont.label)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        viewModel.syncError = nil
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
        .background(AnvilColor.backgroundTertiary)
    }

    // MARK: - Commit Input

    private var commitInput: some View {
        VStack(spacing: AnvilSpacing.sm) {
            TextField("Commit message", text: $viewModel.commitMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1...4)
                .padding(AnvilSpacing.sm)
                .background(AnvilColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                )

            HStack {
                Text("\(viewModel.stagedFiles.count) staged")
                    .font(AnvilFont.label)
                    .foregroundStyle(
                        viewModel.stagedFiles.isEmpty
                            ? AnvilColor.textTertiary
                            : AnvilColor.accentGreen
                    )

                Spacer()

                AnvilButton("Commit", icon: "checkmark", style: .primary) {
                    guard let adapter = container.getOrCreateGitAdapter() else { return }
                    viewModel.commit(using: adapter, appState: appState)
                }
                .opacity(viewModel.canCommit ? 1.0 : 0.5)
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
