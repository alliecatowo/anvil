import Foundation

public struct VoiceSession: Sendable, Identifiable, Codable {
    public let id: String
    public let language: String?
    public let status: VoiceSessionStatus
    public let startedAt: Date
    public let endedAt: Date?

    public init(id: String = UUID().uuidString, language: String? = nil, status: VoiceSessionStatus = .active, startedAt: Date = .now, endedAt: Date? = nil) {
        self.id = id
        self.language = language
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public enum VoiceSessionStatus: String, Sendable, Codable {
    case active, paused, completed, failed
}
