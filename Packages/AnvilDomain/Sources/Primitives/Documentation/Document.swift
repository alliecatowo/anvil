import Foundation

public struct Document: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let content: String
    public let url: String?
    public let parentId: String?
    public let author: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: String = UUID().uuidString, title: String, content: String, url: String? = nil, parentId: String? = nil, author: String? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.content = content
        self.url = url
        self.parentId = parentId
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
