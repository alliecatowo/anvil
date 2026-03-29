import SwiftUI
import UserNotifications
import AnvilApplication

public struct AnvilApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer()
    @State private var showSetupWizard = Self.shouldShowSetupWizard

    private static let shouldShowSetupWizard: Bool = {
        if ProcessInfo.processInfo.environment["ANVIL_SKIP_SETUP_WIZARD"] == "1" {
            return false
        }
        return SetupWizardViewModel.isFirstLaunch
    }()

    private static var isRunningUITests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["ANVIL_UITEST_SCENARIO"] != nil
    }

    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(container)
                .task {
                    // UI tests need deterministic launch and should not be blocked by
                    // notification permission prompts or other system dialogs.
                    if !Self.isRunningUITests {
                        let notificationService = DesktopNotificationService.shared
                        UNUserNotificationCenter.current().delegate = notificationService
                        _ = await notificationService.requestPermission()
                    }

                    // Wire review management port, use case, and event bus into view model
                    appState.reviewViewModel.configure(
                        reviewPort: container.reviewService,
                        createUseCase: container.makeCreateReviewUseCase(),
                        eventBus: container.eventBus
                    )

                    // Wire ticket management port, use case, and event bus into view model
                    appState.intentViewModel.configure(
                        ticketPort: container.ticketService,
                        createUseCase: container.makeCreateTicketUseCase()
                    )
                    appState.intentViewModel.configure(eventBus: container.eventBus)

                    // Wire deployment use case, event bus, and hosting port into ship view model
                    appState.shipViewModel.configure(
                        deploymentUseCase: container.makeCreateDeploymentUseCase()
                    )
                    appState.shipViewModel.configure(eventBus: container.eventBus)
                    appState.editorViewModel.configure(eventBus: container.eventBus)
                    if let hostingPort = container.hostingPort {
                        appState.shipViewModel.configure(hostingPort: hostingPort)
                    }
                    appState.shipViewModel.loadFromProvider()

                    // Wire messaging port into messaging view model
                    appState.messagingViewModel.configure(
                        messagingPort: container.messagingPort ?? container.messagingService
                    )

                    // Wire schedule port into schedule view model
                    appState.scheduleViewModel.configure(
                        schedulePort: container.scheduleService
                    )

                    // Wire notification port into notifications view model
                    appState.notificationsViewModel.configure(
                        notificationPort: container.notificationService
                    )

                    // Wire observability service into observability view model
                    appState.observabilityViewModel.configure(
                        service: container.observabilityService
                    )

                    // Wire database service into database view model
                    appState.databaseViewModel.configure(
                        service: container.databaseService
                    )

                    if let adapter = container.getOrCreateGitAdapter() {
                        await appState.loadGitStatus(from: adapter)
                    }

                    // Keep app-level project scoped features (Rules/Docs/Search/Tests) in sync.
                    appState.currentProjectPath = container.currentProjectPath
                    appState.applyUITestScenarioIfNeeded()
                }
                .onChange(of: container.currentProjectPath) { _, newPath in
                    appState.currentProjectPath = newPath
                }
                .onReceive(NotificationCenter.default.publisher(for: .anvilDesktopNotificationTapped)) { notification in
                    handleDesktopNotificationTap(notification)
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

    // MARK: - Desktop Notification Navigation

    private func handleDesktopNotificationTap(_ notification: Foundation.Notification) {
        guard let userInfo = notification.userInfo else { return }

        let targetModeRaw = userInfo["targetMode"] as? String ?? "Notifications"
        let targetItemId = userInfo["targetItemId"] as? String
        let action = userInfo["action"] as? String

        // Mark as read if that action was chosen
        if action == "MARK_READ", let notifId = userInfo["notificationId"] as? String {
            // Fire-and-forget mark read via NotificationCenter
            NotificationCenter.default.post(
                name: .anvilMarkNotificationRead,
                object: nil,
                userInfo: ["notificationId": notifId]
            )
            return
        }

        // Navigate to the target mode
        if let space = AnvilSpace.allCases.first(where: { $0.rawValue == targetModeRaw }) {
            appState.switchSpace(space)
        }

        // If there's a specific item to select, post it
        if let itemId = targetItemId, !itemId.isEmpty {
            NotificationCenter.default.post(
                name: .anvilNavigateToItem,
                object: nil,
                userInfo: ["itemId": itemId]
            )
        }

        // Bring app to front
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

// MARK: - Navigation Notification Names

public extension Foundation.Notification.Name {
    /// Posted to navigate to a specific item after a desktop notification tap.
    static let anvilNavigateToItem = Foundation.Notification.Name("anvilNavigateToItem")
    /// Posted to mark a notification as read from a desktop notification action.
    static let anvilMarkNotificationRead = Foundation.Notification.Name("anvilMarkNotificationRead")
}
