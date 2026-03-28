import SwiftUI
import AnvilDomain
import AnvilGit
import AnvilGitHub

struct ReviewSidebar: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    private struct SidebarSectionDescriptor: Identifiable {
        let id: String
        let title: String
        let icon: String
        let count: Int
    }

    // Minimal adapter target for upcoming shared sidebar abstraction.
    private var sidebarSections: [SidebarSectionDescriptor] {
        [
            SidebarSectionDescriptor(id: "branches", title: "Branches", icon: "arrow.triangle.branch", count: appState.branches.count),
            SidebarSectionDescriptor(id: "pullRequests", title: "Pull Requests", icon: "arrow.triangle.pull", count: appState.gitHubPRViewModel.pullRequests.count),
            SidebarSectionDescriptor(id: "pending", title: "Pending", icon: "circle", count: viewModel.pendingReviews.count),
            SidebarSectionDescriptor(id: "completed", title: "Completed", icon: "checkmark.circle", count: viewModel.completedReviews.count)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            if let review = viewModel.selectedReview {
                reviewFileList(review)
            } else if appState.gitHubPRViewModel.selectedPR != nil {
                prSelectedBar
            } else {
                gitHubAuthBar
                Divider()
                branchSection
                Divider()
                pullRequestsSection
                Divider()
                groupedReviewList
            }
        }
    }

    // MARK: - Branch Section

    private var branchSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: AnvilSpacing.sm) {
                sectionHeader(sidebarSections[0])
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
            .padding(.trailing, AnvilSpacing.md)

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
        }
    }

    private var localBranches: [Branch] {
        appState.branches.filter { !$0.name.contains("/") }
    }

    private func branchRow(_ branch: Branch) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: branch.isCurrent ? "checkmark.circle.fill" : "arrow.triangle.branch")
                .font(.system(size: 11))
                .foregroundStyle(branch.isCurrent ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                .frame(width: 16)

            Text(branch.name)
                .font(AnvilFont.code)
                .foregroundStyle(
                    viewModel.selectedBranchName == branch.name
                        ? AnvilColor.accentBlue
                        : (branch.isCurrent ? AnvilColor.accentGreen : AnvilColor.textPrimary)
                )
                .lineLimit(1)

            Spacer()

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
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: AnvilSpacing.listItemHeight)
        .background(
            viewModel.selectedBranchName == branch.name
                ? AnvilColor.selectionBackground
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !branch.isCurrent else { return }
            guard let adapter = container.getOrCreateGitAdapter() else { return }
            viewModel.loadBranchDiff(branch.name, using: adapter)
        }
    }

    // MARK: - GitHub Auth Bar

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
                .padding(.vertical, AnvilSpacing.xs)
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
                    .padding(.vertical, AnvilSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isLoginSheetPresented) {
            GitHubLoginView(viewModel: container.gitHubAuth)
                .environmentObject(container)
        }
    }

    // MARK: - Pull Requests Section

    private var pullRequestsSection: some View {
        VStack(spacing: 0) {
            let prVM = appState.gitHubPRViewModel
            sectionHeader(sidebarSections[1])

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
        .task {
            loadPRsIfNeeded()
        }
    }

    private func prRow(_ pr: PullRequest) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: pr.isDraft ? "circle.dashed" : "arrow.triangle.pull")
                .font(.system(size: 11))
                .foregroundStyle(prStatusColor(pr.status))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(pr.title)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text("#\(pr.number) by \(pr.author)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if pr.isDraft {
                Text("Draft")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(minHeight: AnvilSpacing.listItemHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let adapter = container.getOrCreateGitHubAdapter() else { return }
            appState.gitHubPRViewModel.selectPR(pr, using: adapter)
        }
    }

    private var prSelectedBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: AnvilSpacing.sm) {
                Button {
                    appState.gitHubPRViewModel.clearSelection()
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("All PRs")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider()
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

    // MARK: - Grouped Review List (no review selected)

    private var groupedReviewList: some View {
        List {
            if !viewModel.pendingReviews.isEmpty {
                Section {
                    ForEach(viewModel.pendingReviews) { review in
                        reviewRow(review)
                    }
                } header: {
                    sectionHeader(sidebarSections[2])
                }
            }

            if !viewModel.completedReviews.isEmpty {
                Section {
                    ForEach(viewModel.completedReviews) { review in
                        reviewRow(review)
                    }
                } header: {
                    sectionHeader(sidebarSections[3])
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func reviewRow(_ review: Review) -> some View {
        AnvilListItem(
            icon: reviewIcon(for: review),
            title: review.title,
            subtitle: review.author,
            tag: review.sourceId,
            tagColor: review.sourceType == .pullRequest
                ? AnvilColor.accentBlue
                : AnvilColor.accentPurple,
            isSelected: viewModel.selectedReviewID == review.id,
            isCompact: false
        )
        .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
        .onTapGesture { viewModel.selectReview(review.id) }
    }

    private func reviewFileList(_ review: Review) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AnvilSpacing.sm) {
                Button {
                    viewModel.selectedReviewID = nil
                    viewModel.selectedFileID = nil
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                statusBadge(review.status)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider()

            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                Text(review.title)
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(2)

                Text("\(review.author) \u{2022} \(review.diff.count) files")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider()

            List {
                Section {
                    ForEach(review.diff) { file in
                        fileRow(file)
                    }
                } header: {
                    sectionHeader(
                        SidebarSectionDescriptor(
                            id: "files",
                            title: "Files",
                            icon: "doc",
                            count: review.diff.count
                        )
                    )
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func fileRow(_ file: FileDiff) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: fileIcon(for: file.status))
                .font(.system(size: 12))
                .foregroundStyle(fileColor(for: file.status))
                .frame(width: 16)

            Text(file.filePath.components(separatedBy: "/").last ?? file.filePath)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Spacer()

            // Hunk decision summary
            let approved = file.hunks.filter { viewModel.decisionFor($0.id) == .approved }.count
            let total = file.hunks.count
            if approved > 0 {
                Text("\(approved)/\(total)")
                    .font(AnvilFont.label)
                    .foregroundStyle(
                        approved == total ? AnvilColor.accentGreen : AnvilColor.textTertiary
                    )
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: AnvilSpacing.listItemHeight)
        .background(
            viewModel.selectedFileID == file.id
                ? AnvilColor.selectionBackground
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectFile(file.id) }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ descriptor: SidebarSectionDescriptor) -> some View {
        HStack {
            Image(systemName: descriptor.icon)
                .font(.system(size: 10))
                .foregroundStyle(AnvilColor.textTertiary)

            Text(descriptor.title)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            Spacer()

            Text("\(descriptor.count)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .textCase(nil)
    }

    private func statusBadge(_ status: ReviewStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .pending: ("Pending", AnvilColor.accentAmber)
        case .approved: ("Approved", AnvilColor.accentGreen)
        case .changesRequested: ("Changes", AnvilColor.accentRed)
        case .dismissed: ("Dismissed", AnvilColor.textTertiary)
        }
        return AnvilBadge(text: text, color: color)
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
