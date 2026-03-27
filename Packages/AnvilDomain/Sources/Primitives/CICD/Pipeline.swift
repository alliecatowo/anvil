import Foundation

public struct Pipeline: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let repositoryId: String
    public let triggerType: PipelineTriggerType
    public let lastRunStatus: BuildRunStatus?
    public let lastRunAt: Date?

    public init(id: String = UUID().uuidString, name: String, repositoryId: String, triggerType: PipelineTriggerType = .push, lastRunStatus: BuildRunStatus? = nil, lastRunAt: Date? = nil) {
        self.id = id
        self.name = name
        self.repositoryId = repositoryId
        self.triggerType = triggerType
        self.lastRunStatus = lastRunStatus
        self.lastRunAt = lastRunAt
    }
}

public enum PipelineTriggerType: String, Sendable, Codable {
    case push, pullRequest, schedule, manual, tag
}
