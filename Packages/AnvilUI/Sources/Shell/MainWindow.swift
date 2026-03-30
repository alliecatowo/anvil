import SwiftUI

public struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer
    @State private var isNotificationsPopoverVisible = false
    @State private var isBranchPickerVisible = false

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
                    // Unified sidebar panel (rail + content, one glass surface)
                    SidebarPanel()

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

                // Utility Deck (bottom panel — available in all spaces)
                if appState.isTerminalPanelVisible {
                    UtilityDeck()
                        .frame(height: appState.terminalPanelHeight)
                }
            }

            // Status bar — Build-only (editor context)
            if appState.currentSpace == .build {
                StatusBar()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            // Left: sidebar toggle
            ToolbarItem(placement: .navigation) {
                Button("Toggle Sidebar", systemImage: "sidebar.left") {
                    appState.toggleSidebar()
                }
                .help("Toggle Sidebar")
                .accessibilityLabel("Toggle Sidebar")
                .accessibilityAddTraits(.isButton)
            }

            // Left: project switcher (always visible, clear dropdown)
            ToolbarItem(placement: .navigation) {
                Menu {
                    Button {
                        appState.toggleProjectSwitcher()
                    } label: {
                        Label("Switch Project...", systemImage: "folder")
                    }
                    Divider()
                    Button {
                        appState.toggleCommandPalette()
                    } label: {
                        Label("Command Palette", systemImage: "magnifyingglass")
                    }
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                        Text(appState.currentProject?.name ?? "Anvil")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .help("Project: \(appState.currentProject?.name ?? "Anvil")")
                .accessibilityLabel("Project: \(appState.currentProject?.name ?? "Anvil")")
            }

            // Left: branch pill (Build-only)
            ToolbarItem(placement: .navigation) {
                if appState.currentSpace == .build {
                    Button {
                        isBranchPickerVisible.toggle()
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 11, weight: .medium))
                            Text(appState.currentBranch)
                                .font(.system(size: 11))
                                .lineLimit(1)

                            if appState.uncommittedFileCount > 0 {
                                Text("\(appState.uncommittedFileCount)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Switch Branch")
                    .accessibilityLabel("Branch: \(appState.currentBranch)")
                    .popover(isPresented: $isBranchPickerVisible, arrowEdge: .bottom) {
                        BranchPicker(isPresented: $isBranchPickerVisible)
                    }
                }
            }

            // Center: space name
            ToolbarItem(placement: .principal) {
                ToolbarSourcePicker()
            }

            // Right: actions
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
                    let unreadCount = appState.notificationsViewModel.unreadCount
                    Image(systemName: unreadCount > 0 ? "bell.badge" : "bell")
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

                Button("Inspector", systemImage: "info.circle") {
                    appState.toggleInspector()
                }
                .help("Toggle Inspector")
                .accessibilityLabel("Toggle Inspector")
                .accessibilityIdentifier("toolbar.toggle-inspector")
                .accessibilityAddTraits(.isButton)

                Button("Agent Sidebar", systemImage: "sparkles") {
                    appState.toggleAgentPanel()
                }
                .help("Toggle Agent Sidebar")
                .accessibilityLabel("Toggle Agent Sidebar")
                .accessibilityIdentifier("toolbar.toggle-agent-sidebar")
                .accessibilityAddTraits(.isButton)
            }
        }
        .navigationTitle("")
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
