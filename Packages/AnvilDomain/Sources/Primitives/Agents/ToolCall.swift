import Foundation

public struct ToolCall: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let arguments: String // JSON string
    public var status: ToolCallStatus
    public var result: ToolResult?

    public init(id: String = UUID().uuidString, name: String, arguments: String, status: ToolCallStatus = .pending, result: ToolResult? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.status = status
        self.result = result
    }
}

public enum ToolCallStatus: String, Sendable, Codable {
    case pending, approved, rejected, running, completed, failed
}

public struct ToolResult: Sendable, Codable {
    public let content: String
    public let type: ToolResultType
    public let isError: Bool

    public init(content: String, type: ToolResultType = .text, isError: Bool = false) {
        self.content = content
        self.type = type
        self.isError = isError
    }
}

public enum ToolResultType: String, Sendable, Codable {
    case text, diff, image, error, json
}
