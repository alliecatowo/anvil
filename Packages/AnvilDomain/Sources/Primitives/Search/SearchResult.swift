import Foundation

public struct SearchResult: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let snippet: String
    public let url: String?
    public let source: String
    public let relevanceScore: Double
    public let matchedAt: Date

    public init(id: String = UUID().uuidString, title: String, snippet: String, url: String? = nil, source: String, relevanceScore: Double = 0, matchedAt: Date = .now) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.url = url
        self.source = source
        self.relevanceScore = relevanceScore
        self.matchedAt = matchedAt
    }
}
