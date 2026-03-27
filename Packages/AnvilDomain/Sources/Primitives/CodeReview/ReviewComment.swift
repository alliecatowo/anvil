import Foundation

public struct ReviewComment: Sendable, Identifiable, Codable {
    public let id: String
    public let author: String
    public let body: String
    public let filePath: String?
    public let lineRange: ClosedRange<Int>?
    public var isResolved: Bool
    public let isAIGenerated: Bool
    public let createdAt: Date

    public init(id: String = UUID().uuidString, author: String, body: String, filePath: String? = nil, lineRange: ClosedRange<Int>? = nil, isResolved: Bool = false, isAIGenerated: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.author = author
        self.body = body
        self.filePath = filePath
        self.lineRange = lineRange
        self.isResolved = isResolved
        self.isAIGenerated = isAIGenerated
        self.createdAt = createdAt
    }
}

public struct ReviewCommentDraft: Sendable {
    public let body: String
    public let filePath: String?
    public let lineRange: ClosedRange<Int>?

    public init(body: String, filePath: String? = nil, lineRange: ClosedRange<Int>? = nil) {
        self.body = body
        self.filePath = filePath
        self.lineRange = lineRange
    }
}
