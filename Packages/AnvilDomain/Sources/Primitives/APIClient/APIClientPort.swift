import Foundation

public protocol APIClientPort: AnvilProviderDefinition {
    func collections() async throws -> [RequestCollection]
    func collection(collectionId: String) async throws -> RequestCollection
    func send(request: HTTPRequest) async throws -> HTTPResponse
    func importCollection(from url: String) async throws -> RequestCollection
    func saveRequest(request: HTTPRequest, collectionId: String) async throws
    func deleteRequest(requestId: String) async throws
}
