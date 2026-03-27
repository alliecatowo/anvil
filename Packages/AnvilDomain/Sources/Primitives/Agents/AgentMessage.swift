import Foundation

public struct AgentMessage: Sendable, Identifiable, Codable {
    public let id: String
    public let role: AgentMessageRole
    public let content: String
    public let toolCalls: [ToolCall]
    public let timestamp: Date

    public init(id: String = UUID().uuidString, role: AgentMessageRole, content: String, toolCalls: [ToolCall] = [], timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.timestamp = timestamp
    }
}

public enum AgentMessageRole: String, Sendable, Codable {
    case user, assistant, system, tool
}
