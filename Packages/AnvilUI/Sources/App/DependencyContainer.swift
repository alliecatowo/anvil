import Foundation
import AnvilDomain
import AnvilApplication
import AnvilACP
import AnvilGit
import AnvilGitHub

/// Central dependency container that wires all layers together.
/// ViewModels access ports and services through this container.
@MainActor
public final class DependencyContainer: ObservableObject {
    // MARK: - Services

    public let eventBus = EventBus.shared
    public let acpRouter = ACPRouter()
    public let pluginManager = PluginManager()
    public let projectManager = ProjectManager()
    public let notificationAggregator = NotificationAggregator()
    public let searchIndexer = SearchIndexer()
    public let worktreeOrchestrator = WorktreeOrchestrator()

    // MARK: - Git Adapter

    private var gitAdapter: GitSourceControlAdapter?

    public func getOrCreateGitAdapter() -> GitSourceControlAdapter? {
        guard let path = currentProjectPath else { return nil }
        if let adapter = gitAdapter { return adapter }
        let adapter = GitSourceControlAdapter(workingDirectory: path)
        gitAdapter = adapter
        return adapter
    }

    // MARK: - GitHub Auth

    let gitHubAuth = GitHubAuthViewModel()

    // MARK: - GitHub Adapter

    private var gitHubAdapter: GitHubSourceControlCloudAdapter?

    public func getOrCreateGitHubAdapter() -> GitHubSourceControlCloudAdapter? {
        if let adapter = gitHubAdapter { return adapter }
        // Look for a GitHub PAT in configured providers or env
        if let ghConfig = configuredProviders.values.first(where: { $0.providerType == "github" }),
           let token = ghConfig.apiKey {
            let adapter = GitHubSourceControlCloudAdapter(token: token)
            gitHubAdapter = adapter
            return adapter
        }
        // Check Keychain for OAuth token
        if let token = KeychainHelper.load(account: GitHubOAuthService.keychainAccount) {
            let adapter = GitHubSourceControlCloudAdapter(token: token)
            gitHubAdapter = adapter
            return adapter
        }
        // Fall back to GITHUB_TOKEN env var
        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !token.isEmpty {
            let adapter = GitHubSourceControlCloudAdapter(token: token)
            gitHubAdapter = adapter
            return adapter
        }
        return nil
    }

    /// Reset the cached GitHub adapter (e.g. after token change).
    public func resetGitHubAdapter() {
        gitHubAdapter = nil
    }

    // MARK: - ACP Client

    private var acpClient: ACPClient?

    public func getOrCreateACPClient() async -> ACPClient {
        if let client = acpClient { return client }
        let client = ACPClient()
        for (_, config) in configuredProviders {
            switch config.providerType {
            case "claude-cli":
                let provider = ClaudeCLIProvider(cliPath: config.baseURL ?? "")
                await client.registerProvider(provider)
                if config.isDefault { await client.setDefaultProvider(provider.providerId) }
            case "claude-process":
                let cliPath = config.baseURL ?? ""
                await client.registerProcessProvider(id: config.providerId, path: cliPath)
                if config.isDefault { await client.setDefaultProvider("claude-process") }
            case "anthropic":
                if let apiKey = config.apiKey {
                    let provider = AnthropicProvider(apiKey: apiKey)
                    await client.registerProvider(provider)
                    if config.isDefault { await client.setDefaultProvider(provider.providerId) }
                }
            case "openai":
                if let apiKey = config.apiKey {
                    let provider = OpenAIProvider(apiKey: apiKey)
                    await client.registerProvider(provider)
                    if config.isDefault { await client.setDefaultProvider(provider.providerId) }
                }
            case "ollama":
                let provider = OllamaProvider(baseURL: config.baseURL ?? "http://localhost:11434")
                await client.registerProvider(provider)
                if config.isDefault { await client.setDefaultProvider(provider.providerId) }
            case "zed-acp":
                let cmd = config.baseURL ?? "npx"
                let cmdArgs = config.apiKey.map { [$0] } ?? ["@agentclientprotocol/claude-agent-acp"]
                let provider = ZedACPProvider(command: cmd, args: cmdArgs)
                await client.registerProvider(provider)
                if config.isDefault { await client.setDefaultProvider(provider.providerId) }
            default:
                break
            }
        }

        // Auto-register Claude CLI if no providers are configured and the binary exists.
        // Prefer Zed ACP adapter when available (bidirectional protocol with streaming).
        if configuredProviders.isEmpty {
            if ZedACPProvider.isAvailable() {
                let provider = ZedACPProvider(
                    command: "npx",
                    args: ["@agentclientprotocol/claude-agent-acp"]
                )
                await client.registerProvider(provider)
                await client.setDefaultProvider(provider.providerId)
            } else if ClaudeCLIProvider.isAvailable() {
                let provider = ClaudeCLIProvider()
                await client.registerProvider(provider)
                await client.setDefaultProvider(provider.providerId)
            }
        }

        acpClient = client
        return client
    }

    // MARK: - Review Management

    public let reviewService: any ReviewManagementPort = InMemoryReviewService()

    // MARK: - Ticket Provider (External)

    /// Which external ticket provider the user has selected.
    public enum TicketProviderChoice: String, Sendable, CaseIterable {
        case github
        case linear
        case jira
        case none
    }

    @Published public var selectedTicketProvider: TicketProviderChoice = .none

    /// External ticket port adapter (e.g. GitHub Issues, Linear). Injected from App target.
    private var _ticketPort: (any TicketPort)?
    public var ticketPort: (any TicketPort)? { _ticketPort }

    /// Set the external ticket port adapter and test its connection.
    public func setTicketAdapter(_ adapter: any TicketPort) {
        _ticketPort = adapter
        testIntegration(adapter.providerId) { try await adapter.validateConnection() }
    }

    /// Remove the external ticket port adapter.
    public func removeTicketAdapter() {
        if let id = _ticketPort?.providerId {
            integrationStatus.removeValue(forKey: id)
        }
        _ticketPort = nil
        selectedTicketProvider = .none
    }

    // MARK: - Ticket Management (Internal)

    public private(set) var ticketService: any TicketManagementPort = InMemoryTicketService()

    /// Replace the ticket service (e.g. with a persistent SQLite-backed implementation).
    public func setTicketService(_ service: any TicketManagementPort) {
        ticketService = service
    }

    // MARK: - Deployment Management

    public let deploymentService: any DeploymentManagementPort = InMemoryDeploymentService()

    // MARK: - Messaging Service

    public let messagingService: any MessagingPort = InMemoryMessagingService()

    // MARK: - Schedule Service

    public let scheduleService: any SchedulePort = InMemoryScheduleService()

    // MARK: - Testing Service

    public let testingService: any TestingPort = InMemoryTestingService()

    // MARK: - Observability In-Memory Service

    public let observabilityInMemoryService: any ObservabilityPort = InMemoryObservabilityService()

    // MARK: - Notification Service

    public let notificationService: any NotificationPort = InMemoryNotificationService()

    // MARK: - Documentation Service

    public let documentationService: any DocumentationPort = InMemoryDocumentationService()

    // MARK: - Database Service

    public let databaseService = DatabaseService()

    // MARK: - Observability Service

    public let observabilityService = ObservabilityService()

    // MARK: - File System

    public let fileSystemService = FileSystemService()

    // MARK: - Integration Providers

    /// Connection status for each integration provider.
    @Published public var integrationStatus: [String: IntegrationConnectionStatus] = [:]

    /// Hosting port adapter (e.g. Vercel). Injected from App target.
    private var _hostingPort: (any HostingPort)?
    public var hostingPort: (any HostingPort)? { _hostingPort }

    /// Observability port adapter (e.g. Sentry). Injected from App target.
    private var _observabilityPort: (any ObservabilityPort)?
    public var observabilityPort: (any ObservabilityPort)? { _observabilityPort }

    /// Messaging port adapter (e.g. Slack). Injected from App target.
    private var _messagingPort: (any MessagingPort)?
    public var messagingPort: (any MessagingPort)? { _messagingPort }

    public enum IntegrationConnectionStatus: String {
        case connected, disconnected, testing, error
    }

    /// Set the hosting port adapter and test connection.
    public func setHostingAdapter(_ adapter: any HostingPort) {
        _hostingPort = adapter
        testIntegration("vercel") { try await adapter.validateConnection() }
    }

    /// Set the observability port adapter and test connection.
    public func setObservabilityAdapter(_ adapter: any ObservabilityPort) {
        _observabilityPort = adapter
        testIntegration("sentry") { try await adapter.validateConnection() }
    }

    /// Set the messaging port adapter and test connection.
    public func setMessagingAdapter(_ adapter: any MessagingPort) {
        _messagingPort = adapter
        testIntegration("slack") { try await adapter.validateConnection() }
    }

    /// Remove an integration adapter and clear its status.
    public func removeIntegration(_ id: String) {
        switch id {
        case "vercel": _hostingPort = nil
        case "sentry": _observabilityPort = nil
        case "slack": _messagingPort = nil
        default: break
        }
        integrationStatus.removeValue(forKey: id)
    }

    private func testIntegration(_ id: String, validate: @escaping @Sendable () async throws -> Bool) {
        integrationStatus[id] = .testing
        Task { @MainActor [weak self] in
            do {
                let ok = try await validate()
                self?.integrationStatus[id] = ok ? .connected : .error
            } catch {
                self?.integrationStatus[id] = .error
            }
        }
    }

    /// Check whether an integration has stored credentials.
    public func hasIntegrationCredentials(for provider: String) -> Bool {
        switch provider {
        case "vercel": return ProviderKeychain.vercelToken != nil
        case "sentry": return ProviderKeychain.sentryToken != nil && ProviderKeychain.sentryOrganization != nil
        case "slack": return ProviderKeychain.slackToken != nil
        case "docker": return ProviderKeychain.dockerSocketPath != nil
        case "github-issues": return ProviderKeychain.githubToken != nil && ProviderKeychain.githubOwner != nil
        case "linear": return ProviderKeychain.linearApiKey != nil
        default: return false
        }
    }

    // MARK: - Configuration

    @Published public var currentProjectPath: String?
    @Published public var configuredProviders: [String: ProviderConfig] = [:]

    // MARK: - Ports (resolved lazily from configuration)

    private var _sourceControlPort: (any SourceControlPort)?
    private var _acpPort: (any ACPPort)?

    public var sourceControlPort: (any SourceControlPort)? {
        _sourceControlPort
    }

    public var acpPort: (any ACPPort)? {
        _acpPort
    }

    // MARK: - Notification Store (for event-driven notifications)

    @Published public var eventNotifications: [EventNotification] = []

    public struct EventNotification: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let body: String
        public let timestamp: Date

        public init(id: String = UUID().uuidString, title: String, body: String, timestamp: Date = .now) {
            self.id = id
            self.title = title
            self.body = body
            self.timestamp = timestamp
        }
    }

    // MARK: - Init

    public init() {
        loadSavedConfiguration()
        Task { await wireEventHandlers() }
    }

    // MARK: - Event Bus Wiring

    private func wireEventHandlers() async {
        // OnAgentCompleted → create review item notification
        await eventBus.subscribe(to: String(describing: AgentCompletedEvent.self)) { [weak self] event in
            guard let self, let e = event as? AgentCompletedEvent else { return }
            let branch = e.branchName.map { " (branch: \($0))" } ?? ""
            let notification = EventNotification(
                title: "Agent session completed",
                body: "Session \(e.sessionId) finished\(branch). Worktree ready for review."
            )
            await MainActor.run { self.eventNotifications.insert(notification, at: 0) }
        }

        // OnPRMerged → notify about linked ticket closure
        await eventBus.subscribe(to: String(describing: PRMergedEvent.self)) { [weak self] event in
            guard let self, let e = event as? PRMergedEvent else { return }
            let ticketSuffix = e.linkedTicketId.map { " Ticket \($0) can be closed." } ?? ""
            let notification = EventNotification(
                title: "PR merged",
                body: "PR \(e.pullRequestId) merged in \(e.repo) [\(e.branch)].\(ticketSuffix)"
            )
            await MainActor.run { self.eventNotifications.insert(notification, at: 0) }
        }

        // OnBuildFailed → create notification
        await eventBus.subscribe(to: String(describing: BuildFailedEvent.self)) { [weak self] event in
            guard let self, let e = event as? BuildFailedEvent else { return }
            let body = e.failureReason.map { "[\(e.branch)] \($0)" } ?? "[\(e.branch)] Build failed in \(e.pipelineName)"
            let notification = EventNotification(
                title: "Build failed: \(e.pipelineName)",
                body: body
            )
            await MainActor.run { self.eventNotifications.insert(notification, at: 0) }
        }
    }

    // MARK: - Configuration

    public struct ProviderConfig: Codable, Sendable {
        public let providerId: String
        public let providerType: String // "claude-cli", "anthropic", "openai", "ollama"
        public var apiKey: String?
        public var baseURL: String?
        public var isDefault: Bool

        public init(providerId: String, providerType: String, apiKey: String? = nil, baseURL: String? = nil, isDefault: Bool = false) {
            self.providerId = providerId
            self.providerType = providerType
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.isDefault = isDefault
        }
    }

    // MARK: - Project Management

    /// Open a directory as a single-repo project. Creates or finds an existing project.
    /// Routes through CreateProjectUseCase for name derivation to stay in the DDD use-case layer.
    public func openProject(at path: String) async {
        // Check if a project with this repo already exists
        if let existing = await projectManager.project(containingRepo: path) {
            await switchToProject(existing.id)
            return
        }

        let useCase = makeCreateProjectUseCase()
        let name = (try? await useCase.execute(source: .fromDirectory(path: path)))
            ?? URL(fileURLWithPath: path).lastPathComponent

        let project = Project(name: name, repoPaths: [path])
        await projectManager.addProject(project)
        await switchToProject(project.id)
    }

    /// Switch to an existing project by ID. Updates git adapter, project path, etc.
    public func switchToProject(_ projectId: String) async {
        await projectManager.setCurrentProject(projectId)
        guard let project = await projectManager.project(byId: projectId) else { return }

        // Garbage collect stale worktrees from the previous project before switching
        if let oldAdapter = gitAdapter {
            Task {
                try? await worktreeOrchestrator.cleanupStale(provider: oldAdapter)
            }
        }

        // Use primary repo path for git adapter
        currentProjectPath = project.primaryRepoPath
        gitAdapter = nil // Reset so next getOrCreateGitAdapter() picks up new path
    }

    /// Create a new project with the given name and repo paths.
    public func createProject(name: String, description: String = "", repoPaths: [String]) async -> Project {
        let project = Project(name: name, description: description, repoPaths: repoPaths)
        await projectManager.addProject(project)
        await switchToProject(project.id)
        return project
    }

    /// Update project metadata (name, description, repos).
    public func updateProject(_ project: Project) async {
        await projectManager.updateProject(project)
        // If this is the current project and repos changed, refresh the git adapter
        if let currentId = await projectManager.getCurrentProjectId(), currentId == project.id {
            currentProjectPath = project.primaryRepoPath
            gitAdapter = nil
        }
    }

    /// Remove a project from the store.
    public func removeProject(_ id: String) async {
        let wasCurrent = await projectManager.getCurrentProjectId() == id
        await projectManager.removeProject(id)
        if wasCurrent {
            currentProjectPath = nil
            gitAdapter = nil
        }
    }

    // MARK: - Provider Configuration

    public func configureProvider(_ config: ProviderConfig) {
        configuredProviders[config.providerId] = config
        saveConfiguration()
    }

    public func removeProvider(_ providerId: String) {
        configuredProviders.removeValue(forKey: providerId)
        saveConfiguration()
    }

    // MARK: - Use Cases

    public func makeStartAgentSessionUseCase() -> StartAgentSessionUseCase {
        StartAgentSessionUseCase()
    }

    public func makeAutoCommitUseCase() -> AutoCommitUseCase {
        AutoCommitUseCase()
    }

    public func makeSubmitReviewUseCase() -> SubmitReviewUseCase {
        SubmitReviewUseCase()
    }

    public func makeAIReviewUseCase() -> AIReviewUseCase {
        AIReviewUseCase()
    }

    public func makeGenerateCommitMessageUseCase() -> GenerateCommitMessageUseCase {
        GenerateCommitMessageUseCase()
    }

    public func makeCreateReviewUseCase() -> CreateReviewUseCase {
        CreateReviewUseCase(reviewPort: reviewService, eventBus: eventBus)
    }

    public func makeCreateTicketUseCase() -> CreateTicketUseCase {
        CreateTicketUseCase(ticketPort: ticketService, eventBus: eventBus)
    }

    public func makeCreateDeploymentUseCase() -> CreateDeploymentUseCase {
        CreateDeploymentUseCase(deploymentPort: deploymentService, eventBus: eventBus)
    }

    public func makeUpdateReviewUseCase() -> UpdateReviewUseCase {
        UpdateReviewUseCase(reviewPort: reviewService, eventBus: eventBus)
    }

    public func makeCreateProjectUseCase() -> CreateProjectUseCase {
        CreateProjectUseCase()
    }

    public func makeSwitchAgentProviderUseCase() -> SwitchAgentProviderUseCase {
        SwitchAgentProviderUseCase()
    }

    public func makeCreateWorktreeUseCase() -> CreateWorktreeUseCase {
        CreateWorktreeUseCase()
    }

    // MARK: - Persistence

    private let configURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".anvil/config/providers.json")

    private func loadSavedConfiguration() {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }
        guard let data = try? Data(contentsOf: configURL),
              let configs = try? JSONDecoder().decode([String: ProviderConfig].self, from: data) else { return }
        configuredProviders = configs
    }

    private func saveConfiguration() {
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(configuredProviders) {
            try? data.write(to: configURL)
        }
    }
}

// MARK: - File System Service

/// Reads directory trees and file contents from disk.
@MainActor
public final class FileSystemService {

    public struct FileNode: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let path: String
        public let isDirectory: Bool
        public var children: [FileNode]?

        public init(id: String, name: String, path: String, isDirectory: Bool, children: [FileNode]? = nil) {
            self.id = id
            self.name = name
            self.path = path
            self.isDirectory = isDirectory
            self.children = children
        }
    }

    private static let ignoredNames: Set<String> = [
        ".git", ".build", ".swiftpm", "node_modules", ".DS_Store",
        "DerivedData", "Pods", ".hg", ".svn", "xcuserdata",
    ]

    public init() {}

    /// Recursively read a directory tree, skipping common noise directories.
    public func readTree(at path: String, maxDepth: Int = 3) -> [FileNode] {
        readTreeRecursive(at: path, currentDepth: 0, maxDepth: maxDepth)
    }

    /// Read the full text contents of a file.
    public func readFile(at path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func readTreeRecursive(at path: String, currentDepth: Int, maxDepth: Int) -> [FileNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        var nodes: [FileNode] = []

        let sorted = entries.sorted { lhs, rhs in
            let lhsIsDir = self.isDirectory(atPath: (path as NSString).appendingPathComponent(lhs))
            let rhsIsDir = self.isDirectory(atPath: (path as NSString).appendingPathComponent(rhs))
            if lhsIsDir != rhsIsDir { return lhsIsDir }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        for entry in sorted {
            guard !Self.ignoredNames.contains(entry) else { continue }
            guard !entry.hasPrefix(".") || entry == ".env.example" else { continue }

            let fullPath = (path as NSString).appendingPathComponent(entry)
            let isDir = isDirectory(atPath: fullPath)

            if isDir {
                let children: [FileNode]?
                if currentDepth < maxDepth {
                    children = readTreeRecursive(at: fullPath, currentDepth: currentDepth + 1, maxDepth: maxDepth)
                } else {
                    children = nil
                }
                nodes.append(FileNode(id: fullPath, name: entry, path: fullPath, isDirectory: true, children: children))
            } else {
                nodes.append(FileNode(id: fullPath, name: entry, path: fullPath, isDirectory: false))
            }
        }

        return nodes
    }

    private func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
