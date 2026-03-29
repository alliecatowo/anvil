import AppKit
import SwiftUI
import UserNotifications
import AnvilUI
import AnvilApplication
import AnvilInfrastructure

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        MacNotificationService.shared.installDelegate(self)
    }

    // Show notifications even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle notification tap — bring app to front
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { NSApp.activate(ignoringOtherApps: true) }
    }
}

@main
struct AnvilMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer()
    @State private var showSetupWizard = Self.shouldShowSetupWizard

    private static let shouldShowSetupWizard: Bool = {
        if ProcessInfo.processInfo.environment["ANVIL_SKIP_SETUP_WIZARD"] == "1" {
            return false
        }
        return SetupWizardViewModel.isFirstLaunch
    }()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(container)
                .task {
                    // Fast deterministic bootstrap for visual/UI-test scenarios.
                    let launchEnvironment = ProcessInfo.processInfo.environment
                    if launchEnvironment["ANVIL_UITEST_SCENARIO"] != nil {
                        appState.applyUITestScenarioIfNeeded(launchEnvironment)
                        return
                    }

                    // Restore last-opened project from disk
                    if let project = await container.projectManager.currentProject() {
                        appState.currentProject = project
                        appState.currentProjectPath = project.primaryRepoPath
                        container.currentProjectPath = project.primaryRepoPath
                    }
                    // Wire terminal sessions to use the project working directory
                    appState.terminalViewModel.configure(projectPath: appState.currentProjectPath)

                    if let adapter = container.getOrCreateGitAdapter() {
                        await appState.loadGitStatus(from: adapter)
                    }

                    // Register all commands into the unified registry
                    registerBuiltInCommands(registry: container.commandRegistry, appState: appState)

                    // Wire persistent ticket storage (SQLite)
                    let ticketRepo = SQLiteTicketRepository()
                    try? await ticketRepo.open()
                    container.setTicketService(ticketRepo)

                    // Wire ticket management port and use case into view model
                    appState.intentViewModel.configure(
                        ticketPort: container.ticketService,
                        createUseCase: container.makeCreateTicketUseCase()
                    )

                    // Wire persistent agent session storage (SQLite)
                    let sessionRepo = SQLiteAgentSessionRepository()
                    try? await sessionRepo.open()
                    container.setAgentSessionPort(sessionRepo)
                    appState.agentViewModel.configure(sessionPort: sessionRepo)

                    // Wire worktree orchestrator for isolated agent sessions
                    appState.agentViewModel.configure(
                        worktreeOrchestrator: container.worktreeOrchestrator,
                        sourceControlPort: container.getOrCreateGitAdapter()
                    )

                    // Wire SQLite database adapter
                    let sqliteAdapter = SQLiteDatabaseAdapter()
                    container.databaseService.setAdapter(sqliteAdapter)

                    // Inject observability adapter factory (keeps Infrastructure out of UI)
                    container.observabilityAdapterFactory = { token, org in
                        SentryObservabilityAdapter(authToken: token, organization: org)
                    }

                    // Wire external ticket provider based on available credentials
                    wireTicketProvider(container: container)

                    // Wire hosting provider (Vercel or Netlify) based on credentials
                    wireHostingProvider(container: container)

                    // Wire hosting port into ship view model for real deploy pipeline
                    if let hostingPort = container.hostingPort {
                        appState.shipViewModel.configure(hostingPort: hostingPort)
                    }

                    // Wire messaging providers (in-memory baseline + external adapters if configured)
                    wireMessagingProviders(container: container)

                    // Request macOS notification authorization and subscribe to domain events
                    await MacNotificationService.shared.requestAuthorization()
                    await wireNotificationEvents(eventBus: container.eventBus)

                    // Wire auto-PR on agent session completion
                    await wireAutoPR(eventBus: container.eventBus, appState: appState, container: container)
                }
                .sheet(isPresented: $showSetupWizard) {
                    SetupWizard {
                        showSetupWizard = false
                    }
                    .environmentObject(container)
                    .environmentObject(appState)
                    .frame(minWidth: 800, minHeight: 600)
                    .interactiveDismissDisabled()
                }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1400, height: 900)
        .commands {
            AnvilCommands(appState: appState)
            SidebarCommands()
            InspectorCommands()
        }

        Settings {
            SettingsWindow()
                .environmentObject(appState)
                .environmentObject(container)
        }
    }

    /// Detect stored credentials and wire the matching external ticket provider.
    /// Reads tokens from the Infrastructure-layer KeychainStore (service: com.anvil.providers)
    /// which shares the same Keychain entries as ProviderKeychain in AnvilUI.
    @MainActor
    private func wireTicketProvider(container: DependencyContainer) {
        let keychain = KeychainStore(service: "com.anvil.providers")

        // Prefer GitHub Issues when credentials are present
        if let token = try? keychain.get("github.token"), !token.isEmpty,
           let owner = try? keychain.get("github.owner"), !owner.isEmpty,
           let repo = try? keychain.get("github.repo"), !repo.isEmpty {
            let provider = GitHubIssuesTicketProvider(owner: owner, repo: repo, token: token)
            container.setTicketAdapter(provider)
            container.selectedTicketProvider = .github
            return
        }

        // Fall back to Linear
        if let apiKey = try? keychain.get("linear.apiKey"), !apiKey.isEmpty {
            let teamId = (try? keychain.get("linear.teamId")) ?? nil
            let provider = LinearTicketProvider(apiKey: apiKey, teamId: teamId)
            container.setTicketAdapter(provider)
            container.selectedTicketProvider = .linear
            return
        }

        // No external ticket provider configured; the in-memory service handles local tickets.
        container.selectedTicketProvider = .none
    }

    /// Detect stored hosting credentials and wire the matching adapter (Vercel or Netlify).
    @MainActor
    private func wireHostingProvider(container: DependencyContainer) {
        let keychain = KeychainStore(service: "com.anvil.providers")

        // Prefer Vercel when credentials are present
        if let token = try? keychain.get("vercel.apiToken"), !token.isEmpty {
            let teamId = try? keychain.get("vercel.teamId")
            let adapter = VercelHostingAdapter(apiToken: token, teamId: teamId)
            container.setHostingAdapter(adapter)
            return
        }

        // Fall back to Netlify
        if let token = try? keychain.get("netlify.token"), !token.isEmpty {
            let siteId = try? keychain.get("netlify.siteId")
            let adapter = NetlifyHostingAdapter(apiToken: token, siteId: siteId)
            container.setHostingAdapter(adapter)
            return
        }
    }

    /// Wire messaging providers with a provider-agnostic baseline.
    /// Always registers in-memory messaging, then overlays external providers when configured.
    /// Reads from the same Keychain service as ProviderKeychain in AnvilUI.
    @MainActor
    private func wireMessagingProviders(container: DependencyContainer) {
        // Always keep a local provider available.
        container.registerMessagingAdapter(InMemoryMessagingService(), setActive: true)

        let keychain = KeychainStore(service: "com.anvil.providers")

        guard let botToken = try? keychain.get("slack.botToken"), !botToken.isEmpty else {
            return
        }

        let adapter = SlackMessagingAdapter(botToken: botToken)
        // External provider becomes active when available, while keeping the local provider registered.
        container.registerMessagingAdapter(adapter, setActive: true)
    }

    /// Subscribe to domain events and fire macOS notifications for key moments.
    private func wireNotificationEvents(eventBus: EventBus) async {
        let notifier = MacNotificationService.shared

        // Agent session completed
        await eventBus.subscribe(to: String(describing: AgentCompletedEvent.self)) { event in
            guard let e = event as? AgentCompletedEvent else { return }
            notifier.notifyAgentCompleted(
                sessionId: e.sessionId,
                workItemId: e.workItemId,
                branchName: e.branchName
            )
        }

        // PR merged (review-related)
        await eventBus.subscribe(to: String(describing: PRMergedEvent.self)) { event in
            guard let e = event as? PRMergedEvent else { return }
            notifier.send(
                title: "PR merged",
                body: "PR \(e.pullRequestId) merged in \(e.repo) [\(e.branch)]",
                category: MacNotificationService.Category.prReviewRequested,
                userInfo: ["prId": e.pullRequestId, "repo": e.repo]
            )
        }

        // Build/deploy failed
        await eventBus.subscribe(to: String(describing: BuildFailedEvent.self)) { event in
            guard let e = event as? BuildFailedEvent else { return }
            let reason = e.failureReason ?? "Build failed"
            notifier.notifyDeployStatus(
                deployId: e.buildId,
                name: "\(e.pipelineName) [\(e.branch)]: \(reason)",
                succeeded: false
            )
        }
    }

    @MainActor
    private func wireAutoPR(eventBus: EventBus, appState: AppState, container: DependencyContainer) async {
        let useCase = CreateDraftPRUseCase(eventBus: eventBus)

        await eventBus.subscribe(to: String(describing: AgentCompletedEvent.self)) { [weak appState, weak container] event in
            guard let appState, let container else { return }
            guard let e = event as? AgentCompletedEvent else { return }

            await MainActor.run {
                guard appState.isAutoPREnabled else { return }

                // Find the completed session
                guard let session = appState.agentViewModel.sessions.first(where: { $0.id == e.sessionId }),
                      session.worktreePath != nil,
                      let branchName = e.branchName, !branchName.isEmpty else { return }

                // Need GitHub adapter and repo name
                guard let ghAdapter = container.getOrCreateGitHubAdapter(),
                      let gitAdapter = container.getOrCreateGitAdapter() else { return }

                Task {
                    // Derive repo name from git remote
                    guard let remoteURL = try? await gitAdapter.remoteURL() else { return }
                    let repo: String
                    if remoteURL.contains("github.com:") {
                        repo = (remoteURL.components(separatedBy: "github.com:").last ?? "").replacingOccurrences(of: ".git", with: "")
                    } else if remoteURL.contains("github.com/") {
                        repo = (remoteURL.components(separatedBy: "github.com/").last ?? "").replacingOccurrences(of: ".git", with: "")
                    } else {
                        return
                    }
                    guard !repo.isEmpty else { return }

                    // Determine target branch
                    let allBranches = (try? await gitAdapter.branches()) ?? []
                    let targetBranch = allBranches.contains(where: { $0.name == "main" }) ? "main" : "master"

                    do {
                        let result = try await useCase.execute(
                            session: session,
                            repo: repo,
                            sourceBranch: branchName,
                            targetBranch: targetBranch,
                            cloudPort: ghAdapter
                        )

                        await MainActor.run {
                            appState.lastAutoPRURL = result.url
                        }

                        // Post a macOS notification
                        MacNotificationService.shared.send(
                            title: "Draft PR Created",
                            body: result.title,
                            category: MacNotificationService.Category.prReviewRequested,
                            userInfo: ["url": result.url]
                        )
                    } catch {
                        // Silently fail — user can always create PR manually
                    }
                }
            }
        }
    }
}
