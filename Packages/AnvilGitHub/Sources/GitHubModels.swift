import Foundation

// MARK: - GitHub API Response Models

/// These map 1:1 to GitHub REST API JSON responses.
/// They are internal to this package — the adapter converts them to AnvilDomain types.

struct GHRepo: Decodable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let htmlUrl: String
    let visibility: String?
    let defaultBranch: String
    let description: String?
    let private_: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, fullName, htmlUrl, visibility, defaultBranch, description
        case private_ = "private"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        fullName = try container.decode(String.self, forKey: .fullName)
        htmlUrl = try container.decode(String.self, forKey: .htmlUrl)
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility)
        defaultBranch = try container.decodeIfPresent(String.self, forKey: .defaultBranch) ?? "main"
        description = try container.decodeIfPresent(String.self, forKey: .description)
        private_ = try container.decodeIfPresent(Bool.self, forKey: .private_)
    }
}

struct GHUser: Decodable, Sendable {
    let login: String
    let id: Int
}

struct GHPullRequest: Decodable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String        // "open", "closed"
    let merged: Bool?
    let draft: Bool?
    let head: GHBranchRef
    let base: GHBranchRef
    let user: GHUser
    let requestedReviewers: [GHUser]?
    let labels: [GHLabel]?
    let createdAt: Date
    let updatedAt: Date
    let mergedAt: Date?
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
}

struct GHBranchRef: Decodable, Sendable {
    let ref: String
    let sha: String
}

struct GHLabel: Decodable, Sendable {
    let name: String
    let color: String?
}

struct GHComment: Decodable, Sendable {
    let id: Int
    let user: GHUser
    let body: String
    let path: String?
    let line: Int?
    let createdAt: Date
}

struct GHReviewComment: Decodable, Sendable {
    let id: Int
    let user: GHUser
    let body: String
    let path: String?
    let line: Int?
    let createdAt: Date
    let inReplyToId: Int?
}

struct ReplyToCommentRequest: Encodable, Sendable {
    let body: String
}

struct GHCheckRun: Decodable, Sendable {
    let id: Int
    let name: String
    let status: String      // "queued", "in_progress", "completed"
    let conclusion: String?  // "success", "failure", "cancelled", "skipped", "timed_out"
    let htmlUrl: String?
    let startedAt: Date?
    let completedAt: Date?
}

struct GHCheckSuiteResponse: Decodable, Sendable {
    let totalCount: Int
    let checkRuns: [GHCheckRun]
}

struct GHNotification: Decodable, Sendable {
    let id: String
    let reason: String           // "review_requested", "mentioned", "assign", "comment", "ci_activity", etc.
    let unread: Bool
    let subject: GHNotificationSubject
    let repository: GHNotificationRepo
    let updatedAt: Date
    let url: String?
}

struct GHNotificationSubject: Decodable, Sendable {
    let title: String
    let url: String?
    let type: String             // "PullRequest", "Issue", "CheckSuite", "Release", etc.
}

struct GHNotificationRepo: Decodable, Sendable {
    let fullName: String
    let htmlUrl: String
}

// MARK: - Request Bodies

struct CreatePRRequest: Encodable, Sendable {
    let title: String
    let body: String
    let head: String
    let base: String
    let draft: Bool
}

struct CreateCommentRequest: Encodable, Sendable {
    let body: String
}

struct CreateReviewCommentRequest: Encodable, Sendable {
    let body: String
    let path: String
    let line: Int
    let commitId: String
}

struct MergePRRequest: Encodable, Sendable {
    let mergeMethod: String  // "merge", "squash", "rebase"
}
