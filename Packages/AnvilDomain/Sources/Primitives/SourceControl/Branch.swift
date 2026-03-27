import Foundation

public struct Branch: Sendable, Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public let upstream: String?
    public let aheadCount: Int
    public let behindCount: Int
    public let isCurrent: Bool
    public let lastCommitDate: Date?
    public let lastCommitMessage: String?

    public init(name: String, upstream: String? = nil, aheadCount: Int = 0, behindCount: Int = 0, isCurrent: Bool = false, lastCommitDate: Date? = nil, lastCommitMessage: String? = nil) {
        self.name = name
        self.upstream = upstream
        self.aheadCount = aheadCount
        self.behindCount = behindCount
        self.isCurrent = isCurrent
        self.lastCommitDate = lastCommitDate
        self.lastCommitMessage = lastCommitMessage
    }
}
