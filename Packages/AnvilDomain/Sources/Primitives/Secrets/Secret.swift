import Foundation

public struct Secret: Sendable, Identifiable, Codable {
    public let id: String
    public let key: String
    public let vaultId: String
    public let createdAt: Date
    public let updatedAt: Date
    public let expiresAt: Date?
    public let version: Int

    public init(id: String = UUID().uuidString, key: String, vaultId: String, createdAt: Date = .now, updatedAt: Date = .now, expiresAt: Date? = nil, version: Int = 1) {
        self.id = id
        self.key = key
        self.vaultId = vaultId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.version = version
    }
}
