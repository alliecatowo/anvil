import Foundation

public struct Message: Sendable, Identifiable, Codable {
    public let id: String
    public let channelId: String
    public let threadId: String?
    public let author: String
    public let content: String
    public let timestamp: Date
    public let isEdited: Bool

    public init(id: String = UUID().uuidString, channelId: String, threadId: String? = nil, author: String, content: String, timestamp: Date = .now, isEdited: Bool = false) {
        self.id = id
        self.channelId = channelId
        self.threadId = threadId
        self.author = author
        self.content = content
        self.timestamp = timestamp
        self.isEdited = isEdited
    }
}
