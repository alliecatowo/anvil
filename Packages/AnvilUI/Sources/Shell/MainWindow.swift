import SwiftUI

public struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer
    @State private var isNotificationsPopoverVisible = false

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
                        .inspector(isPresented: Binding(
                            get: { appState.isAgentPanelVisible || appState.isInspectorVisible },
                            set: { if !$0 {
                                appState.isAgentPanelVisible = false
                                appState.isInspectorVisible = false
                            }}
                        )) {
                            if appState.isAgentPanelVisible {
                                AgentChatPanel()
                                    .inspectorColumnWidth(min: 320, ideal: 360, max: 480)
                            } else {
                                InspectorPanel()
                                    .inspectorColumnWidth(min: 200, ideal: 260, max: 400)
                            }
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

                Button {
                    isNotificationsPopoverVisible.toggle()
                } label: {
                    Image(systemName: "bell")
                        .overlay(alignment: .topTrailing) {
                            let count = appState.notificationsViewModel.unreadCount
                            if count > 0 {
                                Text(count < 10 ? "\(count)" : "9+")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.red, in: Capsule())
                                    .offset(x: 6, y: -6)
                            }
                        }
                }
                .help("Notifications")
                .accessibilityLabel("Notifications")
                .accessibilityIdentifier("toolbar.notifications")
                .popover(isPresented: $isNotificationsPopoverVisible, arrowEdge: .top) {
                    NotificationsMode()
                        .frame(width: 400, height: 520)
                        .environmentObject(appState)
                        .environmentObject(container)
                }

                Button("Agent Sidebar", systemImage: "sidebar.right") {
                    appState.toggleAgentPanel()
                }
                .help("Toggle Agent Sidebar")
                .accessibilityLabel("Toggle Agent Sidebar")
                .accessibilityIdentifier("toolbar.toggle-agent-sidebar")
                .accessibilityAddTraits(.isButton)

                Button("Inspector", systemImage: "info.circle") {
                    appState.toggleInspector()
                }
                .help("Toggle Inspector")
                .accessibilityLabel("Toggle Inspector")
                .accessibilityIdentifier("toolbar.toggle-inspector")
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
