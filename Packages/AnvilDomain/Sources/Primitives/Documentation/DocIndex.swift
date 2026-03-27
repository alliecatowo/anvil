import Foundation

public struct DocIndex: Sendable, Codable {
    public let entries: [DocIndexEntry]
    public let totalCount: Int
    public let lastUpdated: Date

    public init(entries: [DocIndexEntry], totalCount: Int, lastUpdated: Date = .now) {
        self.entries = entries
        self.totalCount = totalCount
        self.lastUpdated = lastUpdated
    }
}

public struct DocIndexEntry: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let path: String
    public let parentId: String?

    public init(id: String, title: String, path: String, parentId: String? = nil) {
        self.id = id
        self.title = title
        self.path = path
        self.parentId = parentId
    }
}
