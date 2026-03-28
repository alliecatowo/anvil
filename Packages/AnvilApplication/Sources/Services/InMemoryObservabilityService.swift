import AnvilDomain
import Foundation

/// In-memory observability store -- default implementation until a real backend (e.g. Sentry) is wired.
public actor InMemoryObservabilityService: ObservabilityPort {
    private var errors: [String: ErrorEvent] = [:]
    private var alerts: [String: Alert] = [:]
    private var metrics: [Metric] = []

    public let providerId = "in-memory-observability"
    public let providerName = "In-Memory Observability"

    public init() {
        let err = ErrorEvent(
            title: "NullPointerException",
            message: "Unexpected nil in UserService.fetchProfile",
            stackTrace: "UserService.swift:42\nProfileViewModel.swift:18",
            occurrences: 12
        )
        errors[err.id] = err

        let alert = Alert(name: "High Error Rate", query: "error.rate > 5", threshold: 5.0, status: .ok)
        alerts[alert.id] = alert

        metrics = [
            Metric(name: "request.duration", value: 142.0, unit: "ms", tags: ["endpoint": "/api/users"]),
            Metric(name: "error.rate", value: 0.3, unit: "%", tags: ["service": "api"]),
        ]
    }

    public func validateConnection() async throws -> Bool { true }

    public func errors(projectId: String, timeRange: TimeRange?) async throws -> [ErrorEvent] {
        Array(errors.values).sorted { $0.lastSeen > $1.lastSeen }
    }

    public func errorDetail(errorId: String) async throws -> ErrorEvent {
        guard let err = errors[errorId] else { throw ObservabilityServiceError.notFound }
        return err
    }

    public func alerts(projectId: String) async throws -> [Alert] {
        Array(alerts.values).sorted { $0.name < $1.name }
    }

    public func acknowledgeAlert(alertId: String) async throws {
        guard let existing = alerts[alertId] else { throw ObservabilityServiceError.notFound }
        alerts[alertId] = Alert(
            id: existing.id,
            name: existing.name,
            query: existing.query,
            threshold: existing.threshold,
            status: .acknowledged,
            triggeredAt: existing.triggeredAt,
            acknowledgedAt: Date()
        )
    }

    public func resolveAlert(alertId: String) async throws {
        guard let existing = alerts[alertId] else { throw ObservabilityServiceError.notFound }
        alerts[alertId] = Alert(
            id: existing.id,
            name: existing.name,
            query: existing.query,
            threshold: existing.threshold,
            status: .resolved,
            triggeredAt: existing.triggeredAt,
            acknowledgedAt: existing.acknowledgedAt
        )
    }

    public func metrics(projectId: String, query: String, timeRange: TimeRange?) async throws -> [Metric] {
        if query.isEmpty { return metrics }
        let lowered = query.lowercased()
        return metrics.filter { $0.name.lowercased().contains(lowered) }
    }

    public func createAlert(name: String, query: String, threshold: Double) async throws -> Alert {
        let alert = Alert(name: name, query: query, threshold: threshold)
        alerts[alert.id] = alert
        return alert
    }
}

public enum ObservabilityServiceError: Error, Sendable {
    case notFound
}
