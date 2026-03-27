import Foundation

public actor SearchIndexer {
    public struct IndexEntry: Sendable {
        public let id: String
        public let primitive: String
        public let title: String
        public let content: String
        public let path: String?
        public let timestamp: Date
    }

    private var entries: [IndexEntry] = []

    public init() {}

    public func index(_ entry: IndexEntry) {
        entries.append(entry)
    }

    public func search(query: String) -> [IndexEntry] {
        let queryLower = query.lowercased()
        return entries.filter { entry in
            entry.title.lowercased().contains(queryLower) ||
            entry.content.lowercased().contains(queryLower)
        }
    }

    public func clear(primitive: String) {
        entries.removeAll { $0.primitive == primitive }
    }
}
