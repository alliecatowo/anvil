import Foundation

public struct PullRequest: Sendable, Identifiable, Codable {
    public let id: String
    public let number: Int
    public let title: String
    public let body: String
    public let status: PRStatus
    public let sourceBranch: String
    public let targetBranch: String
    public let author: String
    public let reviewers: [String]
    public let labels: [String]
    public let ciChecks: [CICheck]
    public let createdAt: Date
    public let updatedAt: Date
    public let mergedAt: Date?
    public let additions: Int
    public let deletions: Int
    public let changedFiles: Int
    public let isDraft: Bool

    public init(id: String, number: Int, title: String, body: String = "", status: PRStatus = .open, sourceBranch: String, targetBranch: String, author: String, reviewers: [String] = [], labels: [String] = [], ciChecks: [CICheck] = [], createdAt: Date = .now, updatedAt: Date = .now, mergedAt: Date? = nil, additions: Int = 0, deletions: Int = 0, changedFiles: Int = 0, isDraft: Bool = false) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.status = status
        self.sourceBranch = sourceBranch
        self.targetBranch = targetBranch
        self.author = author
        self.reviewers = reviewers
        self.labels = labels
        self.ciChecks = ciChecks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mergedAt = mergedAt
        self.additions = additions
        self.deletions = deletions
        self.changedFiles = changedFiles
        self.isDraft = isDraft
    }
}

public enum PRStatus: String, Sendable, Codable {
    case open, merged, closed
}

public struct PRComment: Sendable, Identifiable, Codable {
    public let id: String
    public let author: String
    public let body: String
    public let filePath: String?
    public let lineNumber: Int?
    public let isResolved: Bool
    public let createdAt: Date

    public init(id: String, author: String, body: String, filePath: String? = nil, lineNumber: Int? = nil, isResolved: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.author = author
        self.body = body
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.isResolved = isResolved
        self.createdAt = createdAt
    }
}

public struct CICheck: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let status: CICheckStatus
    public let conclusion: CICheckConclusion?
    public let url: String?
    public let startedAt: Date?
    public let completedAt: Date?

    public init(id: String, name: String, status: CICheckStatus, conclusion: CICheckConclusion? = nil, url: String? = nil, startedAt: Date? = nil, completedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.conclusion = conclusion
        self.url = url
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

public enum CICheckStatus: String, Sendable, Codable {
    case queued, inProgress, completed
}

public enum CICheckConclusion: String, Sendable, Codable {
    case success, failure, cancelled, skipped, timedOut
}

public struct RemoteRepo: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let fullName: String
    public let url: String
    public let visibility: RepoVisibility
    public let defaultBranch: String
    public let description: String?

    public init(id: String, name: String, fullName: String, url: String, visibility: RepoVisibility = .private_, defaultBranch: String = "main", description: String? = nil) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.url = url
        self.visibility = visibility
        self.defaultBranch = defaultBranch
        self.description = description
    }
}

public enum RepoVisibility: String, Sendable, Codable {
    case public_, private_, internal_
}
