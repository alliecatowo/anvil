import Foundation
import AnvilDomain

/// Implements SourceControlCloudPort using the GitHub REST API.
public actor GitHubSourceControlCloudAdapter: SourceControlCloudPort {
    public let providerId: String = "github"
    public let providerName: String = "GitHub"

    private let client: GitHubClient

    public init(token: String, baseURL: String = "https://api.github.com") {
        self.client = GitHubClient(token: token, baseURL: baseURL)
    }

    public func validateConnection() async throws -> Bool {
        // Try to get authenticated user
        let _: GHUser = try await client.get("/user")
        return true
    }

    // MARK: - Repositories

    public func repositories() async throws -> [RemoteRepo] {
        let repos: [GHRepo] = try await client.get("/user/repos", query: [
            "sort": "updated",
            "per_page": "30",
            "type": "all"
        ])
        return repos.map { mapRepo($0) }
    }

    // MARK: - Pull Requests

    public func pullRequests(repo: String, status: PRStatus?) async throws -> [PullRequest] {
        let state: String
        switch status {
        case .open, nil: state = "open"
        case .closed:    state = "closed"
        case .merged:    state = "closed" // GitHub doesn't have a merged state filter, we filter after
        }

        let prs: [GHPullRequest] = try await client.get("/repos/\(repo)/pulls", query: [
            "state": state,
            "sort": "updated",
            "direction": "desc",
            "per_page": "30"
        ])

        let mapped = prs.map { mapPR($0) }

        if status == .merged {
            return mapped.filter { $0.status == .merged }
        }
        return mapped
    }

    public func pullRequestDetail(repo: String, number: Int) async throws -> PullRequest {
        let pr: GHPullRequest = try await client.get("/repos/\(repo)/pulls/\(number)")
        return mapPR(pr)
    }

    public func createPullRequest(repo: String, title: String, body: String, source: String, target: String, isDraft: Bool) async throws -> PullRequest {
        let request = CreatePRRequest(title: title, body: body, head: source, base: target, draft: isDraft)
        let pr: GHPullRequest = try await client.post("/repos/\(repo)/pulls", body: request)
        return mapPR(pr)
    }

    public func mergePullRequest(repo: String, number: Int, strategy: MergeStrategy) async throws {
        let method: String
        switch strategy {
        case .merge:       method = "merge"
        case .squash:      method = "squash"
        case .rebase:      method = "rebase"
        case .fastForward: method = "rebase"
        }

        let request = MergePRRequest(mergeMethod: method)
        let _: GHPullRequest = try await client.patch("/repos/\(repo)/pulls/\(number)/merge", body: request)
    }

    public func closePullRequest(repo: String, number: Int) async throws {
        struct CloseBody: Encodable { let state = "closed" }
        let _: GHPullRequest = try await client.patch("/repos/\(repo)/pulls/\(number)", body: CloseBody())
    }

    public func updatePullRequestBranch(repo: String, number: Int) async throws {
        try await client.put("/repos/\(repo)/pulls/\(number)/update-branch")
    }

    // MARK: - Comments

    public func pullRequestComments(repo: String, number: Int) async throws -> [PRComment] {
        // Get both issue comments and review comments
        let issueComments: [GHComment] = try await client.get("/repos/\(repo)/issues/\(number)/comments", query: [
            "per_page": "50"
        ])
        let reviewComments: [GHReviewComment] = try await client.get("/repos/\(repo)/pulls/\(number)/comments", query: [
            "per_page": "50"
        ])

        let mapped1 = issueComments.map { mapComment($0) }
        let mapped2 = reviewComments.map { mapReviewComment($0) }

        return (mapped1 + mapped2).sorted { $0.createdAt < $1.createdAt }
    }

    public func addComment(repo: String, prNumber: Int, body: String, file: String?, line: Int?) async throws -> PRComment {
        if let file = file, let line = line {
            // Review comment on a specific file/line
            // Need the latest commit SHA
            let pr: GHPullRequest = try await client.get("/repos/\(repo)/pulls/\(prNumber)")
            let request = CreateReviewCommentRequest(body: body, path: file, line: line, commitId: pr.head.sha)
            let comment: GHReviewComment = try await client.post("/repos/\(repo)/pulls/\(prNumber)/comments", body: request)
            return mapReviewComment(comment)
        } else {
            // General issue comment
            let request = CreateCommentRequest(body: body)
            let comment: GHComment = try await client.post("/repos/\(repo)/issues/\(prNumber)/comments", body: request)
            return mapComment(comment)
        }
    }

    // MARK: - Reply & Resolve

    public func replyToComment(repo: String, prNumber: Int, commentId: String, body: String) async throws -> PRComment {
        let request = ReplyToCommentRequest(body: body)
        let comment: GHReviewComment = try await client.post("/repos/\(repo)/pulls/\(prNumber)/comments/\(commentId)/replies", body: request)
        return mapReviewComment(comment)
    }

    public func resolveReviewThread(repo: String, threadId: String) async throws {
        // GitHub GraphQL is needed for thread resolution — not available via REST.
        // For now this is a no-op stub; the UI can still track resolved state locally.
    }

    // MARK: - CI Status

    public func ciStatus(repo: String, prNumber: Int) async throws -> [CICheck] {
        let pr: GHPullRequest = try await client.get("/repos/\(repo)/pulls/\(prNumber)")
        let response: GHCheckSuiteResponse = try await client.get("/repos/\(repo)/commits/\(pr.head.sha)/check-runs", query: [
            "per_page": "30"
        ])
        return response.checkRuns.map { mapCheckRun($0) }
    }

    // MARK: - Remote Operations

    public func push(remote: String, branch: String, force: Bool) async throws {
        // Push is a local git operation, not a GitHub API call.
        // This would be handled by GitSourceControlAdapter instead.
        throw GitHubError.notConfigured
    }

    public func pull(remote: String, branch: String) async throws {
        throw GitHubError.notConfigured
    }

    public func fetch(remote: String) async throws {
        throw GitHubError.notConfigured
    }

    // MARK: - Notifications

    public func fetchNotifications(since: Date? = nil) async throws -> [GitHubNotification] {
        var query: [String: String] = ["per_page": "50"]
        if let since = since {
            let formatter = ISO8601DateFormatter()
            query["since"] = formatter.string(from: since)
        }
        let notifications: [GHNotification] = try await client.get("/notifications", query: query)
        return notifications.map { mapNotification($0) }
    }

    public func markNotificationRead(threadId: String) async throws {
        try await client.patch("/notifications/threads/\(threadId)")
    }

    private func mapNotification(_ n: GHNotification) -> GitHubNotification {
        let type: GitHubNotification.NotificationType
        switch n.subject.type {
        case "PullRequest": type = .pullRequest
        case "Issue":       type = .issue
        case "CheckSuite":  type = .ciCheck
        case "Release":     type = .release
        default:            type = .other
        }

        let urgency: GitHubNotification.Urgency
        switch n.reason {
        case "review_requested", "assign":     urgency = .high
        case "ci_activity":                    urgency = .normal
        case "mention":                        urgency = .high
        default:                               urgency = .normal
        }

        return GitHubNotification(
            id: n.id,
            title: n.subject.title,
            reason: n.reason,
            type: type,
            repoFullName: n.repository.fullName,
            url: n.subject.url,
            unread: n.unread,
            urgency: urgency,
            updatedAt: n.updatedAt
        )
    }

    // MARK: - Mapping

    private func mapRepo(_ repo: GHRepo) -> RemoteRepo {
        let visibility: RepoVisibility
        if let v = repo.visibility {
            switch v {
            case "public":   visibility = .public_
            case "internal": visibility = .internal_
            default:         visibility = .private_
            }
        } else {
            visibility = (repo.private_ == true) ? .private_ : .public_
        }

        return RemoteRepo(
            id: "\(repo.id)",
            name: repo.name,
            fullName: repo.fullName,
            url: repo.htmlUrl,
            visibility: visibility,
            defaultBranch: repo.defaultBranch,
            description: repo.description
        )
    }

    private func mapPR(_ pr: GHPullRequest) -> PullRequest {
        let status: PRStatus
        if pr.merged == true || pr.mergedAt != nil {
            status = .merged
        } else if pr.state == "closed" {
            status = .closed
        } else {
            status = .open
        }

        return PullRequest(
            id: "\(pr.id)",
            number: pr.number,
            title: pr.title,
            body: pr.body ?? "",
            status: status,
            sourceBranch: pr.head.ref,
            targetBranch: pr.base.ref,
            author: pr.user.login,
            reviewers: pr.requestedReviewers?.map(\.login) ?? [],
            labels: pr.labels?.map(\.name) ?? [],
            ciChecks: [],
            createdAt: pr.createdAt,
            updatedAt: pr.updatedAt,
            mergedAt: pr.mergedAt,
            additions: pr.additions ?? 0,
            deletions: pr.deletions ?? 0,
            changedFiles: pr.changedFiles ?? 0,
            isDraft: pr.draft ?? false
        )
    }

    private func mapComment(_ c: GHComment) -> PRComment {
        PRComment(
            id: "\(c.id)",
            author: c.user.login,
            body: c.body,
            filePath: c.path,
            lineNumber: c.line,
            createdAt: c.createdAt
        )
    }

    private func mapReviewComment(_ c: GHReviewComment) -> PRComment {
        PRComment(
            id: "review-\(c.id)",
            author: c.user.login,
            body: c.body,
            filePath: c.path,
            lineNumber: c.line,
            createdAt: c.createdAt,
            replyToId: c.inReplyToId.map { "review-\($0)" }
        )
    }

    private func mapCheckRun(_ c: GHCheckRun) -> CICheck {
        let status: CICheckStatus
        switch c.status {
        case "queued":      status = .queued
        case "in_progress": status = .inProgress
        default:            status = .completed
        }

        let conclusion: CICheckConclusion?
        switch c.conclusion {
        case "success":   conclusion = .success
        case "failure":   conclusion = .failure
        case "cancelled": conclusion = .cancelled
        case "skipped":   conclusion = .skipped
        case "timed_out": conclusion = .timedOut
        default:          conclusion = nil
        }

        return CICheck(
            id: "\(c.id)",
            name: c.name,
            status: status,
            conclusion: conclusion,
            url: c.htmlUrl,
            startedAt: c.startedAt,
            completedAt: c.completedAt
        )
    }
}
