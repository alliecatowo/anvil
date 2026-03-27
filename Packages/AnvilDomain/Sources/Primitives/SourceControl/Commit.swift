import Foundation

public struct Commit: Sendable, Identifiable, Codable, Hashable {
    public let id: String // hash
    public let shortHash: String
    public let author: String
    public let authorEmail: String
    public let date: Date
    public let message: String
    public let parents: [String]
    public let filesChanged: Int
    public let insertions: Int
    public let deletions: Int

    public init(id: String, shortHash: String, author: String, authorEmail: String, date: Date, message: String, parents: [String] = [], filesChanged: Int = 0, insertions: Int = 0, deletions: Int = 0) {
        self.id = id
        self.shortHash = shortHash
        self.author = author
        self.authorEmail = authorEmail
        self.date = date
        self.message = message
        self.parents = parents
        self.filesChanged = filesChanged
        self.insertions = insertions
        self.deletions = deletions
    }
}
