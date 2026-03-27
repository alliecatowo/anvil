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
