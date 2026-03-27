import Foundation

public struct DailyLog: Sendable, Identifiable, Codable {
    public let id: String
    public let date: Date
    public let content: String
    public let tasksCompleted: Int
    public let updatedAt: Date

    public init(id: String = UUID().uuidString, date: Date = .now, content: String, tasksCompleted: Int = 0, updatedAt: Date = .now) {
        self.id = id
        self.date = date
        self.content = content
        self.tasksCompleted = tasksCompleted
        self.updatedAt = updatedAt
    }
}
