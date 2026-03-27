import Foundation

public struct ACPMessage: Sendable, Codable {
    public let role: ACPMessageRole
    public let content: String
    public let toolCallId: String?

    public init(role: ACPMessageRole, content: String, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
    }
}

public enum ACPMessageRole: String, Sendable, Codable {
    case system, user, assistant, tool
}
