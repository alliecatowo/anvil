import Foundation

public struct Subtask: Sendable, Identifiable, Codable {
    public let id: String
    public let ticketId: String
    public var title: String
    public var isCompleted: Bool
    public let createdAt: Date

    public init(id: String = UUID().uuidString, ticketId: String, title: String, isCompleted: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.ticketId = ticketId
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
