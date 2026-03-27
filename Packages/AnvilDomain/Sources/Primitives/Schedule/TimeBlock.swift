import Foundation

public struct TimeBlock: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let category: TimeBlockCategory

    public init(id: String = UUID().uuidString, title: String, start: Date, end: Date, category: TimeBlockCategory = .deepWork) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.category = category
    }
}

public enum TimeBlockCategory: String, Sendable, Codable {
    case deepWork, meeting, admin, break_, personal
}
