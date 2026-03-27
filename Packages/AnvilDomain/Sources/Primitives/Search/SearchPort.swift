import Foundation

public protocol SearchPort: AnvilProviderDefinition {
    func search(query: String, scopes: [SearchScope]) async throws -> [SearchResult]
    func recentSearches() async throws -> [String]
    func availableScopes() async throws -> [SearchScope]
}
