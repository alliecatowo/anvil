import Foundation

public struct ContainerImage: Sendable, Identifiable, Codable {
    public let id: String
    public let repository: String
    public let tag: String
    public let sizeBytes: Int64
    public let createdAt: Date

    public init(id: String, repository: String, tag: String = "latest", sizeBytes: Int64 = 0, createdAt: Date = .now) {
        self.id = id
        self.repository = repository
        self.tag = tag
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
    }
}
