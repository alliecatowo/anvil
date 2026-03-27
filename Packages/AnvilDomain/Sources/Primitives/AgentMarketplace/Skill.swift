import Foundation

public struct Skill: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let author: String
    public let version: String
    public let category: SkillCategory
    public let isInstalled: Bool
    public let downloadCount: Int
    public let rating: Double?

    public init(id: String = UUID().uuidString, name: String, description: String, author: String, version: String, category: SkillCategory, isInstalled: Bool = false, downloadCount: Int = 0, rating: Double? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.category = category
        self.isInstalled = isInstalled
        self.downloadCount = downloadCount
        self.rating = rating
    }
}

public enum SkillCategory: String, Sendable, Codable {
    case coding, testing, deployment, documentation, communication, productivity, ai, other
}
