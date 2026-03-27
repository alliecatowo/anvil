import Foundation

public struct BuildRun: Sendable, Identifiable, Codable {
    public let id: String
    public let pipelineId: String
    public let branch: String
    public let commitHash: String?
    public let status: BuildRunStatus
    public let startedAt: Date
    public let completedAt: Date?
    public let durationSeconds: Int?

    public init(id: String = UUID().uuidString, pipelineId: String, branch: String, commitHash: String? = nil, status: BuildRunStatus = .queued, startedAt: Date = .now, completedAt: Date? = nil, durationSeconds: Int? = nil) {
        self.id = id
        self.pipelineId = pipelineId
        self.branch = branch
        self.commitHash = commitHash
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
    }
}

public enum BuildRunStatus: String, Sendable, Codable {
    case queued, running, passed, failed, cancelled, skipped
}
