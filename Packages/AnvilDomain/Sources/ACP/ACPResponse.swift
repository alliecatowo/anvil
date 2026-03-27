import Foundation

public struct ACPResponse: Sendable {
    public let message: ACPMessage
    public let usage: ACPUsage
    public let model: String
    public let stopReason: ACPStopReason

    public init(message: ACPMessage, usage: ACPUsage, model: String, stopReason: ACPStopReason) {
        self.message = message
        self.usage = usage
        self.model = model
        self.stopReason = stopReason
    }
}

public struct ACPUsage: Sendable, Codable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public enum ACPStopReason: String, Sendable, Codable {
    case endTurn, toolUse, maxTokens, error
}
