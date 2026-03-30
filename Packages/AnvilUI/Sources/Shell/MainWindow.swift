import SwiftUI

public struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Show welcome page when no project is open
            if container.currentProjectPath == nil {
                WelcomePage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Main content area
                HStack(spacing: 0) {
                    // Icon rail — always visible (44pt)
                    IconRail()
                        .frame(width: AnvilSpacing.iconRailWidth)

                    // Content sidebar — toggleable (260pt)
                    if !appState.isSidebarCollapsed {
                        ContentSidebar()
                            .frame(width: AnvilSpacing.sidebarWidth)
                    }

                    // Project search panel
                    if appState.isProjectSearchVisible {
                        SearchPanel()
                    }

                    // Content
                    ContentArea()
                        .inspector(isPresented: $appState.isInspectorVisible) {
                            InspectorPanel()
                                .inspectorColumnWidth(min: 200, ideal: 260, max: 400)
                        }
                }

                // Terminal panel (bottom)
                if appState.isTerminalPanelVisible {
                    TerminalPanel()
                        .frame(height: appState.terminalPanelHeight)
                }
            }

            // Status bar
            StatusBar()
        }
        .background(AnvilColor.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Toggle Sidebar", systemImage: "sidebar.left") {
                    appState.toggleSidebar()
                }
                .help("Toggle Sidebar")
                .accessibilityLabel("Toggle Sidebar")
                .accessibilityAddTraits(.isButton)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button("Command Palette", systemImage: "magnifyingglass") {
                    appState.toggleCommandPalette()
                }
                .help("Command Palette (\u{2318}K)")
                .keyboardShortcut("k", modifiers: .command)
                .accessibilityLabel("Command Palette")
                .accessibilityAddTraits(.isButton)

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                .help("Settings")
            }
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarBackground(.bar, for: .windowToolbar)
        .overlay {
            if appState.isCommandPaletteVisible {
                CommandPalette()
            } else if appState.isQuickCaptureVisible {
                QuickCapture()
            } else if appState.isProjectSwitcherVisible {
                ProjectSwitcher()
            } else if appState.isCodebaseQAVisible {
                CodebaseQAView()
                    .environmentObject(container)
            }
        }
        .sheet(isPresented: $appState.isProjectNotesVisible) {
            ProjectNotes()
                .frame(minWidth: 500, minHeight: 400)
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.isProjectInfoVisible) {
            ProjectInfoPanel()
                .frame(minWidth: 500, minHeight: 450)
                .environmentObject(appState)
        }
        .keyEventRouter()
    }
}
