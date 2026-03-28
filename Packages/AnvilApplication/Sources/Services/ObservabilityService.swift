import Foundation
import AnvilDomain

/// Application-layer service for observability operations.
/// Mediates between the UI and the ObservabilityPort adapter (e.g. Sentry).
@MainActor
public final class ObservabilityService: ObservableObject {
    private var adapter: (any ObservabilityPort)?

    @Published public var isConnected: Bool = false
    @Published public var lastError: String?
    @Published public var projectId: String = ""

    public init() {}

    public func setAdapter(_ adapter: any ObservabilityPort) {
        self.adapter = adapter
    }

    public var hasAdapter: Bool { adapter != nil }

    // MARK: - Connection

    public func connect(projectId: String) async {
        guard let adapter else {
            lastError = "No observability adapter configured"
            return
        }
        self.projectId = projectId
        do {
            let valid = try await adapter.validateConnection()
            isConnected = valid
            if !valid {
                lastError = "Connection validation failed"
            } else {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
            isConnected = false
        }
    }

    public func disconnect() {
        isConnected = false
        projectId = ""
    }

    // MARK: - Errors

    public func fetchErrors(timeRange: TimeRange? = nil) async -> [ErrorEvent] {
        guard let adapter, isConnected else { return [] }
        do {
            let events = try await adapter.errors(projectId: projectId, timeRange: timeRange)
            lastError = nil
            return events
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    public func fetchErrorDetail(errorId: String) async -> ErrorEvent? {
        guard let adapter, isConnected else { return nil }
        do {
            let event = try await adapter.errorDetail(errorId: errorId)
            lastError = nil
            return event
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Alerts

    public func fetchAlerts() async -> [Alert] {
        guard let adapter, isConnected else { return [] }
        do {
            let alerts = try await adapter.alerts(projectId: projectId)
            lastError = nil
            return alerts
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    // MARK: - Metrics

    public func fetchMetrics(query: String = "", timeRange: TimeRange? = nil) async -> [Metric] {
        guard let adapter, isConnected else { return [] }
        do {
            let metrics = try await adapter.metrics(projectId: projectId, query: query, timeRange: timeRange)
            lastError = nil
            return metrics
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }
}
