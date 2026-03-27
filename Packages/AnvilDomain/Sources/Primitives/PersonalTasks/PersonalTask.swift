import Foundation

public struct PersonalTask: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let isCompleted: Bool
    public let priority: PersonalTaskPriority
    public let dueDate: Date?
    public let createdAt: Date
    public let completedAt: Date?

    public init(id: String = UUID().uuidString, title: String, isCompleted: Bool = false, priority: PersonalTaskPriority = .medium, dueDate: Date? = nil, createdAt: Date = .now, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public enum PersonalTaskPriority: String, Sendable, Codable {
    case low, medium, high, urgent
}
