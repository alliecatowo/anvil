import Foundation

public struct Migration: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let version: String
    public let appliedAt: Date?
    public let status: MigrationStatus

    public init(id: String = UUID().uuidString, name: String, version: String, appliedAt: Date? = nil, status: MigrationStatus = .pending) {
        self.id = id
        self.name = name
        self.version = version
        self.appliedAt = appliedAt
        self.status = status
    }
}

public enum MigrationStatus: String, Sendable, Codable {
    case pending, applied, failed, rolledBack
}
