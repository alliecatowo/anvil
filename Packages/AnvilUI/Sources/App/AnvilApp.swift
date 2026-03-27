import SwiftUI

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
                .preferredColorScheme(.dark)
                .task {
                    if let adapter = container.getOrCreateGitAdapter() {
                        await appState.loadGitStatus(from: adapter)
                    }
                }
                .sheet(isPresented: $showSetupWizard) {
                    SetupWizard {
                        showSetupWizard = false
                    }
                    .environmentObject(container)
                    .environmentObject(appState)
                    .frame(minWidth: 800, minHeight: 600)
                    .preferredColorScheme(.dark)
                    .interactiveDismissDisabled()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
        .commands {
            AnvilCommands(appState: appState)
        }

        Settings {
            SettingsWindow()
                .environmentObject(appState)
                .environmentObject(container)
        }
    }
}
