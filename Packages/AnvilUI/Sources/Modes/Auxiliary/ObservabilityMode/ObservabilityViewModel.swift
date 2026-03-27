import SwiftUI
import AnvilDomain

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

// MARK: - View Model

@MainActor
final class ObservabilityViewModel: ObservableObject {

    // MARK: Navigation

    @Published var selectedTab: ObservabilityTab = .errors
    @Published var selectedErrorID: String?

    // MARK: Data

    @Published var errors: [ErrorItem] = []
    @Published var metrics: [MetricCard] = []

    // MARK: Computed

    var selectedError: ErrorItem? {
        errors.first { $0.id == selectedErrorID }
    }

    var criticalCount: Int {
        errors.filter { $0.severity == .critical }.count
    }

    // MARK: Init

    init() {
        let (sampleErrors, sampleMetrics) = Self.makeSampleData()
        self.errors = sampleErrors
        self.metrics = sampleMetrics
        self.selectedErrorID = sampleErrors.first?.id
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
                    tags: ["service": "exercise-service", "env": "production"]
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
                    tags: ["service": "exercise-service", "env": "production", "dependency": "redis"]
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
                    tags: ["service": "analytics-service", "env": "staging"]
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
                    tags: ["service": "exercise-service", "flag": "exercise-v2"]
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
}
