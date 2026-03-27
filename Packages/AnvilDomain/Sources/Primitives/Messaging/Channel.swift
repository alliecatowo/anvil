import Foundation

public struct Channel: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let topic: String?
    public let isPrivate: Bool
    public let memberCount: Int
    public let unreadCount: Int

    public init(id: String = UUID().uuidString, name: String, topic: String? = nil, isPrivate: Bool = false, memberCount: Int = 0, unreadCount: Int = 0) {
        self.id = id
        self.name = name
        self.topic = topic
        self.isPrivate = isPrivate
        self.memberCount = memberCount
        self.unreadCount = unreadCount
    }
}
