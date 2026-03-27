import Foundation

public struct SynthesisRoom: Sendable, Identifiable, Codable {
    public let id: String
    public let inputSessionIds: [String]
    public let synthesisModel: String
    public var status: SynthesisStatus
    public var output: String?
    public let createdAt: Date

    public init(id: String = UUID().uuidString, inputSessionIds: [String], synthesisModel: String, status: SynthesisStatus = .pending, output: String? = nil, createdAt: Date = .now) {
        self.id = id
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
