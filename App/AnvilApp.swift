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
    @State private var showSetupWizard = SetupWizardViewModel.isFirstLaunch

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(container)
                .task {
                    // Restore last-opened project from disk
                    if let project = await container.projectManager.currentProject() {
                        appState.currentProject = project
                        appState.currentProjectPath = project.primaryRepoPath
                        container.currentProjectPath = project.primaryRepoPath
                    }
                    if let adapter = container.getOrCreateGitAdapter() {
                        await appState.loadGitStatus(from: adapter)
                    }

                    // Wire persistent ticket storage (SQLite)
                    let ticketRepo = SQLiteTicketRepository()
                    try? await ticketRepo.open()
                    container.setTicketService(ticketRepo)

                    // Wire ticket management port and use case into view model
                    appState.intentViewModel.configure(
                        ticketPort: container.ticketService,
                        createUseCase: container.makeCreateTicketUseCase()
                    )

                    // Wire SQLite database adapter
                    let sqliteAdapter = SQLiteDatabaseAdapter()
                    container.databaseService.setAdapter(sqliteAdapter)

                    // Wire external ticket provider based on available credentials
                    wireTicketProvider(container: container)

                    // Wire Slack messaging adapter if bot token is available
                    wireMessagingProvider(container: container)

                    // Request macOS notification authorization and subscribe to domain events
                    await MacNotificationService.shared.requestAuthorization()
                    await wireNotificationEvents(eventBus: container.eventBus)
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

    /// Detect a stored Slack bot token and wire the SlackMessagingAdapter.
    /// Reads from the same Keychain service as ProviderKeychain in AnvilUI.
    @MainActor
    private func wireMessagingProvider(container: DependencyContainer) {
        let keychain = KeychainStore(service: "com.anvil.providers")

        guard let botToken = try? keychain.get("slack.botToken"), !botToken.isEmpty else {
            return
        }

        let adapter = SlackMessagingAdapter(botToken: botToken)
        container.setMessagingAdapter(adapter)
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
}
