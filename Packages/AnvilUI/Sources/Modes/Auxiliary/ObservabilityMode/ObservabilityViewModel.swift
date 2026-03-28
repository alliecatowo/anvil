import SwiftUI
import AnvilDomain
import AnvilApplication

// MARK: - Observability Tab

enum ObservabilityTab: String, CaseIterable {
    case errors = "Errors"
    case metrics = "Metrics"
}

// MARK: - Severity (UI-level)

enum ErrorSeverity: String, CaseIterable {
    case critical, warning, info

    var color: Color {
        switch self {
        case .critical: AnvilColor.accentRed
        case .warning: AnvilColor.accentAmber
        case .info: AnvilColor.accentBlue
        }
    }

    var icon: String {
        switch self {
        case .critical: "exclamationmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    init(from event: ErrorEvent) {
        let title = event.title.lowercased()
        let level = event.tags["level"]?.lowercased()
        if level == "fatal" || level == "error" || title.contains("error") || title.contains("exception") || event.occurrences > 100 {
            self = .critical
        } else if level == "warning" || title.contains("warning") || title.contains("deprecat") {
            self = .warning
        } else {
            self = .info
        }
    }
}

// MARK: - Display Models

struct ErrorItem: Identifiable {
    let id: String
    let event: ErrorEvent
    let severity: ErrorSeverity
    let affectedUsers: Int
    let breadcrumbs: [String]
}

struct MetricCard: Identifiable {
    let id: String
    let title: String
    let value: String
    let subtitle: String
    let trend: MetricTrend
    let color: Color
}

enum MetricTrend: String {
    case up, down, flat

    var icon: String {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .up: AnvilColor.accentRed
        case .down: AnvilColor.accentGreen
        case .flat: AnvilColor.textTertiary
        }
    }
}

/// Data point for error trend chart.
struct ErrorTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Double
}

// MARK: - View Model

@MainActor
final class ObservabilityViewModel: ObservableObject {

    // MARK: Navigation

    @Published var selectedTab: ObservabilityTab = .errors
    @Published var selectedErrorID: String?

    // MARK: Data

    @Published var errors: [ErrorItem] = []
    @Published var alerts: [AnvilDomain.Alert] = []
    @Published var metrics: [MetricCard] = []
    @Published var errorTrend: [ErrorTrendPoint] = []
    @Published var detailedError: ErrorEvent?

    // MARK: Connection State

    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var sentryOrg: String = ""
    @Published var sentryProject: String = ""
    @Published var sentryToken: String = ""
    @Published var usingDemoData: Bool = false

    // MARK: Computed

    var selectedError: ErrorItem? {
        errors.first { $0.id == selectedErrorID }
    }

    var criticalCount: Int {
        errors.filter { $0.severity == .critical }.count
    }

    private weak var observabilityService: ObservabilityService?

    func configure(service: ObservabilityService) {
        self.observabilityService = service
        self.isConnected = service.isConnected
    }

    // MARK: - Connection

    func connectToSentry() async {
        guard let service = observabilityService else {
            errorMessage = "Observability service not configured"
            return
        }
        isLoading = true
        errorMessage = nil

        await service.connect(projectId: sentryProject)
        isConnected = service.isConnected
        errorMessage = service.lastError

        if isConnected {
            usingDemoData = false
            await loadErrors()
            await loadMetrics()
        }
        isLoading = false
    }

    func disconnect() {
        observabilityService?.disconnect()
        isConnected = false
        errors = []
        alerts = []
        metrics = []
        errorTrend = []
        detailedError = nil
        selectedErrorID = nil
        usingDemoData = false
    }

    func loadDemoData() {
        let (sampleErrors, sampleMetrics) = Self.makeSampleData()
        self.errors = sampleErrors
        self.metrics = sampleMetrics
        self.errorTrend = Self.makeSampleTrend()
        self.selectedErrorID = sampleErrors.first?.id
        self.usingDemoData = true
    }

    // MARK: - Data Loading

    func loadErrors() async {
        guard let service = observabilityService, isConnected else { return }
        isLoading = true

        let now = Date()
        let dayAgo = now.addingTimeInterval(-86400)
        let range = TimeRange(start: dayAgo, end: now)

        let events = await service.fetchErrors(timeRange: range)
        errorMessage = service.lastError

        self.errors = events.map { event in
            ErrorItem(
                id: event.id,
                event: event,
                severity: ErrorSeverity(from: event),
                affectedUsers: event.tags["users"].flatMap(Int.init) ?? event.occurrences / 3,
                breadcrumbs: [] // Populated on detail fetch
            )
        }

        if selectedErrorID == nil {
            selectedErrorID = errors.first?.id
        }

        isLoading = false
    }

    func loadErrorDetail(errorId: String) async {
        guard let service = observabilityService, isConnected else { return }
        detailedError = await service.fetchErrorDetail(errorId: errorId)
        errorMessage = service.lastError
    }

    func loadMetrics() async {
        guard let service = observabilityService, isConnected else { return }

        let now = Date()
        let dayAgo = now.addingTimeInterval(-86400)
        let range = TimeRange(start: dayAgo, end: now)

        let rawMetrics = await service.fetchMetrics(query: "", timeRange: range)
        errorMessage = service.lastError

        // Build trend data from raw time series
        self.errorTrend = rawMetrics.map { metric in
            ErrorTrendPoint(date: metric.timestamp, count: metric.value)
        }

        // Build summary cards from aggregated data
        let totalErrors = rawMetrics.reduce(0.0) { $0 + $1.value }
        let avgRate = rawMetrics.isEmpty ? 0 : totalErrors / Double(rawMetrics.count)

        self.metrics = [
            MetricCard(id: "m-1", title: "Total Errors (24h)", value: formatNumber(totalErrors), subtitle: "Last 24 hours", trend: totalErrors > 100 ? .up : .flat, color: AnvilColor.accentRed),
            MetricCard(id: "m-2", title: "Avg Error Rate", value: String(format: "%.1f/hr", avgRate), subtitle: "Per time bucket", trend: avgRate > 10 ? .up : .down, color: AnvilColor.accentAmber),
            MetricCard(id: "m-3", title: "Unique Issues", value: "\(errors.count)", subtitle: "Active issues", trend: errors.count > 10 ? .up : .flat, color: AnvilColor.accentBlue),
            MetricCard(id: "m-4", title: "Critical", value: "\(criticalCount)", subtitle: "Requires attention", trend: criticalCount > 0 ? .up : .down, color: AnvilColor.accentRed),
        ]
    }

    func refresh() async {
        if usingDemoData { return }
        await loadErrors()
        await loadMetrics()
        await loadAlerts()
    }

    func selectError(_ id: String) {
        selectedErrorID = id
        if !usingDemoData {
            Task { await loadErrorDetail(errorId: id) }
        }
    }

    // MARK: - Alerts

    func loadAlerts() async {
        guard let service = observabilityService, isConnected else { return }
        let fetched = await service.fetchAlerts()
        self.alerts = fetched
    }

    func acknowledgeAlert(alertId: String) {
        guard let index = alerts.firstIndex(where: { $0.id == alertId }) else { return }
        alerts[index].status = .acknowledged
        alerts[index].acknowledgedAt = Date()
        // Reassign to trigger @Published update
        alerts = alerts
    }

    func resolveAlert(alertId: String) {
        guard let index = alerts.firstIndex(where: { $0.id == alertId }) else { return }
        alerts[index].status = .resolved
        // Reassign to trigger @Published update
        alerts = alerts
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Double) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", n / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", n / 1_000) }
        return String(format: "%.0f", n)
    }

    // MARK: - Sample Data

    static func makeSampleData() -> ([ErrorItem], [MetricCard]) {
        let now = Date()

        let errors: [ErrorItem] = [
            ErrorItem(
                id: "err-1",
                event: ErrorEvent(
                    id: "err-1",
                    title: "TypeError: Cannot read property 'map' of undefined",
                    message: "Unhandled exception in ExerciseListController.getAll",
                    stackTrace: """
                    TypeError: Cannot read property 'map' of undefined
                        at ExerciseListController.getAll (src/exercise/controllers/exercise-list.controller.ts:42:18)
                        at processTicksAndRejections (node:internal/process/task_queues:95:5)
                        at /src/common/interceptors/logging.interceptor.ts:28:20
                        at NestInterceptorConsumer.intercept (node_modules/@nestjs/core/interceptors/interceptors-consumer.js:12:28)
                        at target (node_modules/@nestjs/core/router/router-execution-context.js:51:36)
                    """,
                    occurrences: 247,
                    firstSeen: now.addingTimeInterval(-86400 * 3),
                    lastSeen: now.addingTimeInterval(-120),
                    tags: ["service": "exercise-service", "env": "production", "level": "error"]
                ),
                severity: .critical,
                affectedUsers: 1_842,
                breadcrumbs: [
                    "User navigated to /exercises",
                    "GET /api/v1/exercises?page=1",
                    "ExerciseListController.getAll invoked",
                    "DailyETSessionConfigBroker returned null",
                    "TypeError thrown at line 42"
                ]
            ),
            ErrorItem(
                id: "err-2",
                event: ErrorEvent(
                    id: "err-2",
                    title: "ConnectionTimeoutError: Redis connection timed out",
                    message: "Redis client failed to connect within 5000ms",
                    stackTrace: """
                    ConnectionTimeoutError: Redis connection timed out
                        at RedisClient.connect (node_modules/ioredis/built/Redis.js:204:17)
                        at CacheService.get (src/common/cache/cache.service.ts:31:5)
                        at SessionConfigCache.lookup (src/exercise/infrastructure/cache/session-config.cache.ts:18:12)
                    """,
                    occurrences: 89,
                    firstSeen: now.addingTimeInterval(-7200),
                    lastSeen: now.addingTimeInterval(-300),
                    tags: ["service": "exercise-service", "env": "production", "dependency": "redis", "level": "error"]
                ),
                severity: .critical,
                affectedUsers: 634,
                breadcrumbs: [
                    "CacheService.get called for session config",
                    "Redis connection pool exhausted",
                    "Timeout after 5000ms",
                    "Fallback to database query"
                ]
            ),
            ErrorItem(
                id: "err-3",
                event: ErrorEvent(
                    id: "err-3",
                    title: "DeprecationWarning: collection.ensureIndex is deprecated",
                    message: "Use createIndex instead of ensureIndex in MongoDB driver",
                    stackTrace: """
                    DeprecationWarning: collection.ensureIndex is deprecated. Use createIndexes instead.
                        at NativeCollection.ensureIndex (node_modules/mongoose/lib/drivers/node-mongodb-native/collection.js:149:28)
                        at AnalyticsRepository.init (src/analytics/infrastructure/repositories/analytics.repository.ts:22:8)
                    """,
                    occurrences: 12,
                    firstSeen: now.addingTimeInterval(-86400 * 14),
                    lastSeen: now.addingTimeInterval(-86400),
                    tags: ["service": "analytics-service", "env": "staging", "level": "warning"]
                ),
                severity: .warning,
                affectedUsers: 0,
                breadcrumbs: [
                    "Service startup",
                    "MongoDB connection established",
                    "ensureIndex called on analytics collection"
                ]
            ),
            ErrorItem(
                id: "err-4",
                event: ErrorEvent(
                    id: "err-4",
                    title: "INFO: Feature flag 'exercise-v2' evaluated to false",
                    message: "Feature flag check returned default value for 3 users in segment",
                    stackTrace: nil,
                    occurrences: 1_503,
                    firstSeen: now.addingTimeInterval(-86400 * 7),
                    lastSeen: now.addingTimeInterval(-60),
                    tags: ["service": "exercise-service", "flag": "exercise-v2", "level": "info"]
                ),
                severity: .info,
                affectedUsers: 3,
                breadcrumbs: [
                    "FeatureFlagService.evaluate called",
                    "Flag 'exercise-v2' not in active segment",
                    "Returned default value: false"
                ]
            ),
        ]

        let metrics: [MetricCard] = [
            MetricCard(id: "m-1", title: "Error Rate", value: "2.4%", subtitle: "+0.8% from last hour", trend: .up, color: AnvilColor.accentRed),
            MetricCard(id: "m-2", title: "P99 Latency", value: "842ms", subtitle: "-12ms from last hour", trend: .down, color: AnvilColor.accentGreen),
            MetricCard(id: "m-3", title: "Request Count", value: "14.2K", subtitle: "Last 15 minutes", trend: .flat, color: AnvilColor.accentBlue),
            MetricCard(id: "m-4", title: "Apdex Score", value: "0.91", subtitle: "-0.03 from yesterday", trend: .up, color: AnvilColor.accentAmber),
            MetricCard(id: "m-5", title: "Active Users", value: "3,847", subtitle: "Currently connected", trend: .flat, color: AnvilColor.accentPurple),
        ]

        return (errors, metrics)
    }

    static func makeSampleTrend() -> [ErrorTrendPoint] {
        let now = Date()
        return (0..<24).map { hour in
            let date = now.addingTimeInterval(-Double(23 - hour) * 3600)
            let base = 15.0 + Double.random(in: -5...10)
            let spike = hour == 18 ? 45.0 : 0.0
            return ErrorTrendPoint(date: date, count: max(0, base + spike))
        }
    }
}
