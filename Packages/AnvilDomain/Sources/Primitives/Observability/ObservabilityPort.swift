import Foundation

public protocol ObservabilityPort: AnvilProviderDefinition {
    func errors(projectId: String, timeRange: TimeRange?) async throws -> [ErrorEvent]
    func errorDetail(errorId: String) async throws -> ErrorEvent
    func alerts(projectId: String) async throws -> [Alert]
    func acknowledgeAlert(alertId: String) async throws
    func resolveAlert(alertId: String) async throws
    func metrics(projectId: String, query: String, timeRange: TimeRange?) async throws -> [Metric]
    func createAlert(name: String, query: String, threshold: Double) async throws -> Alert
}

public struct TimeRange: Sendable, Codable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}
