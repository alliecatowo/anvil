import Foundation

public struct ErrorEvent: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let message: String
    public let stackTrace: String?
    public let occurrences: Int
    public let firstSeen: Date
    public let lastSeen: Date
    public let isResolved: Bool
    public let tags: [String: String]

    public init(id: String = UUID().uuidString, title: String, message: String, stackTrace: String? = nil, occurrences: Int = 1, firstSeen: Date = .now, lastSeen: Date = .now, isResolved: Bool = false, tags: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.message = message
        self.stackTrace = stackTrace
        self.occurrences = occurrences
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.isResolved = isResolved
        self.tags = tags
    }
}
