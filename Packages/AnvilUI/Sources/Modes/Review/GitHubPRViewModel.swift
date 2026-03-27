import SwiftUI
import AnvilDomain
import AnvilGitHub

/// Manages GitHub PR data for the Review mode.
@MainActor
final class GitHubPRViewModel: ObservableObject {

    @Published var pullRequests: [PullRequest] = []
    @Published var selectedPR: PullRequest?
    @Published var prComments: [PRComment] = []
    @Published var ciChecks: [CICheck] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var repoFullName: String = ""
    @Published var isMerging = false
    @Published var mergeError: String?
    @Published var selectedMergeStrategy: MergeStrategy = .squash

    // MARK: - Load PRs

    func loadPullRequests(using adapter: GitHubSourceControlCloudAdapter, repo: String) {
        repoFullName = repo
        isLoading = true
        error = nil

        Task { @MainActor in
            defer { isLoading = false }
            do {
                pullRequests = try await adapter.pullRequests(repo: repo, status: .open)
            } catch {
                self.error = "Failed to load PRs: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Select PR

    func selectPR(_ pr: PullRequest, using adapter: GitHubSourceControlCloudAdapter) {
        selectedPR = pr
        ciChecks = []
        prComments = []

        Task { @MainActor in
            // Load detail, comments, and CI in parallel
            async let detailTask = adapter.pullRequestDetail(repo: repoFullName, number: pr.number)
            async let commentsTask = adapter.pullRequestComments(repo: repoFullName, number: pr.number)
            async let ciTask = adapter.ciStatus(repo: repoFullName, prNumber: pr.number)

            if let detail = try? await detailTask {
                selectedPR = detail
            }
            if let comments = try? await commentsTask {
                prComments = comments
            }
            if let checks = try? await ciTask {
                ciChecks = checks
            }
        }
    }

    func clearSelection() {
        selectedPR = nil
        prComments = []
        ciChecks = []
        mergeError = nil
    }

    // MARK: - Merge

    func mergePR(using adapter: GitHubSourceControlCloudAdapter) {
        guard let pr = selectedPR, pr.status == .open else { return }
        guard !isMerging else { return }
        isMerging = true
        mergeError = nil

        Task { @MainActor in
            defer { isMerging = false }
            do {
                try await adapter.mergePullRequest(repo: repoFullName, number: pr.number, strategy: selectedMergeStrategy)
                // Refresh the PR to show merged status
                if let updated = try? await adapter.pullRequestDetail(repo: repoFullName, number: pr.number) {
                    selectedPR = updated
                }
                // Refresh the PR list
                pullRequests = (try? await adapter.pullRequests(repo: repoFullName, status: .open)) ?? []
            } catch {
                mergeError = "Merge failed: \(error.localizedDescription)"
            }
        }
    }

    var canMerge: Bool {
        guard let pr = selectedPR else { return false }
        return pr.status == .open && !pr.isDraft && ciSummary.failed == 0
    }

    // MARK: - Update Branch

    @Published var isUpdatingBranch = false
    @Published var updateBranchError: String?

    func updateBranch(using adapter: GitHubSourceControlCloudAdapter) {
        guard let pr = selectedPR, pr.status == .open else { return }
        guard !isUpdatingBranch else { return }
        isUpdatingBranch = true
        updateBranchError = nil

        Task { @MainActor in
            defer { isUpdatingBranch = false }
            do {
                try await adapter.updatePullRequestBranch(repo: repoFullName, number: pr.number)
                // Refresh PR detail to get updated state
                if let updated = try? await adapter.pullRequestDetail(repo: repoFullName, number: pr.number) {
                    selectedPR = updated
                }
                // Refresh CI checks since new commits may trigger new checks
                if let checks = try? await adapter.ciStatus(repo: repoFullName, prNumber: pr.number) {
                    ciChecks = checks
                }
            } catch {
                updateBranchError = "Update branch failed: \(error.localizedDescription)"
            }
        }
    }

    var needsUpdate: Bool {
        guard let pr = selectedPR else { return false }
        return pr.status == .open && pr.behindCount > 0
    }

    // MARK: - Comment Threads

    @Published var replyText: [String: String] = [:]   // threadId -> draft text
    @Published var expandedThreads: Set<String> = []
    @Published var resolvedThreads: Set<String> = []
    @Published var isReplying = false
    @Published var replyError: String?

    /// Groups flat comments into threads. Root comments (no replyToId) start threads;
    /// replies are grouped under their root.
    var commentThreads: [PRCommentThread] {
        var roots: [PRComment] = []
        var repliesByRoot: [String: [PRComment]] = [:]

        for comment in prComments {
            if let parentId = comment.replyToId {
                repliesByRoot[parentId, default: []].append(comment)
            } else {
                roots.append(comment)
            }
        }

        return roots.map { root in
            var thread = PRCommentThread(rootComment: root, replies: repliesByRoot[root.id] ?? [])
            if resolvedThreads.contains(root.id) {
                thread.isResolved = true
            }
            return thread
        }.sorted { $0.rootComment.createdAt < $1.rootComment.createdAt }
    }

    var unresolvedThreadCount: Int {
        commentThreads.filter { !$0.isResolved }.count
    }

    var resolvedThreadCount: Int {
        commentThreads.filter { $0.isResolved }.count
    }

    func toggleThread(_ threadId: String) {
        if expandedThreads.contains(threadId) {
            expandedThreads.remove(threadId)
        } else {
            expandedThreads.insert(threadId)
        }
    }

    func replyToThread(_ threadId: String, using adapter: GitHubSourceControlCloudAdapter) {
        guard let pr = selectedPR else { return }
        guard let text = replyText[threadId], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isReplying else { return }
        isReplying = true
        replyError = nil

        Task { @MainActor in
            defer { isReplying = false }
            do {
                let newComment = try await adapter.replyToComment(repo: repoFullName, prNumber: pr.number, commentId: threadId, body: text)
                prComments.append(newComment)
                replyText[threadId] = ""
                expandedThreads.insert(threadId)
            } catch {
                replyError = "Reply failed: \(error.localizedDescription)"
            }
        }
    }

    func resolveThread(_ threadId: String, using adapter: GitHubSourceControlCloudAdapter) {
        resolvedThreads.insert(threadId)
        // Collapse resolved threads
        expandedThreads.remove(threadId)

        Task { @MainActor in
            do {
                try await adapter.resolveReviewThread(repo: repoFullName, threadId: threadId)
            } catch {
                // If API fails, keep local state — resolve is best-effort via REST
            }
        }
    }

    func unresolveThread(_ threadId: String) {
        resolvedThreads.remove(threadId)
    }

    // MARK: - Computed

    var openPRs: [PullRequest] {
        pullRequests.filter { $0.status == .open }
    }

    var draftPRs: [PullRequest] {
        pullRequests.filter { $0.isDraft }
    }

    var readyPRs: [PullRequest] {
        pullRequests.filter { $0.status == .open && !$0.isDraft }
    }

    var ciSummary: (passed: Int, failed: Int, pending: Int) {
        let passed = ciChecks.filter { $0.conclusion == .success }.count
        let failed = ciChecks.filter { $0.conclusion == .failure }.count
        let pending = ciChecks.filter { $0.status != .completed }.count
        return (passed, failed, pending)
    }
}
