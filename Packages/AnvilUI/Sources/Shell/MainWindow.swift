import SwiftUI

public struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Mode tab bar
            ModeTabBar()

            Divider()
                .overlay(AnvilColor.borderSubtle)

            // Show welcome page when no project is open
            if container.currentProjectPath == nil {
                WelcomePage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Main content area
                HStack(spacing: 0) {
                    // Sidebar
                    if appState.isSidebarVisible {
                        Sidebar()
                            .frame(width: appState.isSidebarCollapsed ? AnvilSpacing.sidebarCollapsedWidth : AnvilSpacing.sidebarWidth)

                        Divider()
                            .overlay(AnvilColor.borderSubtle)
                    }

                    // Project search panel
                    if appState.isProjectSearchVisible {
                        SearchPanel()

                        Divider()
                            .overlay(AnvilColor.borderSubtle)
                    }

                    // Content
                    ContentArea()

                    // Inspector
                    if appState.isInspectorVisible {
                        Divider()
                            .overlay(AnvilColor.borderSubtle)

                        InspectorPanel()
                            .frame(width: AnvilSpacing.inspectorWidth)
                    }
                }

                // Terminal panel (bottom)
                if appState.isTerminalPanelVisible {
                    TerminalPanel()
                        .frame(height: appState.terminalPanelHeight)
                }
            }

            Divider()
                .overlay(AnvilColor.borderSubtle)

            // Status bar
            StatusBar()
        }
        .background(AnvilColor.backgroundPrimary)
        .overlay {
            if appState.isCommandPaletteVisible {
                CommandPalette()
            }
            if appState.isQuickCaptureVisible {
                QuickCapture()
            }
            if appState.isProjectSwitcherVisible {
                ProjectSwitcher()
            }
            if appState.isCodebaseQAVisible {
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
