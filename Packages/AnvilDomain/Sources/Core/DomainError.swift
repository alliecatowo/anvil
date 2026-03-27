import Foundation

public enum AnvilDomainError: Error, Sendable {
    case notFound(entity: String, id: String)
    case invalidState(message: String)
    case providerError(provider: String, underlying: String)
    case permissionDenied(action: String)
    case connectionFailed(service: String, reason: String)
    case timeout(operation: String, duration: TimeInterval)
    case unsupported(feature: String, provider: String)
    case conflict(message: String)
    case rateLimited(provider: String, retryAfter: TimeInterval?)
    case budgetExceeded(provider: String, limit: Decimal, current: Decimal)
}
