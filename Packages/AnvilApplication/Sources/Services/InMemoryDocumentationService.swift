import AnvilDomain
import Foundation

/// In-memory documentation store -- default implementation until a real backend (e.g. Notion) is wired.
public actor InMemoryDocumentationService: DocumentationPort {
    private var documents: [String: Document] = [:]

    public let providerId = "in-memory-documentation"
    public let providerName = "In-Memory Documentation"

    public init() {
        let gettingStarted = Document(
            title: "Getting Started",
            content: "Welcome to Anvil. This guide walks you through initial setup.",
            author: "system"
        )
        let architecture = Document(
            title: "Architecture Overview",
            content: "Anvil uses hexagonal architecture with ports and adapters.",
            parentId: gettingStarted.id,
            author: "system"
        )
        documents[gettingStarted.id] = gettingStarted
        documents[architecture.id] = architecture
    }

    public func validateConnection() async throws -> Bool { true }

    public func search(query: String) async throws -> [Document] {
        let lowered = query.lowercased()
        return documents.values.filter {
            $0.title.lowercased().contains(lowered) || $0.content.lowercased().contains(lowered)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func document(documentId: String) async throws -> Document {
        guard let doc = documents[documentId] else { throw DocumentationServiceError.notFound }
        return doc
    }

    public func index() async throws -> DocIndex {
        let entries = documents.values.map {
            DocIndexEntry(id: $0.id, title: $0.title, path: "/\($0.id)", parentId: $0.parentId)
        }.sorted { $0.title < $1.title }
        return DocIndex(entries: entries, totalCount: entries.count)
    }

    public func createDocument(title: String, content: String, parentId: String?) async throws -> Document {
        let doc = Document(title: title, content: content, parentId: parentId, author: "local-user")
        documents[doc.id] = doc
        return doc
    }

    public func updateDocument(documentId: String, content: String) async throws -> Document {
        guard let existing = documents[documentId] else { throw DocumentationServiceError.notFound }
        let updated = Document(
            id: existing.id,
            title: existing.title,
            content: content,
            url: existing.url,
            parentId: existing.parentId,
            author: existing.author,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        documents[documentId] = updated
        return updated
    }

    public func deleteDocument(documentId: String) async throws {
        guard documents.removeValue(forKey: documentId) != nil else {
            throw DocumentationServiceError.notFound
        }
    }
}

public enum DocumentationServiceError: Error, Sendable {
    case notFound
}
