import Foundation

public enum ACPStreamEvent: Sendable {
    case textDelta(String)
    case toolCallStart(id: String, name: String)
    case toolCallDelta(id: String, argumentsDelta: String)
    case toolCallEnd(id: String)
    case toolResult(id: String, content: String)
    case messageComplete(ACPMessage)
    case usage(ACPUsage)
    case error(ACPError)
}

public enum ACPError: Error, Sendable {
    case invalidAPIKey(provider: String)
    case rateLimited(retryAfter: TimeInterval?)
    case modelNotAvailable(model: String)
    case contextWindowExceeded(limit: Int, actual: Int)
    case networkError(String)
    case providerError(String)
}
