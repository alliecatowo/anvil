import SwiftUI
import AnvilDomain

// MARK: - Ship Tab

enum ShipTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case logs = "Build Logs"
    case envVars = "Env Vars"
}

// MARK: - Environment Status (UI-level)

enum EnvironmentDeployStatus: String {
    case live, deploying, failed

    var color: Color {
        switch self {
        case .live: AnvilColor.accentGreen
        case .deploying: AnvilColor.accentAmber
        case .failed: AnvilColor.accentRed
        }
    }

    var label: String {
        switch self {
        case .live: "Live"
        case .deploying: "Deploying"
        case .failed: "Failed"
        }
    }
}

// MARK: - Health Check

enum HealthCheckStatus: String, CaseIterable {
    case healthy, degraded, down

    var color: Color {
        switch self {
        case .healthy: AnvilColor.accentGreen
        case .degraded: AnvilColor.accentAmber
        case .down: AnvilColor.accentRed
        }
    }

    var icon: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .degraded: "exclamationmark.triangle.fill"
        case .down: "xmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .healthy: "Healthy"
        case .degraded: "Degraded"
        case .down: "Down"
        }
    }
}

struct HealthCheck: Identifiable {
    let id: String
    let name: String
    let status: HealthCheckStatus
    let responseTime: Int // ms
    let lastChecked: Date

    init(id: String = UUID().uuidString, name: String, status: HealthCheckStatus, responseTime: Int, lastChecked: Date = Date()) {
        self.id = id
        self.name = name
        self.status = status
        self.responseTime = responseTime
        self.lastChecked = lastChecked
    }
}

// MARK: - Display Models

struct EnvironmentCard: Identifiable {
    let id: String
    let environment: HostingEnvironment
    var status: EnvironmentDeployStatus
    var lastDeployTime: Date?
    let currentURL: String?
    var currentVersion: String
    var currentCommit: String
    var healthChecks: [HealthCheck]

    var overallHealth: HealthCheckStatus {
        if healthChecks.contains(where: { $0.status == .down }) { return .down }
        if healthChecks.contains(where: { $0.status == .degraded }) { return .degraded }
        return .healthy
    }
}

struct EnvVar: Identifiable {
    let id: String
    var key: String
    var value: String
    var isSecret: Bool

    init(id: String = UUID().uuidString, key: String, value: String, isSecret: Bool = false) {
        self.id = id
        self.key = key
        self.value = value
        self.isSecret = isSecret
    }
}

// MARK: - Deploy History Entry

struct DeployHistoryEntry: Identifiable {
    let id: String
    let deployment: Deployment
    let triggeredBy: String
    let branch: String
    let version: String
    let duration: Int // seconds

    var durationString: String {
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Ship View Model

@MainActor
public final class ShipViewModel: ObservableObject {

    // MARK: Navigation

    @Published var selectedTab: ShipTab = .dashboard
    @Published var selectedEnvironmentID: String?

    // MARK: Data

    @Published var environments: [EnvironmentCard] = []
    @Published var deployments: [Deployment] = []
    @Published var buildLogs: [BuildLog] = []
    @Published var envVars: [String: [EnvVar]] = [:]
    @Published var deployHistory: [String: [DeployHistoryEntry]] = [:]

    // MARK: Deploy State

    @Published var isDeploying: Bool = false
    @Published var deployProgress: Double = 0.0
    @Published var deployingEnvironmentID: String?

    // MARK: Editing

    @Published var newEnvKey: String = ""
    @Published var newEnvValue: String = ""
    @Published var newEnvIsSecret: Bool = false
    @Published var editingEnvVarID: String?
    @Published var editingKey: String = ""
    @Published var editingValue: String = ""

    // MARK: Env Compare

    @Published var showingEnvCompare: Bool = false
    @Published var compareSourceID: String?
    @Published var compareTargetID: String?

    // MARK: Rollback

    @Published var showingRollbackConfirm: Bool = false
    @Published var pendingRollbackDeployID: String?
    @Published var pendingRollbackEnvID: String?

    // MARK: Delete Confirm

    @Published var showingDeleteConfirm: Bool = false
    @Published var pendingDeleteEnvVarID: String?
    @Published var pendingDeleteEnvID: String?

    // MARK: Log Streaming

    @Published var isStreamingLogs: Bool = false
    private var logStreamTask: Task<Void, Never>?

    // MARK: Computed

    var selectedEnvironment: EnvironmentCard? {
        environments.first { $0.id == selectedEnvironmentID }
    }

    var deploymentsForSelected: [Deployment] {
        guard let envID = selectedEnvironmentID else { return deployments }
        return deployments.filter { $0.environmentId == envID }
    }

    var envVarsForSelected: [EnvVar] {
        guard let envID = selectedEnvironmentID else { return [] }
        return envVars[envID] ?? []
    }

    var deployHistoryForSelected: [DeployHistoryEntry] {
        guard let envID = selectedEnvironmentID else { return [] }
        return deployHistory[envID] ?? []
    }

    var buildLogsForSelected: [BuildLog] {
        guard let envID = selectedEnvironmentID else { return buildLogs }
        let envDeploymentIDs = Set(deployments.filter { $0.environmentId == envID }.map(\.id))
        let filtered = buildLogs.filter { envDeploymentIDs.contains($0.deploymentId) }
        return filtered.isEmpty ? buildLogs : filtered
    }

    var envCompareData: [(key: String, sourceValue: String?, targetValue: String?, isDifferent: Bool)] {
        guard let sourceID = compareSourceID, let targetID = compareTargetID else { return [] }
        let sourceVars = envVars[sourceID] ?? []
        let targetVars = envVars[targetID] ?? []

        let sourceDict = Dictionary(uniqueKeysWithValues: sourceVars.map { ($0.key, $0) })
        let targetDict = Dictionary(uniqueKeysWithValues: targetVars.map { ($0.key, $0) })

        let allKeys = Set(sourceDict.keys).union(Set(targetDict.keys)).sorted()

        return allKeys.map { key in
            let sourceVar = sourceDict[key]
            let targetVar = targetDict[key]
            let sourceDisplay = sourceVar.map { $0.isSecret ? "********" : $0.value }
            let targetDisplay = targetVar.map { $0.isSecret ? "********" : $0.value }
            let isDifferent = sourceDisplay != targetDisplay
            return (key: key, sourceValue: sourceDisplay, targetValue: targetDisplay, isDifferent: isDifferent)
        }
    }

    // MARK: Init

    public init() {
        self.environments = []
        self.deployments = []
        self.buildLogs = []
        self.envVars = [:]
        self.deployHistory = [:]
        self.selectedEnvironmentID = nil
    }

    /// Load sample data for previews and demos.
    public func loadSampleData() {
        let (envs, deploys, logs, vars, history) = Self.makeSampleData()
        self.environments = envs
        self.deployments = deploys
        self.buildLogs = logs
        self.envVars = vars
        self.deployHistory = history
        self.selectedEnvironmentID = envs.first?.id
    }

    // MARK: - Deploy Action

    func deploy(environmentID: String) {
        guard !isDeploying else { return }

        isDeploying = true
        deployProgress = 0.0
        deployingEnvironmentID = environmentID

        // Mark environment as deploying
        if let idx = environments.firstIndex(where: { $0.id == environmentID }) {
            environments[idx].status = .deploying
        }

        // Simulate deploy progress
        Task { @MainActor [weak self] in
            guard let self else { return }

            let steps: [(Double, String, BuildLogLevel)] = [
                (0.05, "Cloning repository...", .info),
                (0.10, "Checking out branch...", .info),
                (0.20, "Installing dependencies...", .info),
                (0.30, "npm install completed (1,247 packages)", .info),
                (0.40, "Running build...", .info),
                (0.50, "TypeScript compilation successful", .info),
                (0.60, "Running tests...", .info),
                (0.70, "All 247 tests passed", .info),
                (0.80, "Building Docker image...", .info),
                (0.85, "Image built: sha256:abc123def456", .info),
                (0.90, "Pushing to registry...", .info),
                (0.95, "Starting deployment...", .info),
                (1.00, "Deployment complete!", .info),
            ]

            let deploymentID = "dep-\(UUID().uuidString.prefix(6))"
            let envName = self.environments.first(where: { $0.id == environmentID })?.environment.name ?? "Unknown"

            for step in steps {
                try? await Task.sleep(for: .milliseconds(400))
                self.deployProgress = step.0

                let log = BuildLog(
                    id: UUID().uuidString,
                    deploymentId: deploymentID,
                    timestamp: Date(),
                    level: step.2,
                    message: "[\(envName)] \(step.1)"
                )
                self.buildLogs.append(log)
            }

            // Complete deployment
            let newCommit = String(UUID().uuidString.prefix(7))
            let newDeployment = Deployment(
                id: deploymentID,
                projectId: "proj-1",
                environmentId: environmentID,
                commitHash: newCommit,
                status: .ready,
                url: self.environments.first(where: { $0.id == environmentID })?.currentURL,
                createdAt: Date(),
                completedAt: Date()
            )
            self.deployments.insert(newDeployment, at: 0)

            // Update environment card
            if let idx = self.environments.firstIndex(where: { $0.id == environmentID }) {
                self.environments[idx].status = .live
                self.environments[idx].lastDeployTime = Date()
                self.environments[idx].currentCommit = newCommit
            }

            // Add to history
            let newVersion = "v\(Int.random(in: 2...3)).\(Int.random(in: 0...9)).\(Int.random(in: 0...9))"
            let historyEntry = DeployHistoryEntry(
                id: deploymentID,
                deployment: newDeployment,
                triggeredBy: "You",
                branch: self.environments.first(where: { $0.id == environmentID })?.environment.branch ?? "main",
                version: newVersion,
                duration: Int.random(in: 45...180)
            )
            self.deployHistory[environmentID, default: []].insert(historyEntry, at: 0)

            self.isDeploying = false
            self.deployProgress = 0.0
            self.deployingEnvironmentID = nil
        }
    }

    // MARK: - Rollback Action

    func requestRollback(deploymentID: String, environmentID: String) {
        pendingRollbackDeployID = deploymentID
        pendingRollbackEnvID = environmentID
        showingRollbackConfirm = true
    }

    func confirmRollback() {
        guard let deployID = pendingRollbackDeployID,
              let envID = pendingRollbackEnvID else { return }

        showingRollbackConfirm = false

        if let historyEntry = deployHistory[envID]?.first(where: { $0.id == deployID }) {
            // Mark environment as deploying
            if let idx = environments.firstIndex(where: { $0.id == envID }) {
                environments[idx].status = .deploying
            }

            let rollbackDeployID = "dep-rb-\(UUID().uuidString.prefix(6))"
            let envName = environments.first(where: { $0.id == envID })?.environment.name ?? "Unknown"

            let rollbackLogs: [(String, BuildLogLevel)] = [
                ("[\(envName)] Initiating rollback to \(historyEntry.version)...", .warning),
                ("[\(envName)] Rolling back to commit \(historyEntry.deployment.commitHash ?? "unknown")...", .info),
                ("[\(envName)] Restoring container image...", .info),
                ("[\(envName)] Running health checks...", .info),
                ("[\(envName)] Rollback complete. Now serving \(historyEntry.version)", .info),
            ]

            Task { @MainActor [weak self] in
                guard let self else { return }

                for logEntry in rollbackLogs {
                    try? await Task.sleep(for: .milliseconds(300))
                    let log = BuildLog(
                        id: UUID().uuidString,
                        deploymentId: rollbackDeployID,
                        timestamp: Date(),
                        level: logEntry.1,
                        message: logEntry.0
                    )
                    self.buildLogs.append(log)
                }

                let rollbackDeployment = Deployment(
                    id: rollbackDeployID,
                    projectId: "proj-1",
                    environmentId: envID,
                    commitHash: historyEntry.deployment.commitHash,
                    status: .ready,
                    url: self.environments.first(where: { $0.id == envID })?.currentURL,
                    createdAt: Date(),
                    completedAt: Date()
                )
                self.deployments.insert(rollbackDeployment, at: 0)

                if let idx = self.environments.firstIndex(where: { $0.id == envID }) {
                    self.environments[idx].status = .live
                    self.environments[idx].lastDeployTime = Date()
                    self.environments[idx].currentVersion = historyEntry.version
                    self.environments[idx].currentCommit = historyEntry.deployment.commitHash ?? "unknown"
                }

                let entry = DeployHistoryEntry(
                    id: rollbackDeployID,
                    deployment: rollbackDeployment,
                    triggeredBy: "You (rollback)",
                    branch: historyEntry.branch,
                    version: historyEntry.version,
                    duration: 12
                )
                self.deployHistory[envID, default: []].insert(entry, at: 0)
            }
        }

        pendingRollbackDeployID = nil
        pendingRollbackEnvID = nil
    }

    func cancelRollback() {
        showingRollbackConfirm = false
        pendingRollbackDeployID = nil
        pendingRollbackEnvID = nil
    }

    // MARK: - Env Var Management

    func addEnvVar(to environmentID: String) {
        guard !newEnvKey.isEmpty else { return }
        let envVar = EnvVar(key: newEnvKey, value: newEnvValue, isSecret: newEnvIsSecret)
        envVars[environmentID, default: []].append(envVar)
        newEnvKey = ""
        newEnvValue = ""
        newEnvIsSecret = false
    }

    func startEditingEnvVar(_ envVar: EnvVar) {
        editingEnvVarID = envVar.id
        editingKey = envVar.key
        editingValue = envVar.isSecret ? "" : envVar.value
    }

    func saveEditingEnvVar(in environmentID: String) {
        guard let editID = editingEnvVarID else { return }
        if let idx = envVars[environmentID]?.firstIndex(where: { $0.id == editID }) {
            envVars[environmentID]?[idx].key = editingKey
            if !editingValue.isEmpty {
                envVars[environmentID]?[idx].value = editingValue
            }
        }
        cancelEditing()
    }

    func cancelEditing() {
        editingEnvVarID = nil
        editingKey = ""
        editingValue = ""
    }

    func requestDeleteEnvVar(id: String, from environmentID: String) {
        pendingDeleteEnvVarID = id
        pendingDeleteEnvID = environmentID
        showingDeleteConfirm = true
    }

    func confirmDeleteEnvVar() {
        guard let varID = pendingDeleteEnvVarID, let envID = pendingDeleteEnvID else { return }
        envVars[envID]?.removeAll { $0.id == varID }
        showingDeleteConfirm = false
        pendingDeleteEnvVarID = nil
        pendingDeleteEnvID = nil
    }

    func cancelDeleteEnvVar() {
        showingDeleteConfirm = false
        pendingDeleteEnvVarID = nil
        pendingDeleteEnvID = nil
    }

    func toggleEnvVarSecret(id: String, in environmentID: String) {
        if let idx = envVars[environmentID]?.firstIndex(where: { $0.id == id }) {
            envVars[environmentID]?[idx].isSecret.toggle()
        }
    }

    // MARK: - Env Compare

    func openEnvCompare() {
        let envIDs = environments.map(\.id)
        compareSourceID = selectedEnvironmentID ?? envIDs.first
        compareTargetID = envIDs.first(where: { $0 != compareSourceID }) ?? envIDs.last
        showingEnvCompare = true
    }

    // MARK: - Log Streaming

    func startLogStreaming(for environmentID: String) {
        stopLogStreaming()
        isStreamingLogs = true

        let envName = environments.first(where: { $0.id == environmentID })?.environment.name ?? "Unknown"
        let deploymentID = deploymentsForSelected.first?.id ?? "dep-stream"

        logStreamTask = Task { @MainActor [weak self] in
            let streamMessages = [
                "GET /api/health 200 OK (2ms)",
                "GET /api/users 200 OK (15ms)",
                "POST /api/auth/login 200 OK (42ms)",
                "GET /api/dashboard 200 OK (8ms)",
                "GET /static/bundle.js 304 Not Modified",
                "POST /api/webhooks/stripe 200 OK (120ms)",
                "GET /api/users/profile 200 OK (5ms)",
                "WARN: Rate limit approaching for IP 192.168.1.100",
                "GET /api/search?q=deploy 200 OK (230ms)",
                "POST /api/deployments/notify 200 OK (18ms)",
                "GET /healthz 200 OK (1ms)",
                "GET /api/metrics 200 OK (3ms)",
            ]

            var index = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 800...2500)))
                guard !Task.isCancelled, let self else { return }

                let msg = streamMessages[index % streamMessages.count]
                let level: BuildLogLevel = msg.hasPrefix("WARN") ? .warning : .info

                let log = BuildLog(
                    id: UUID().uuidString,
                    deploymentId: deploymentID,
                    timestamp: Date(),
                    level: level,
                    message: "[\(envName)] \(msg)"
                )
                self.buildLogs.append(log)
                index += 1
            }
        }
    }

    func stopLogStreaming() {
        logStreamTask?.cancel()
        logStreamTask = nil
        isStreamingLogs = false
    }

    // MARK: - Sample Data

    #if DEBUG
    static func withSampleData() -> ShipViewModel {
        let vm = ShipViewModel()
        let (envs, deploys, logs, vars, history) = makeSampleData()
        vm.environments = envs
        vm.deployments = deploys
        vm.buildLogs = logs
        vm.envVars = vars
        vm.deployHistory = history
        vm.selectedEnvironmentID = envs.first?.id
        return vm
    }
    #endif

    static func makeSampleData() -> ([EnvironmentCard], [Deployment], [BuildLog], [String: [EnvVar]], [String: [DeployHistoryEntry]]) {

        let prodEnv = HostingEnvironment(id: "env-prod", name: "Production", branch: "main", url: "https://app.example.com", isProduction: true)
        let stagingEnv = HostingEnvironment(id: "env-staging", name: "Staging", branch: "develop", url: "https://staging.example.com")
        let devEnv = HostingEnvironment(id: "env-dev", name: "Development", branch: "feat/onboarding-v2", url: "https://dev.example.com")

        let environments: [EnvironmentCard] = [
            EnvironmentCard(
                id: prodEnv.id, environment: prodEnv, status: .live,
                lastDeployTime: Date().addingTimeInterval(-3600), currentURL: prodEnv.url,
                currentVersion: "v2.4.1", currentCommit: "a1b2c3d",
                healthChecks: [
                    HealthCheck(name: "API Server", status: .healthy, responseTime: 12),
                    HealthCheck(name: "Database", status: .healthy, responseTime: 3),
                    HealthCheck(name: "Redis Cache", status: .healthy, responseTime: 1),
                    HealthCheck(name: "CDN", status: .healthy, responseTime: 8),
                ]
            ),
            EnvironmentCard(
                id: stagingEnv.id, environment: stagingEnv, status: .deploying,
                lastDeployTime: Date().addingTimeInterval(-300), currentURL: stagingEnv.url,
                currentVersion: "v2.5.0-rc1", currentCommit: "e4f5g6h",
                healthChecks: [
                    HealthCheck(name: "API Server", status: .healthy, responseTime: 45),
                    HealthCheck(name: "Database", status: .degraded, responseTime: 250),
                    HealthCheck(name: "Redis Cache", status: .healthy, responseTime: 2),
                ]
            ),
            EnvironmentCard(
                id: devEnv.id, environment: devEnv, status: .live,
                lastDeployTime: Date().addingTimeInterval(-7200), currentURL: devEnv.url,
                currentVersion: "v2.5.0-dev", currentCommit: "i7j8k9l",
                healthChecks: [
                    HealthCheck(name: "API Server", status: .healthy, responseTime: 22),
                    HealthCheck(name: "Database", status: .healthy, responseTime: 5),
                ]
            ),
        ]

        let deployments: [Deployment] = [
            Deployment(id: "dep-1", projectId: "proj-1", environmentId: "env-prod", commitHash: "a1b2c3d", status: .ready, url: "https://app.example.com", createdAt: Date().addingTimeInterval(-3600), completedAt: Date().addingTimeInterval(-3500)),
            Deployment(id: "dep-2", projectId: "proj-1", environmentId: "env-staging", commitHash: "e4f5g6h", status: .building, url: nil, createdAt: Date().addingTimeInterval(-300)),
            Deployment(id: "dep-3", projectId: "proj-1", environmentId: "env-dev", commitHash: "i7j8k9l", status: .ready, url: "https://dev.example.com", createdAt: Date().addingTimeInterval(-7200), completedAt: Date().addingTimeInterval(-7100)),
            Deployment(id: "dep-4", projectId: "proj-1", environmentId: "env-prod", commitHash: "m0n1o2p", status: .ready, url: "https://app.example.com", createdAt: Date().addingTimeInterval(-86400), completedAt: Date().addingTimeInterval(-86300)),
            Deployment(id: "dep-5", projectId: "proj-1", environmentId: "env-prod", commitHash: "q3r4s5t", status: .ready, url: "https://app.example.com", createdAt: Date().addingTimeInterval(-172800), completedAt: Date().addingTimeInterval(-172700)),
            Deployment(id: "dep-6", projectId: "proj-1", environmentId: "env-staging", commitHash: "u6v7w8x", status: .ready, url: "https://staging.example.com", createdAt: Date().addingTimeInterval(-43200), completedAt: Date().addingTimeInterval(-43100)),
            Deployment(id: "dep-7", projectId: "proj-1", environmentId: "env-staging", commitHash: "y9z0a1b", status: .failed, url: nil, createdAt: Date().addingTimeInterval(-86400)),
            Deployment(id: "dep-8", projectId: "proj-1", environmentId: "env-dev", commitHash: "c2d3e4f", status: .ready, url: "https://dev.example.com", createdAt: Date().addingTimeInterval(-14400), completedAt: Date().addingTimeInterval(-14300)),
            Deployment(id: "dep-9", projectId: "proj-1", environmentId: "env-dev", commitHash: "g5h6i7j", status: .cancelled, url: nil, createdAt: Date().addingTimeInterval(-28800)),
            Deployment(id: "dep-10", projectId: "proj-1", environmentId: "env-prod", commitHash: "k8l9m0n", status: .ready, url: "https://app.example.com", createdAt: Date().addingTimeInterval(-259200), completedAt: Date().addingTimeInterval(-259100)),
        ]

        let deploymentID = "dep-2"
        let logBase = Date().addingTimeInterval(-300)
        let buildLogs: [BuildLog] = [
            BuildLog(id: "log-1", deploymentId: deploymentID, timestamp: logBase, level: .info, message: "[Staging] Cloning repository..."),
            BuildLog(id: "log-2", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(2), level: .info, message: "[Staging] Checked out branch: develop (e4f5g6h)"),
            BuildLog(id: "log-3", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(5), level: .info, message: "[Staging] Installing dependencies..."),
            BuildLog(id: "log-4", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(15), level: .info, message: "[Staging] npm install completed (1,247 packages)"),
            BuildLog(id: "log-5", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(18), level: .info, message: "[Staging] Running build..."),
            BuildLog(id: "log-6", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(25), level: .warning, message: "[Staging] Warning: unused import 'lodash' in src/utils/helpers.ts"),
            BuildLog(id: "log-7", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(30), level: .info, message: "[Staging] TypeScript compilation successful"),
            BuildLog(id: "log-8", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(35), level: .info, message: "[Staging] Running tests..."),
            BuildLog(id: "log-9", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(42), level: .info, message: "[Staging] All 247 tests passed"),
            BuildLog(id: "log-10", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(45), level: .info, message: "[Staging] Building Docker image..."),
            BuildLog(id: "log-11", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(60), level: .info, message: "[Staging] Image built: sha256:abc123def456"),
            BuildLog(id: "log-12", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(65), level: .info, message: "[Staging] Pushing to registry..."),
            BuildLog(id: "log-13", deploymentId: "dep-1", timestamp: logBase.addingTimeInterval(-3300), level: .info, message: "[Production] Deploying v2.4.1..."),
            BuildLog(id: "log-14", deploymentId: "dep-1", timestamp: logBase.addingTimeInterval(-3290), level: .info, message: "[Production] Build completed successfully"),
            BuildLog(id: "log-15", deploymentId: "dep-1", timestamp: logBase.addingTimeInterval(-3280), level: .info, message: "[Production] Health checks passed"),
            BuildLog(id: "log-16", deploymentId: "dep-1", timestamp: logBase.addingTimeInterval(-3270), level: .info, message: "[Production] Deployment complete"),
            BuildLog(id: "log-17", deploymentId: "dep-3", timestamp: logBase.addingTimeInterval(-6900), level: .info, message: "[Development] Deploying v2.5.0-dev..."),
            BuildLog(id: "log-18", deploymentId: "dep-3", timestamp: logBase.addingTimeInterval(-6890), level: .info, message: "[Development] Build completed"),
            BuildLog(id: "log-19", deploymentId: "dep-3", timestamp: logBase.addingTimeInterval(-6880), level: .warning, message: "[Development] 3 deprecation warnings in build output"),
            BuildLog(id: "log-20", deploymentId: "dep-3", timestamp: logBase.addingTimeInterval(-6870), level: .info, message: "[Development] Deployment complete"),
        ]

        let envVars: [String: [EnvVar]] = [
            "env-prod": [
                EnvVar(key: "DATABASE_URL", value: "postgresql://prod-db.internal:5432/app_production", isSecret: true),
                EnvVar(key: "REDIS_URL", value: "redis://prod-redis.internal:6379", isSecret: true),
                EnvVar(key: "API_KEY", value: "sk-prod-a1b2c3d4e5f6g7h8i9j0", isSecret: true),
                EnvVar(key: "STRIPE_SECRET_KEY", value: "sk_live_xxxxxxxxxxxx", isSecret: true),
                EnvVar(key: "NODE_ENV", value: "production"),
                EnvVar(key: "LOG_LEVEL", value: "warn"),
                EnvVar(key: "CORS_ORIGIN", value: "https://app.example.com"),
                EnvVar(key: "SENTRY_DSN", value: "https://abc123@sentry.io/12345", isSecret: true),
            ],
            "env-staging": [
                EnvVar(key: "DATABASE_URL", value: "postgresql://staging-db.internal:5432/app_staging", isSecret: true),
                EnvVar(key: "REDIS_URL", value: "redis://staging-redis.internal:6379", isSecret: true),
                EnvVar(key: "API_KEY", value: "sk-staging-test123456", isSecret: true),
                EnvVar(key: "STRIPE_SECRET_KEY", value: "sk_test_xxxxxxxxxxxx", isSecret: true),
                EnvVar(key: "NODE_ENV", value: "staging"),
                EnvVar(key: "LOG_LEVEL", value: "debug"),
                EnvVar(key: "CORS_ORIGIN", value: "https://staging.example.com"),
                EnvVar(key: "FEATURE_FLAG_V2", value: "true"),
            ],
            "env-dev": [
                EnvVar(key: "DATABASE_URL", value: "postgresql://localhost:5432/app_dev", isSecret: true),
                EnvVar(key: "REDIS_URL", value: "redis://localhost:6379", isSecret: true),
                EnvVar(key: "API_KEY", value: "sk-dev-localkey123", isSecret: true),
                EnvVar(key: "NODE_ENV", value: "development"),
                EnvVar(key: "LOG_LEVEL", value: "debug"),
                EnvVar(key: "CORS_ORIGIN", value: "http://localhost:3000"),
                EnvVar(key: "FEATURE_FLAG_V2", value: "true"),
                EnvVar(key: "HOT_RELOAD", value: "true"),
            ],
        ]

        var deployHistory: [String: [DeployHistoryEntry]] = [:]

        deployHistory["env-prod"] = [
            DeployHistoryEntry(id: "dep-1", deployment: deployments[0], triggeredBy: "CI/CD Pipeline", branch: "main", version: "v2.4.1", duration: 95),
            DeployHistoryEntry(id: "dep-4", deployment: deployments[3], triggeredBy: "alice@team.com", branch: "main", version: "v2.4.0", duration: 102),
            DeployHistoryEntry(id: "dep-5", deployment: deployments[4], triggeredBy: "CI/CD Pipeline", branch: "main", version: "v2.3.9", duration: 88),
            DeployHistoryEntry(id: "dep-10", deployment: deployments[9], triggeredBy: "bob@team.com", branch: "main", version: "v2.3.8", duration: 110),
        ]

        deployHistory["env-staging"] = [
            DeployHistoryEntry(id: "dep-2", deployment: deployments[1], triggeredBy: "CI/CD Pipeline", branch: "develop", version: "v2.5.0-rc1", duration: 0),
            DeployHistoryEntry(id: "dep-6", deployment: deployments[5], triggeredBy: "alice@team.com", branch: "develop", version: "v2.5.0-beta3", duration: 78),
            DeployHistoryEntry(id: "dep-7", deployment: deployments[6], triggeredBy: "CI/CD Pipeline", branch: "develop", version: "v2.5.0-beta2", duration: 45),
        ]

        deployHistory["env-dev"] = [
            DeployHistoryEntry(id: "dep-3", deployment: deployments[2], triggeredBy: "You", branch: "feat/onboarding-v2", version: "v2.5.0-dev", duration: 62),
            DeployHistoryEntry(id: "dep-8", deployment: deployments[7], triggeredBy: "You", branch: "feat/onboarding-v2", version: "v2.5.0-dev.2", duration: 55),
            DeployHistoryEntry(id: "dep-9", deployment: deployments[8], triggeredBy: "You", branch: "feat/onboarding-v2", version: "v2.5.0-dev.1", duration: 0),
        ]

        return (environments, deployments, buildLogs, envVars, deployHistory)
    }
}
