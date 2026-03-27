import Foundation

public protocol AnalyticsPort: AnvilProviderDefinition {
    func usageMetrics(timeRange: TimeRange?) async throws -> [UsageMetric]
    func costReport(timeRange: TimeRange?) async throws -> CostReport
    func trackEvent(name: String, properties: [String: String]) async throws
}
