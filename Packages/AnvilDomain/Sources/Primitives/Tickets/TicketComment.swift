import Foundation

public struct TicketComment: Sendable, Identifiable, Codable {
    public let id: String
    public let ticketId: String
    public let author: String
    public var body: String
    public let createdAt: Date

    public init(id: String = UUID().uuidString, ticketId: String, author: String, body: String, createdAt: Date = .now) {
        self.id = id
        self.ticketId = ticketId
        self.author = author
        self.body = body
        self.createdAt = createdAt
    }
}
