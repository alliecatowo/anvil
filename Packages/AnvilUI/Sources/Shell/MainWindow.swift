import SwiftUI

public struct MainWindow: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Mode tab bar
            ModeTabBar()

            Divider()
                .overlay(AnvilColor.borderSubtle)

            // Main content area
            HStack(spacing: 0) {
                // Sidebar
                if appState.isSidebarVisible {
                    Sidebar()
                        .frame(width: appState.isSidebarCollapsed ? AnvilSpacing.sidebarCollapsedWidth : AnvilSpacing.sidebarWidth)

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
                Divider()
                    .overlay(AnvilColor.borderSubtle)

                TerminalPanel()
                    .frame(height: 200)
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
        }
        .sheet(isPresented: $appState.isProjectNotesVisible) {
            ProjectNotes()
                .frame(minWidth: 500, minHeight: 400)
                .environmentObject(appState)
        }
        .keyEventRouter()
    }
}
