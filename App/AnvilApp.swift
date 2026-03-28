import AppKit
import SwiftUI
import AnvilUI
import AnvilInfrastructure

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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

                    // Wire ticket management port and use case into view model
                    appState.intentViewModel.configure(
                        ticketPort: container.ticketService,
                        createUseCase: container.makeCreateTicketUseCase()
                    )

                    // Wire SQLite database adapter
                    let sqliteAdapter = SQLiteDatabaseAdapter()
                    container.databaseService.setAdapter(sqliteAdapter)
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
}
