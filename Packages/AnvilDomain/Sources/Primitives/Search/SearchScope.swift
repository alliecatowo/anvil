import Foundation

public struct SearchScope: Sendable, Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let category: SearchScopeCategory

    public init(id: String = UUID().uuidString, name: String, category: SearchScopeCategory) {
        self.id = id
        self.name = name
        self.category = category
    }
}

public enum SearchScopeCategory: String, Sendable, Codable, Hashable {
    case code, documentation, tickets, messages, files, all
}
