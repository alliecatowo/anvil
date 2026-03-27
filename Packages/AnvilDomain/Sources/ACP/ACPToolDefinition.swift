import Foundation

public struct ACPToolDefinition: Sendable, Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let inputSchema: String // JSON Schema as string

    public init(name: String, description: String, inputSchema: String) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}
