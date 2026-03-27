import Foundation

public protocol DocumentationPort: AnvilProviderDefinition {
    func search(query: String) async throws -> [Document]
    func document(documentId: String) async throws -> Document
    func index() async throws -> DocIndex
    func createDocument(title: String, content: String, parentId: String?) async throws -> Document
    func updateDocument(documentId: String, content: String) async throws -> Document
    func deleteDocument(documentId: String) async throws
}
