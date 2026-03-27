import Foundation

public struct Review: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let sourceType: ReviewSourceType
    public let sourceId: String
    public var status: ReviewStatus
    public let reviewer: String?
    public let author: String
    public let diff: [FileDiff]
    public var comments: [ReviewComment]
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, title: String, sourceType: ReviewSourceType, sourceId: String, status: ReviewStatus = .pending, reviewer: String? = nil, author: String, diff: [FileDiff] = [], comments: [ReviewComment] = [], createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.status = status
        self.reviewer = reviewer
        self.author = author
        self.diff = diff
        self.comments = comments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ReviewSourceType: String, Sendable, Codable {
    case pullRequest, agentSession, manualSelection
}

public enum ReviewStatus: String, Sendable, Codable {
    case pending, approved, changesRequested, dismissed
}
