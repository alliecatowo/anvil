import Foundation

public struct DesignFile: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let projectId: String
    public let url: String?
    public let lastModified: Date
    public let lastModifiedBy: String?
    public let thumbnailUrl: String?

    public init(id: String = UUID().uuidString, name: String, projectId: String, url: String? = nil, lastModified: Date = .now, lastModifiedBy: String? = nil, thumbnailUrl: String? = nil) {
        self.id = id
        self.name = name
        self.projectId = projectId
        self.url = url
        self.lastModified = lastModified
        self.lastModifiedBy = lastModifiedBy
        self.thumbnailUrl = thumbnailUrl
    }
}
