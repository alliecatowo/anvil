import SwiftUI
import UserNotifications
import AnvilApplication

public struct AnvilApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer()
    @State private var showSetupWizard = SetupWizardViewModel.isFirstLaunch

    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(container)
                .task {
                    // Set up desktop notifications
                    let notificationService = DesktopNotificationService.shared
                    UNUserNotificationCenter.current().delegate = notificationService
                    _ = await notificationService.requestPermission()

                    // Wire review management port into view model
                    appState.reviewViewModel.configure(reviewPort: container.reviewService)

                    if let adapter = container.getOrCreateGitAdapter() {
                        await appState.loadGitStatus(from: adapter)
                    }
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
