import Foundation

public enum AgentStreamEvent: Sendable {
    case textDelta(String)
    case toolCallStart(id: String, name: String)
    case toolCallDelta(id: String, argumentsDelta: String)
    case toolCallEnd(id: String)
    case toolCallResult(id: String, result: ToolResult)
    case usage(TokenUsage)
    case sessionComplete
    case error(String)
}
