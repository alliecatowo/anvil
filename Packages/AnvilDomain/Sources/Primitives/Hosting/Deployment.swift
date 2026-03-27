import Foundation

public struct Deployment: Sendable, Identifiable, Codable {
    public let id: String
    public let projectId: String
    public let environmentId: String
    public let commitHash: String?
    public let status: DeploymentStatus
    public let url: String?
    public let createdAt: Date
    public let completedAt: Date?

    public init(id: String = UUID().uuidString, projectId: String, environmentId: String, commitHash: String? = nil, status: DeploymentStatus = .queued, url: String? = nil, createdAt: Date = .now, completedAt: Date? = nil) {
        self.id = id
        self.projectId = projectId
        self.environmentId = environmentId
        self.commitHash = commitHash
        self.status = status
        self.url = url
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public enum DeploymentStatus: String, Sendable, Codable {
    case queued, building, deploying, ready, failed, cancelled
}
