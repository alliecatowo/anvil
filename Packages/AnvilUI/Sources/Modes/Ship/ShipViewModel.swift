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

// MARK: - Display Models

struct EnvironmentCard: Identifiable {
    let id: String
    let environment: HostingEnvironment
    let status: EnvironmentDeployStatus
    let lastDeployTime: Date?
    let currentURL: String?
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

    // MARK: Editing

    @Published var newEnvKey: String = ""
    @Published var newEnvValue: String = ""
    @Published var newEnvIsSecret: Bool = false

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

    // MARK: Init

    public init() {}

    // MARK: Actions

    func deploy(environmentID: String) {
        // Stub: would call HostingPort.deploy
    }

    func rollback(deploymentID: String) {
        // Stub: would call HostingPort.rollback
    }

    func addEnvVar(to environmentID: String) {
        guard !newEnvKey.isEmpty else { return }
        let envVar = EnvVar(key: newEnvKey, value: newEnvValue, isSecret: newEnvIsSecret)
        envVars[environmentID, default: []].append(envVar)
        newEnvKey = ""
        newEnvValue = ""
        newEnvIsSecret = false
    }

    func deleteEnvVar(id: String, from environmentID: String) {
        envVars[environmentID]?.removeAll { $0.id == id }
    }

    // MARK: - Sample Data (for previews only)

    #if DEBUG
    static func withSampleData() -> ShipViewModel {
        let vm = ShipViewModel()
        let (envs, deploys, logs, vars) = makeSampleData()
        vm.environments = envs
        vm.deployments = deploys
        vm.buildLogs = logs
        vm.envVars = vars
        vm.selectedEnvironmentID = envs.first?.id
        return vm
    }
    #endif

    static func makeSampleData() -> ([EnvironmentCard], [Deployment], [BuildLog], [String: [EnvVar]]) {

        let prodEnv = HostingEnvironment(id: "env-prod", name: "Production", branch: "main", url: "https://app.example.com", isProduction: true)
        let stagingEnv = HostingEnvironment(id: "env-staging", name: "Staging", branch: "develop", url: "https://staging.example.com")
        let previewEnv = HostingEnvironment(id: "env-preview", name: "Preview", branch: "feat/onboarding-v2", url: "https://preview-feat-onboarding-v2.example.com")

        let environments: [EnvironmentCard] = [
            EnvironmentCard(id: prodEnv.id, environment: prodEnv, status: .live, lastDeployTime: Date().addingTimeInterval(-3600), currentURL: prodEnv.url),
            EnvironmentCard(id: stagingEnv.id, environment: stagingEnv, status: .deploying, lastDeployTime: Date().addingTimeInterval(-300), currentURL: stagingEnv.url),
            EnvironmentCard(id: previewEnv.id, environment: previewEnv, status: .failed, lastDeployTime: Date().addingTimeInterval(-7200), currentURL: previewEnv.url),
        ]

        let deployments: [Deployment] = [
            Deployment(id: "dep-1", projectId: "proj-1", environmentId: "env-prod", commitHash: "a1b2c3d", status: .ready, url: "https://app.example.com", createdAt: Date().addingTimeInterval(-3600), completedAt: Date().addingTimeInterval(-3500)),
            Deployment(id: "dep-2", projectId: "proj-1", environmentId: "env-staging", commitHash: "e4f5g6h", status: .building, url: nil, createdAt: Date().addingTimeInterval(-300)),
            Deployment(id: "dep-3", projectId: "proj-1", environmentId: "env-preview", commitHash: "i7j8k9l", status: .failed, url: nil, createdAt: Date().addingTimeInterval(-7200), completedAt: Date().addingTimeInterval(-7100)),
            Deployment(id: "dep-4", projectId: "proj-1", environmentId: "env-prod", commitHash: "m0n1o2p", status: .cancelled, url: "https://app.example.com", createdAt: Date().addingTimeInterval(-86400), completedAt: Date().addingTimeInterval(-86300)),
        ]

        let deploymentID = "dep-2"
        let logBase = Date().addingTimeInterval(-300)
        let buildLogs: [BuildLog] = [
            BuildLog(id: "log-1", deploymentId: deploymentID, timestamp: logBase, level: .info, message: "Cloning repository..."),
            BuildLog(id: "log-2", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(2), level: .info, message: "Checked out branch: develop (e4f5g6h)"),
            BuildLog(id: "log-3", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(5), level: .info, message: "Installing dependencies..."),
            BuildLog(id: "log-4", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(15), level: .info, message: "npm install completed (1,247 packages)"),
            BuildLog(id: "log-5", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(18), level: .info, message: "Running build..."),
            BuildLog(id: "log-6", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(25), level: .warning, message: "Warning: unused import 'lodash' in src/utils/helpers.ts"),
            BuildLog(id: "log-7", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(30), level: .info, message: "TypeScript compilation successful"),
            BuildLog(id: "log-8", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(35), level: .info, message: "Running tests..."),
            BuildLog(id: "log-9", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(42), level: .info, message: "All 247 tests passed"),
            BuildLog(id: "log-10", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(45), level: .info, message: "Building Docker image..."),
            BuildLog(id: "log-11", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(60), level: .info, message: "Image built: sha256:abc123def456"),
            BuildLog(id: "log-12", deploymentId: deploymentID, timestamp: logBase.addingTimeInterval(65), level: .info, message: "Pushing to registry..."),
        ]

        let envVars: [String: [EnvVar]] = [
            "env-prod": [
                EnvVar(key: "DATABASE_URL", value: "postgresql://prod-db:5432/app", isSecret: true),
                EnvVar(key: "REDIS_URL", value: "redis://prod-redis:6379", isSecret: true),
                EnvVar(key: "NODE_ENV", value: "production"),
                EnvVar(key: "LOG_LEVEL", value: "warn"),
                EnvVar(key: "API_KEY", value: "sk-prod-abc123xyz", isSecret: true),
            ],
            "env-staging": [
                EnvVar(key: "DATABASE_URL", value: "postgresql://staging-db:5432/app", isSecret: true),
                EnvVar(key: "NODE_ENV", value: "staging"),
                EnvVar(key: "LOG_LEVEL", value: "debug"),
                EnvVar(key: "FEATURE_FLAG_V2", value: "true"),
            ],
            "env-preview": [
                EnvVar(key: "DATABASE_URL", value: "postgresql://preview-db:5432/app", isSecret: true),
                EnvVar(key: "NODE_ENV", value: "development"),
                EnvVar(key: "LOG_LEVEL", value: "debug"),
            ],
        ]

        return (environments, deployments, buildLogs, envVars)
    }
}
