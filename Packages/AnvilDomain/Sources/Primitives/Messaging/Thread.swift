import Foundation

public struct MessageThread: Sendable, Identifiable, Codable {
    public let id: String
    public let channelId: String
    public let rootMessageId: String
    public let replyCount: Int
    public let lastReplyAt: Date?
    public let participants: [String]

    public init(id: String = UUID().uuidString, channelId: String, rootMessageId: String, replyCount: Int = 0, lastReplyAt: Date? = nil, participants: [String] = []) {
        self.id = id
        self.channelId = channelId
        self.rootMessageId = rootMessageId
        self.replyCount = replyCount
        self.lastReplyAt = lastReplyAt
        self.participants = participants
    }
}
