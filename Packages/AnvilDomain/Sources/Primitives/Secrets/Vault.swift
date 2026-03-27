import Foundation

public struct Vault: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let secretCount: Int
    public let lastAccessedAt: Date?

    public init(id: String = UUID().uuidString, name: String, secretCount: Int = 0, lastAccessedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.secretCount = secretCount
        self.lastAccessedAt = lastAccessedAt
    }
}
