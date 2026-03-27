import Foundation

public struct Ticket: Sendable, Identifiable, Codable {
    public let id: String
    public var title: String
    public var description: String
    public var status: String
    public var priority: TicketPriority
    public var assignee: String?
    public var labels: [String]
    public var dueDate: Date?
    public var storyPoints: Int?
    public var epicId: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, title: String, description: String = "", status: String = "open", priority: TicketPriority = .medium, assignee: String? = nil, labels: [String] = [], dueDate: Date? = nil, storyPoints: Int? = nil, epicId: String? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.assignee = assignee
        self.labels = labels
        self.dueDate = dueDate
        self.storyPoints = storyPoints
        self.epicId = epicId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum TicketPriority: Int, Sendable, Codable, Comparable {
    case critical = 0
    case high = 1
    case medium = 2
    case low = 3
    case none = 4

    public static func < (lhs: TicketPriority, rhs: TicketPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct TicketDraft: Sendable {
    public let title: String
    public let description: String
    public let priority: TicketPriority
    public let labels: [String]
    public let assignee: String?
    public let epicId: String?

    public init(title: String, description: String = "", priority: TicketPriority = .medium, labels: [String] = [], assignee: String? = nil, epicId: String? = nil) {
        self.title = title
        self.description = description
        self.priority = priority
        self.labels = labels
        self.assignee = assignee
        self.epicId = epicId
    }
}

public struct TicketUpdate: Sendable {
    public var title: String?
    public var description: String?
    public var status: String?
    public var priority: TicketPriority?
    public var assignee: String?
    public var labels: [String]?
    public var dueDate: Date?
    public var storyPoints: Int?

    public init(title: String? = nil, description: String? = nil, status: String? = nil, priority: TicketPriority? = nil, assignee: String? = nil, labels: [String]? = nil, dueDate: Date? = nil, storyPoints: Int? = nil) {
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.assignee = assignee
        self.labels = labels
        self.dueDate = dueDate
        self.storyPoints = storyPoints
    }
}

public struct TicketFilter: Sendable {
    public var status: String?
    public var priority: TicketPriority?
    public var assignee: String?
    public var labels: [String]?
    public var epicId: String?

    public init(status: String? = nil, priority: TicketPriority? = nil, assignee: String? = nil, labels: [String]? = nil, epicId: String? = nil) {
        self.status = status
        self.priority = priority
        self.assignee = assignee
        self.labels = labels
        self.epicId = epicId
    }
}
