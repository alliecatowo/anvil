import SwiftUI
import AnvilDomain
import AnvilGit
import AnvilGitHub

struct ReviewSidebar: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    private var totalChangesCount: Int {
        appState.stagedChanges.count + appState.unstagedChanges.count + appState.untrackedChanges.count
    }

    private var conflictCount: Int {
        viewModel.mergeConflicts.count
    }

    var body: some View {
        VStack(spacing: 0) {
            gitHubAuthBar
            Divider()
            reviewActionsBar
            Divider()

            List {
                if let review = viewModel.selectedReview {
                    selectedReviewSection(for: review)
                }

                branchSection
                remotesSection
                tagsSection
                stashesSection
                worktreesSection
                changesSection
                pullRequestsSection
                pendingReviewsSection
                completedReviewsSection
            }
            .listStyle(.sidebar)
            .task {
                viewModel.loadReviews()
                if let adapter = container.getOrCreateGitAdapter() {
                    viewModel.loadSourceControlData(using: adapter)
                    await appState.loadGitStatus(from: adapter)
                }
            }
        }
    }

    // MARK: - Branch Section

    private var branchSection: some View {
        AnvilSidebarDisclosureSection(
            title: "Branches",
            icon: "arrow.triangle.branch",
            count: localBranches.count,
            isExpanded: $isBranchesExpanded,
            content: {
                if appState.branches.isEmpty {
                    HStack {
                        Text("No branches loaded")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(localBranches) { branch in
                        branchRow(branch)
                    }
                }
            },
            trailing: {
                Button {
                    viewModel.isCommitGraphVisible.toggle()
                } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 11))
                        .foregroundStyle(
                            viewModel.isCommitGraphVisible ? AnvilColor.accentBlue : AnvilColor.textTertiary
                        )
                }
                .buttonStyle(.plain)
                .help(viewModel.isCommitGraphVisible ? "Hide Commit Graph" : "Show Commit Graph")
            }
        )
    }

    private var localBranches: [Branch] {
        appState.branches.filter { !$0.name.contains("/") }
    }

    private func branchRow(_ branch: Branch) -> some View {
        AnvilSidebarRowButton(
            title: branch.name,
            icon: branch.isCurrent ? "checkmark" : "arrow.triangle.branch",
            isActive: viewModel.selectedBranchName == branch.name,
            action: {
                guard !branch.isCurrent else {
                    appState.gitOperationResult = .success("Already on \(branch.name). Choose another branch or use Start Review.")
                    return
                }
                appState.gitHubPRViewModel.clearSelection()
                if let adapter = container.getOrCreateGitAdapter() {
                    viewModel.loadBranchDiff(branch.name, using: adapter)
                } else {
                    viewModel.selectedBranchName = branch.name
                }
            },
            trailing: {
                HStack(spacing: AnvilSpacing.xs) {
                    if branch.aheadCount > 0 {
                        Text("+\(branch.aheadCount)")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentGreen)
                    }
                    if branch.behindCount > 0 {
                        Text("-\(branch.behindCount)")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentRed)
                    }
                }
            }
        )
        .accessibilityLabel("Branch \(branch.name)\(branch.isCurrent ? ", current" : "")")
    }

    // MARK: - Remotes Section

    private var remotesSection: some View {
        AnvilSidebarDisclosureSection(
            title: "Remotes",
            icon: "globe",
            count: viewModel.remotes.count,
            isExpanded: $isRemotesExpanded,
            content: {
                if viewModel.remotes.isEmpty {
                    emptySectionLabel("No remotes")
                } else {
                    ForEach(viewModel.remotes, id: \.name) { remote in
                        remoteRow(remote)
                    }
                }
            }
        )
    }

    private func remoteRow(_ remote: GitRemote) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                Text(remote.name)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(remote.fetchURL.components(separatedBy: "/").suffix(2).joined(separator: "/").replacingOccurrences(of: ".git", with: ""))
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .padding(.vertical, 2)

            // Show tracking branches for this remote
            let remoteBranches = appState.branches.filter { $0.name.hasPrefix("\(remote.name)/") }
            if !remoteBranches.isEmpty {
                ForEach(remoteBranches) { branch in
                    HStack(spacing: AnvilSpacing.sm) {
                        Color.clear.frame(width: 16)
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 14)
                            .accessibilityHidden(true)
                        Text(branch.name.replacingOccurrences(of: "\(remote.name)/", with: ""))
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, 2)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        AnvilSidebarDisclosureSection(
            title: "Tags",
            icon: "tag",
            count: viewModel.tags.count,
            isExpanded: $isTagsExpanded,
            content: {
                if viewModel.tags.isEmpty {
                    emptySectionLabel("No tags")
                } else {
                    ForEach(viewModel.tags, id: \.name) { tag in
                        tagRow(tag)
                    }
                }
            }
        )
    }

    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "tag")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentAmber)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(tag.name)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Spacer()

            if let annotation = tag.annotation, !annotation.isEmpty {
                Text(annotation)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tag \(tag.name)\(tag.annotation.map { ", \($0)" } ?? "")")
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .padding(.vertical, 2)
    }

    // MARK: - Stashes Section

    private var stashesSection: some View {
        AnvilSidebarDisclosureSection(
            title: "Stashes",
            icon: "tray.and.arrow.down",
            count: viewModel.stashes.count,
            isExpanded: $isStashesExpanded,
            content: {
                if viewModel.stashes.isEmpty {
                    emptySectionLabel("No stashes")
                } else {
                    ForEach(viewModel.stashes, id: \.id) { stash in
                        stashRow(stash)
                    }
                }
            }
        )
    }

    private func stashRow(_ stash: Stash) -> some View {
        AnvilSidebarRowButton(
            title: stash.message,
            icon: "tray.and.arrow.down",
            subtitle: Self.relativeStashDate(stash.date),
            action: {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.applyStash(index: stash.index, using: adapter)
            }
        )
        .accessibilityLabel("Stash: \(stash.message)")
        .contextMenu {
            Button("Apply") {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.applyStash(index: stash.index, using: adapter)
            }
            Button("Pop") {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.popStash(using: adapter)
            }
            Divider()
            Button("Drop", role: .destructive) {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.dropStash(index: stash.index, using: adapter)
            }
        }
    }

    private static func relativeStashDate(_ date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return "\(Int(interval / 604800))w ago"
    }

    // MARK: - Worktrees Section

    private var worktreesSection: some View {
        AnvilSidebarDisclosureSection(
            title: "Worktrees",
            icon: "folder.badge.gearshape",
            count: viewModel.worktrees.count,
            isExpanded: $isWorktreesExpanded,
            content: {
                if viewModel.worktrees.isEmpty {
                    emptySectionLabel("No worktrees")
                } else {
                    ForEach(viewModel.worktrees) { wt in
                        worktreeRow(wt)
                    }
                }
            },
            trailing: {
                Button {
                    viewModel.newWorktreeBranch = ""
                    viewModel.isAddWorktreeSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Add Worktree")
            }
        )
        .sheet(isPresented: $viewModel.isAddWorktreeSheetPresented) {
            addWorktreeSheet
        }
    }

    private func worktreeRow(_ wt: Worktree) -> some View {
        AnvilSidebarRowButton(
            title: wt.branch ?? "detached",
            icon: wt.isMain ? "folder.fill" : "folder.badge.gearshape",
            subtitle: {
                var parts: [String] = []
                if let sha = wt.headSHA {
                    parts.append(String(sha.prefix(7)))
                }
                parts.append((wt.path as NSString).lastPathComponent)
                return parts.joined(separator: " ")
            }(),
            isActive: appState.currentProjectPath == wt.path,
            action: {
                activateWorktree(wt)
            },
            trailing: {
                if wt.isMain {
                    AnvilBadge(text: "main", color: AnvilColor.accentGreen)
                }
            }
        )
        .accessibilityLabel("Worktree \(wt.branch ?? "detached") at \(wt.path)")
        .contextMenu {
            Button("Open in New Window") {
                if let url = URL(string: "anvil://open?path=\(wt.path)") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(wt.path, forType: .string)
            }
            if !wt.isMain {
                Divider()
                Button("Remove Worktree", role: .destructive) {
                    guard let adapter = container.getOrCreateGitAdapter() else { return }
                    viewModel.removeWorktree(path: wt.path, using: adapter)
                }
            }
        }
    }

    private func activateWorktree(_ worktree: Worktree) {
        if appState.currentProjectPath == worktree.path {
            appState.gitOperationResult = .success("Already using worktree \(worktree.branch ?? "detached").")
            return
        }

        // Keep both app and container project scopes aligned before refreshing git/review state.
        container.currentProjectPath = worktree.path
        appState.currentProjectPath = worktree.path
        appState.gitHubPRViewModel.clearSelection()
        viewModel.clearBranchDiff()

        guard let adapter = container.getOrCreateGitAdapter() else {
            appState.gitOperationResult = .failure("Could not open git adapter for \(worktree.path).")
            return
        }

        Task {
            await appState.loadGitStatus(from: adapter)
            await MainActor.run {
                viewModel.loadSourceControlData(using: adapter)
                viewModel.loadReviews()
                appState.gitOperationResult = .success("Switched to worktree \(worktree.branch ?? "detached").")
            }
        }
    }

    private var addWorktreeSheet: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Text("Add Worktree")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                Text("Branch name")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)

                Picker("Branch", selection: $viewModel.newWorktreeBranch) {
                    Text("Select a branch...").tag("")
                    ForEach(appState.branches.filter({ !$0.isCurrent })) { branch in
                        Text(branch.name).tag(branch.name)
                    }
                }
                .labelsHidden()
            }

            HStack {
                Button("Cancel") {
                    viewModel.isAddWorktreeSheetPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    guard !viewModel.newWorktreeBranch.isEmpty else { return }
                    guard let adapter = container.getOrCreateGitAdapter() else { return }
                    let branch = viewModel.newWorktreeBranch
                    let basePath = (appState.currentProjectPath ?? "") as NSString
                    let worktreePath = basePath.deletingLastPathComponent + "/\(branch)-worktree"
                    viewModel.addWorktree(branch: branch, path: worktreePath, using: adapter)
                    viewModel.isAddWorktreeSheetPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newWorktreeBranch.isEmpty)
            }
        }
        .padding(AnvilSpacing.xl)
        .frame(width: 360)
    }

    private func emptySectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
    }

    // MARK: - Changes Section

    private var changesSection: some View {
        AnvilSidebarDisclosureSection(
            title: "Local Changes",
            icon: "square.and.pencil",
            count: totalChangesCount,
            isExpanded: $isChangesExpanded,
            content: {
                if !isChangesExpanded {
                    EmptyView()
                } else if totalChangesCount == 0 && conflictCount == 0 {
                    HStack {
                        Text("No changes")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    if conflictCount > 0 {
                        changeGroupHeader("Conflicts", count: conflictCount)
                        ForEach(Array(viewModel.mergeConflicts.enumerated()), id: \.element.id) { index, conflict in
                            conflictRow(conflict, index: index)
                        }
                    }
                    if !appState.stagedChanges.isEmpty {
                        changeGroupHeader("Staged", count: appState.stagedChanges.count)
                        ForEach(appState.stagedChanges) { change in
                            changeRow(change)
                        }
                    }
                    if !appState.unstagedChanges.isEmpty {
                        changeGroupHeader("Modified", count: appState.unstagedChanges.count)
                        ForEach(appState.unstagedChanges) { change in
                            changeRow(change)
                        }
                    }
                    if !appState.untrackedChanges.isEmpty {
                        changeGroupHeader("Untracked", count: appState.untrackedChanges.count)
                        ForEach(appState.untrackedChanges) { change in
                            changeRow(change)
                        }
                    }
                }
            },
            trailing: {
                if conflictCount > 0 {
                    AnvilBadge(text: "\(conflictCount) conflict\(conflictCount == 1 ? "" : "s")", color: AnvilColor.accentRed)
                }
            }
        )
    }

    private func conflictRow(_ conflict: MergeConflict, index: Int) -> some View {
        AnvilSidebarRowButton(
            title: (conflict.filePath as NSString).lastPathComponent,
            icon: "exclamationmark.triangle.fill",
            isActive: viewModel.selectedConflictIndex == index,
            action: {
                appState.gitHubPRViewModel.clearSelection()
                viewModel.isCommitGraphVisible = false
                viewModel.selectConflict(index)
            },
            trailing: {
                Text("U")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AnvilColor.accentRed)
            }
        )
        .accessibilityLabel("Merge conflict: \((conflict.filePath as NSString).lastPathComponent)")
    }

    private func changeGroupHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
            Spacer()
            Text("\(count)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, 2)
    }

    private func changeRow(_ change: GitFileChange) -> some View {
        AnvilSidebarRowButton(
            title: change.fileName,
            icon: changeStatusIcon(change.status),
            isActive: viewModel.selectedFileID == change.filePath,
            action: {
                appState.gitHubPRViewModel.clearSelection()
                if change.status == .unmerged {
                    if let idx = viewModel.mergeConflicts.firstIndex(where: { $0.filePath == change.filePath }) {
                        viewModel.selectConflict(idx)
                    }
                } else if let adapter = container.getOrCreateGitAdapter() {
                    viewModel.loadLocalFileDiff(change, using: adapter)
                } else {
                    if viewModel.reviews.isEmpty {
                        viewModel.reviews = ReviewViewModel.makeSampleReviews()
                    }
                    let match = viewModel.reviews.first(where: {
                        $0.diff.contains(where: { $0.filePath.hasSuffix(change.fileName) })
                    }) ?? viewModel.reviews.first
                    if let review = match {
                        viewModel.selectReview(review.id, selectFirstFile: true)
                    }
                }
            },
            trailing: {
                Text(changeStatusLabel(change.status))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(changeStatusColor(change.status))
            }
        )
        .accessibilityLabel("\(change.fileName), \(change.status.rawValue)")
    }

    private var pendingReviewsForSidebar: [Review] {
        viewModel.pendingReviews.filter { $0.id != viewModel.selectedReviewID }
    }

    private var completedReviewsForSidebar: [Review] {
        viewModel.completedReviews.filter { $0.id != viewModel.selectedReviewID }
    }

    private func selectedReviewSection(for review: Review) -> some View {
        AnvilSidebarSection(
            title: "Selected Review",
            icon: reviewIcon(for: review),
            count: review.diff.count,
            content: {
                VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                    HStack(alignment: .top, spacing: AnvilSpacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(review.title)
                                .font(AnvilFont.body)
                                .foregroundStyle(AnvilColor.textPrimary)
                                .lineLimit(2)

                            Text("\(review.author) \u{2022} \(review.sourceId)")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        statusBadge(review.status)
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)

                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .accessibilityHidden(true)
                        Text("Open in the main canvas")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.bottom, AnvilSpacing.xs)
                }
            },
            trailing: {
                Button {
                    viewModel.clearBranchDiff()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Back to review inbox")
            }
        )
    }

    private var pendingReviewsSection: some View {
        AnvilSidebarSection(title: "Pending", icon: "circle", count: pendingReviewsForSidebar.count) {
            if pendingReviewsForSidebar.isEmpty {
                emptySectionLabel("No pending reviews")
            } else {
                ForEach(pendingReviewsForSidebar) { review in
                    reviewRow(review)
                }
            }
        }
    }

    private var completedReviewsSection: some View {
        AnvilSidebarSection(title: "Completed", icon: "checkmark.circle", count: completedReviewsForSidebar.count) {
            if completedReviewsForSidebar.isEmpty {
                emptySectionLabel("No completed reviews")
            } else {
                ForEach(completedReviewsForSidebar) { review in
                    reviewRow(review)
                }
            }
        }
    }

    private func reviewRow(_ review: Review) -> some View {
        AnvilSidebarRowButton(
            title: review.title,
            icon: reviewIcon(for: review),
            subtitle: review.author,
            isActive: viewModel.selectedReviewID == review.id
        ) {
            appState.gitHubPRViewModel.clearSelection()
            viewModel.resetNavigationState()
            viewModel.selectReview(review.id)
        } trailing: {
            HStack(spacing: AnvilSpacing.xs) {
                AnvilBadge(
                    text: review.sourceId,
                    color: review.sourceType == .pullRequest
                        ? AnvilColor.accentBlue
                        : AnvilColor.accentPurple
                )

                Text("\(review.diff.count) files")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(viewModel.selectedReviewID == review.id ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(review.title), by \(review.author), \(review.sourceId), \(review.diff.count) files, status \(String(describing: review.status))")
    }

    private func fileRow(_ file: FileDiff) -> some View {
        AnvilSidebarRowButton(
            title: file.filePath.components(separatedBy: "/").last ?? file.filePath,
            icon: fileIcon(for: file.status),
            subtitle: file.filePath.components(separatedBy: "/").dropLast().joined(separator: "/"),
            isActive: viewModel.selectedFileID == file.id
        ) {
            appState.gitHubPRViewModel.clearSelection()
            viewModel.isCommitGraphVisible = false
            viewModel.selectFile(file.id)
        } trailing: {
            HStack(spacing: AnvilSpacing.xs) {
                if viewModel.commentCountForFile(file.id) > 0 {
                    AnvilBadge(text: "\(viewModel.commentCountForFile(file.id)) comments", color: AnvilColor.accentBlue)
                }

                let approved = file.hunks.filter { viewModel.decisionFor($0.id) == .approved }.count
                let total = file.hunks.count
                if approved > 0 {
                    Text("\(approved)/\(total)")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }
        }
    }

    private func changeStatusIcon(_ status: GitFileChangeStatus) -> String {
        switch status {
        case .modified:  "pencil"
        case .added:     "plus"
        case .deleted:   "minus"
        case .renamed:   "arrow.right"
        case .copied:    "doc.on.doc"
        case .untracked: "questionmark"
        case .unmerged:  "exclamationmark.triangle"
        }
    }

    private func changeStatusLabel(_ status: GitFileChangeStatus) -> String {
        switch status {
        case .modified:  "M"
        case .added:     "A"
        case .deleted:   "D"
        case .renamed:   "R"
        case .copied:    "C"
        case .untracked: "?"
        case .unmerged:  "U"
        }
    }

    private func changeStatusColor(_ status: GitFileChangeStatus) -> Color {
        switch status {
        case .modified:  AnvilColor.accentAmber
        case .added:     AnvilColor.accentGreen
        case .deleted:   AnvilColor.accentRed
        case .renamed:   AnvilColor.accentBlue
        case .copied:    AnvilColor.accentPurple
        case .untracked: AnvilColor.textTertiary
        case .unmerged:  AnvilColor.accentRed
        }
    }

    // MARK: - GitHub Auth Bar

    // MARK: - Disclosure state

    @State private var isBranchesExpanded = true
    @State private var isRemotesExpanded = false
    @State private var isTagsExpanded = false
    @State private var isStashesExpanded = false
    @State private var isWorktreesExpanded = false
    @State private var isChangesExpanded = true
    @State private var isPRsExpanded = true

    @State private var isLoginSheetPresented = false

    private var gitHubAuthBar: some View {
        let auth = container.gitHubAuth
        return Group {
            if auth.isLoggedIn, let username = auth.username {
                HStack(spacing: AnvilSpacing.sm) {
                    Circle()
                        .fill(AnvilColor.accentGreen.opacity(0.15))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AnvilColor.accentGreen)
                        )
                        .accessibilityHidden(true)
                    Text(username)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                    Spacer()
                    Button {
                        isLoginSheetPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
            } else {
                Button {
                    isLoginSheetPresented = true
                } label: {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 12))
                        Text("Sign in to GitHub")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.textSecondary)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isLoginSheetPresented) {
            GitHubLoginView(viewModel: container.gitHubAuth)
                .environmentObject(container)
        }
    }

    private var reviewActionsBar: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Button {
                startReviewFromCurrentChanges()
            } label: {
                Label("Start Review", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                if let adapter = container.getOrCreateGitAdapter() {
                    viewModel.loadSourceControlData(using: adapter)
                    Task { await appState.loadGitStatus(from: adapter) }
                }
                loadPRsIfNeeded()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }

    private func startReviewFromCurrentChanges() {
        appState.gitHubPRViewModel.clearSelection()

        if let adapter = container.getOrCreateGitAdapter() {
            if let staged = appState.stagedChanges.first {
                viewModel.loadLocalFileDiff(staged, using: adapter)
                return
            }
            if let unstaged = appState.unstagedChanges.first {
                viewModel.loadLocalFileDiff(unstaged, using: adapter)
                return
            }
            if let untracked = appState.untrackedChanges.first {
                viewModel.loadLocalFileDiff(untracked, using: adapter)
                return
            }
            if let branch = appState.branches.first(where: { !$0.isCurrent && !$0.name.contains("/") }) {
                viewModel.loadBranchDiff(branch.name, using: adapter)
            }
            return
        }

        // No git adapter — use or seed demo reviews
        if viewModel.reviews.isEmpty {
            viewModel.reviews = ReviewViewModel.makeSampleReviews()
        }
        if let first = viewModel.reviews.first {
            viewModel.selectReview(first.id, selectFirstFile: true)
        }
    }

    // MARK: - Pull Requests Section

    private var pullRequestsSection: some View {
        let prVM = appState.gitHubPRViewModel
        return AnvilSidebarDisclosureSection(
            title: "Pull Requests",
            icon: "arrow.triangle.pull",
            count: prVM.pullRequests.count,
            isExpanded: $isPRsExpanded,
            content: {
                if prVM.isLoading {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading PRs...")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else if let error = prVM.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.accentAmber)
                        Text(error)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else if prVM.pullRequests.isEmpty {
                    HStack {
                        Text("No open pull requests")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(prVM.pullRequests) { pr in
                        prRow(pr)
                    }
                }
            }
        )
        .task {
            loadPRsIfNeeded()
        }
    }

    private func prRow(_ pr: PullRequest) -> some View {
        AnvilSidebarRowButton(
            title: pr.title,
            icon: pr.isDraft ? "circle.dashed" : "arrow.triangle.pull",
            subtitle: "#\(pr.number) by \(pr.author)",
            isActive: appState.gitHubPRViewModel.selectedPR?.id == pr.id
        ) {
            guard let adapter = container.getOrCreateGitHubAdapter() else { return }
            appState.gitHubPRViewModel.selectPR(pr, using: adapter)
        } trailing: {
            AnvilBadge(
                text: pr.isDraft ? "Draft" : pr.status.rawValue.capitalized,
                color: prStatusColor(pr.status)
            )
        }
    }

    private func prStatusColor(_ status: PRStatus) -> Color {
        switch status {
        case .open:   AnvilColor.accentGreen
        case .merged: AnvilColor.accentPurple
        case .closed: AnvilColor.accentRed
        }
    }

    private func loadPRsIfNeeded() {
        let prVM = appState.gitHubPRViewModel
        guard prVM.pullRequests.isEmpty, !prVM.isLoading else { return }
        guard let adapter = container.getOrCreateGitHubAdapter() else { return }

        // Try to derive repo name from git remote
        if let gitAdapter = container.getOrCreateGitAdapter() {
            Task {
                if let url = try? await gitAdapter.remoteURL() {
                    let repo = Self.extractRepoFullName(from: url)
                    if !repo.isEmpty {
                        prVM.loadPullRequests(using: adapter, repo: repo)
                    }
                }
            }
        }
    }

    /// Extract "owner/repo" from a GitHub remote URL.
    private static func extractRepoFullName(from url: String) -> String {
        // Handle SSH: git@github.com:owner/repo.git
        if url.contains("github.com:") {
            let parts = url.components(separatedBy: "github.com:")
            if let path = parts.last {
                return path.replacingOccurrences(of: ".git", with: "")
            }
        }
        // Handle HTTPS: https://github.com/owner/repo.git
        if url.contains("github.com/") {
            let parts = url.components(separatedBy: "github.com/")
            if let path = parts.last {
                return path.replacingOccurrences(of: ".git", with: "")
            }
        }
        return ""
    }

    private func statusBadge(_ status: ReviewStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .pending: ("Pending", AnvilColor.accentAmber)
        case .approved: ("Approved", AnvilColor.accentGreen)
        case .changesRequested: ("Changes", AnvilColor.accentRed)
        case .dismissed: ("Dismissed", AnvilColor.textTertiary)
        }
        return AnvilBadge(text: text, color: color)
            .accessibilityLabel("Status: \(text)")
    }

    private func reviewIcon(for review: Review) -> String {
        switch review.status {
        case .pending: "circle"
        case .approved: "checkmark.circle.fill"
        case .changesRequested: "exclamationmark.circle.fill"
        case .dismissed: "minus.circle"
        }
    }

    private func fileIcon(for status: DiffFileStatus) -> String {
        switch status {
        case .added: "plus.circle.fill"
        case .modified: "pencil.circle.fill"
        case .deleted: "minus.circle.fill"
        case .renamed: "arrow.right.circle.fill"
        case .copied: "doc.on.doc.fill"
        }
    }

    private func fileColor(for status: DiffFileStatus) -> Color {
        switch status {
        case .added: AnvilColor.accentGreen
        case .modified: AnvilColor.accentAmber
        case .deleted: AnvilColor.accentRed
        case .renamed: AnvilColor.accentBlue
        case .copied: AnvilColor.accentPurple
        }
    }
}
