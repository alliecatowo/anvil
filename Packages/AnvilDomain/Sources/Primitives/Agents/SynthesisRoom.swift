import Foundation

public struct SynthesisRoom: Sendable, Identifiable, Codable {
    public let id: String
    public var title: String
    public let inputSessionIds: [String]
    public let synthesisModel: String
    public var status: SynthesisStatus
    public var output: String?
    public let createdAt: Date

    public init(id: String = UUID().uuidString, title: String = "Synthesis Room", inputSessionIds: [String], synthesisModel: String, status: SynthesisStatus = .pending, output: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.inputSessionIds = inputSessionIds
        self.synthesisModel = synthesisModel
        self.status = status
        self.output = output
        self.createdAt = createdAt
    }
}

public enum SynthesisStatus: String, Sendable, Codable {
    case pending, running, completed, failed
}

/// Links two agent sessions that work on related tasks.
public struct SessionLink: Sendable, Identifiable, Codable {
    public let id: String
    public let fromSessionId: String
    public let toSessionId: String
    public let label: String
    public let createdAt: Date

    public init(id: String = UUID().uuidString, fromSessionId: String, toSessionId: String, label: String = "related", createdAt: Date = .now) {
        self.id = id
        self.fromSessionId = fromSessionId
        self.toSessionId = toSessionId
        self.label = label
        self.createdAt = createdAt
    }
}
