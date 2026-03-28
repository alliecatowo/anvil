import SwiftUI
import AnvilTerminal

public struct Sidebar: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if appState.isSidebarCollapsed {
                CollapsedSidebar()
            } else {
                // Delegate to mode-specific sidebar
                switch appState.currentMode {
                case .agent:
                    AgentSidebar(viewModel: appState.agentViewModel)
                case .intent:
                    IntentSidebar(viewModel: appState.intentViewModel)
                case .review:
                    ReviewSidebar(viewModel: appState.reviewViewModel)
                case .ship:
                    ShipSidebar(viewModel: appState.shipViewModel)
                case .editor, .database, .terminal, .docs, .messaging, .notifications, .testing, .extensions:
                    AuxiliarySidebar(mode: appState.currentMode)
                }
            }
        }
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(width: 1)
        }
    }
}

struct CollapsedSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            railButton(
                icon: "sidebar.leading",
                title: "Expand Navigation",
                isActive: false,
                action: { appState.isSidebarCollapsed = false }
            )

            railDivider
            railSection(modes: AnvilMode.coreModes)
            railDivider
            railSection(modes: AnvilMode.workspaceModes)
            railDivider
            railSection(modes: AnvilMode.contextModes)

            Spacer()

            railDivider
            railButton(
                icon: "magnifyingglass",
                title: "Find in Project",
                isActive: appState.isProjectSearchVisible,
                action: { appState.toggleProjectSearch() }
            )
            railButton(
                icon: "sidebar.right",
                title: "Toggle Inspector",
                isActive: appState.isInspectorVisible,
                action: { appState.toggleInspector() }
            )
        }
        .padding(.vertical, AnvilSpacing.sm)
    }

    private var railDivider: some View {
        Rectangle()
            .fill(AnvilColor.borderSubtle)
            .frame(height: 1)
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)
    }

    private func railSection(modes: [AnvilMode]) -> some View {
        VStack(spacing: 4) {
            ForEach(modes) { mode in
                railButton(
                    icon: mode.icon,
                    title: mode.rawValue,
                    isActive: appState.currentMode == mode,
                    action: { appState.switchMode(mode) }
                )
            }
        }
    }

    private func railButton(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .frame(width: 36, height: 32)
                .background(isActive ? Color.accentColor.opacity(0.14) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

struct AuxiliarySidebar: View {
    let mode: AnvilMode
    @EnvironmentObject var appState: AppState
    @State private var collapsedSections: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Mode header
            HStack {
                Image(systemName: mode.icon)
                    .font(.system(size: 14))
                Text(mode.rawValue)
                    .font(AnvilFont.sidebarHeader)
            }
            .foregroundStyle(AnvilColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .background(AnvilColor.backgroundSidebar.opacity(0.55))

            // Mode-specific navigation items
            ScrollView {
                LazyVStack(spacing: 0) {
                    switch mode {
                    case .editor:
                        editorItems
                    case .database:
                        databaseItems
                    case .terminal:
                        terminalItems
                    case .docs:
                        docsItems
                    case .messaging:
                        messagingItems
                    case .notifications:
                        notificationsItems
                    case .testing:
                        testingItems
                    case .extensions:
                        extensionsItems
                    default:
                        EmptyView()
                    }
                }
            }
            .scrollIndicators(.hidden)

            Spacer()
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorItems: some View {
        sidebarSection("WORKSPACE", icon: "folder") {
            navItem("Open Files", icon: "doc.text", shortcut: "\u{2318}P") { appState.openFilePalette() }
            navItem("File Tree", icon: "list.triangle", shortcut: "\u{2318}\u{21E7}E", isActive: appState.currentMode == .editor) {
                // Switch to editor mode so the file tree sidebar is visible
                appState.switchMode(.editor)
                appState.isSidebarVisible = true
                appState.isSidebarCollapsed = false
            }
            navItem("Symbol Outline", icon: "list.bullet.indent", shortcut: "\u{2318}\u{21E7}O") {
                appState.commandPaletteInitialMode = .symbols
                appState.toggleCommandPalette()
            }
        }
        sidebarSection("SOURCE CONTROL", icon: "arrow.triangle.branch") {
            navItem("Changes", icon: "pencil.circle", shortcut: nil, isActive: appState.isSourceControlVisible) {
                appState.toggleSourceControl()
            }
            navItem("Branches", icon: "arrow.triangle.branch", shortcut: nil, isActive: appState.isSourceControlVisible) {
                appState.isSourceControlVisible = true
            }
            navItem("Stashes", icon: "tray.and.arrow.down", shortcut: nil, isActive: appState.isSourceControlVisible) {
                appState.isSourceControlVisible = true
            }
        }
        sidebarSection("SEARCH", icon: "magnifyingglass") {
            navItem("Find in Files", icon: "doc.text.magnifyingglass", shortcut: "\u{2318}\u{21E7}F", isActive: appState.isProjectSearchVisible) {
                appState.toggleProjectSearch()
            }
            navItem("Find in Current File", icon: "arrow.left.arrow.right", shortcut: "\u{2318}F") { appState.triggerFindInFile = true }
        }
    }

    // MARK: - Database

    @ViewBuilder
    private var databaseItems: some View {
        sidebarSection("WORKSPACE", icon: "cylinder") {
            infoItem("SQLite Workspace", icon: "internaldrive", detail: "Current provider surface")
            infoItem("Schema Browser", icon: "tablecells", detail: "Tables, indexes, and views")
            infoItem("Query Runner", icon: "terminal", detail: "Ad hoc queries and results")
        }
        sidebarSection("WORKSPACE ACTIONS", icon: "bolt") {
            navItem("Find in Project", icon: "doc.text.magnifyingglass", shortcut: "\u{2318}\u{21E7}F", isActive: appState.isProjectSearchVisible) {
                appState.toggleProjectSearch()
            }
            navItem("Ask Codebase", icon: "questionmark.bubble", shortcut: "\u{2318}/", isActive: appState.isCodebaseQAVisible) {
                appState.toggleCodebaseQA()
            }
            navItem("Inspector", icon: "sidebar.right", shortcut: "\u{2318}\u{21E7}I", isActive: appState.isInspectorVisible) {
                appState.toggleInspector()
            }
        }
    }

    // MARK: - Terminal

    @ViewBuilder
    private var terminalItems: some View {
        sidebarSection("SESSIONS", icon: "terminal") {
            TerminalSessionList(viewModel: appState.terminalViewModel) { id in
                appState.switchMode(.terminal)
                appState.terminalViewModel.selectTab(id)
            }
        }
        sidebarSection("ACTIONS", icon: "bolt") {
            navItem("New Terminal", icon: "plus", shortcut: "\u{2318}\u{21E7}T") {
                appState.switchMode(.terminal)
                _ = appState.terminalViewModel.addTab()
            }
            navItem("Split Right", icon: "rectangle.split.2x1", shortcut: "\u{2318}\\") {
                appState.switchMode(.terminal)
                appState.triggerSplitVertical = true
            }
            navItem("Split Down", icon: "rectangle.split.1x2", shortcut: "\u{2318}\u{21E7}\\") {
                appState.switchMode(.terminal)
                appState.triggerSplitHorizontal = true
            }
            navItem("Clear Buffer", icon: "xmark.circle", shortcut: nil) {
                appState.switchMode(.terminal)
                appState.terminalViewModel.clearBuffer()
            }
        }
    }

    // MARK: - Docs

    @ViewBuilder
    private var docsItems: some View {
        sidebarSection("KNOWLEDGE", icon: "book") {
            infoItem("Project Notes", icon: "note.text", detail: "Long-form working memory")
            infoItem("Markdown Workspace", icon: "doc.richtext", detail: "Docs mode editor surface")
            infoItem("Reference Library", icon: "books.vertical", detail: "Project docs and manuals")
        }
        sidebarSection("WORKSPACE ACTIONS", icon: "bolt") {
            navItem("Project Notes", icon: "note.text.badge.plus", shortcut: "\u{2318}\u{21E7}N", isActive: appState.isProjectNotesVisible) {
                appState.toggleProjectNotes()
            }
            navItem("Ask Codebase", icon: "questionmark.bubble", shortcut: "\u{2318}/", isActive: appState.isCodebaseQAVisible) {
                appState.toggleCodebaseQA()
            }
            navItem("Find in Project", icon: "doc.text.magnifyingglass", shortcut: "\u{2318}\u{21E7}F", isActive: appState.isProjectSearchVisible) {
                appState.toggleProjectSearch()
            }
        }
    }

    // MARK: - Messaging

    @ViewBuilder
    private var messagingItems: some View {
        sidebarSection("COMMUNICATION", icon: "message") {
            infoItem("Channels", icon: "number", detail: "Team streams and shared context")
            infoItem("Direct Messages", icon: "person.2", detail: "Focused 1:1 conversations")
            infoItem("Threads", icon: "bubble.left.and.bubble.right", detail: "Decision trails and follow-up")
        }
        sidebarSection("WORKSPACE ACTIONS", icon: "bolt") {
            navItem("Quick Capture", icon: "square.and.pencil", shortcut: "\u{2318}\u{21E7}Space", isActive: appState.isQuickCaptureVisible) {
                appState.toggleQuickCapture()
            }
            navItem("Switch Project", icon: "rectangle.2.swap", shortcut: "\u{2318}\u{21E7}O", isActive: appState.isProjectSwitcherVisible) {
                appState.toggleProjectSwitcher()
            }
            navItem("Command Palette", icon: "command", shortcut: "\u{2318}K", isActive: appState.isCommandPaletteVisible) {
                appState.toggleCommandPalette()
            }
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationsItems: some View {
        sidebarSection("TRIAGE", icon: "bell") {
            navItem(
                appState.notificationsViewModel.unreadCount > 0
                    ? "Inbox (\(appState.notificationsViewModel.unreadCount))"
                    : "Inbox",
                icon: "tray",
                shortcut: nil,
                isActive: appState.notificationsViewModel.selectedTab == .inbox
            ) {
                appState.notificationsViewModel.selectedTab = .inbox
            }
            navItem("Activity Feed", icon: "list.bullet", shortcut: nil, isActive: appState.notificationsViewModel.selectedTab == .activity) {
                appState.notificationsViewModel.selectedTab = .activity
            }
            navItem("Preferences", icon: "gearshape", shortcut: nil, isActive: appState.notificationsViewModel.selectedTab == .preferences) {
                appState.notificationsViewModel.selectedTab = .preferences
            }
        }
        sidebarSection("WORKSPACE ACTIONS", icon: "bolt") {
            navItem("Project Info", icon: "info.circle", shortcut: nil, isActive: appState.isProjectInfoVisible) {
                appState.toggleProjectInfo()
            }
            navItem("Inspector", icon: "sidebar.right", shortcut: "\u{2318}\u{21E7}I", isActive: appState.isInspectorVisible) {
                appState.toggleInspector()
            }
            navItem("Command Palette", icon: "command", shortcut: "\u{2318}K", isActive: appState.isCommandPaletteVisible) {
                appState.toggleCommandPalette()
            }
        }
    }

    // MARK: - Testing

    @ViewBuilder
    private var testingItems: some View {
        sidebarSection("RUNSPACE", icon: "testtube.2") {
            infoItem("Suite Browser", icon: "list.bullet.rectangle", detail: "Organize by target and status")
            infoItem("Failed Runs", icon: "xmark.circle", detail: "Fast focus on breakage")
            infoItem("Coverage", icon: "chart.bar", detail: "Execution and confidence signals")
        }
        sidebarSection("WORKSPACE ACTIONS", icon: "bolt") {
            navItem("New Terminal Session", icon: "plus.rectangle.on.rectangle", shortcut: "\u{2318}\u{21E7}T") {
                appState.switchMode(.terminal)
                _ = appState.terminalViewModel.addTab()
            }
            navItem("Toggle Terminal Panel", icon: "terminal", shortcut: "\u{2318}J", isActive: appState.isTerminalPanelVisible) {
                appState.toggleTerminal()
            }
            navItem("Find in Project", icon: "doc.text.magnifyingglass", shortcut: "\u{2318}\u{21E7}F", isActive: appState.isProjectSearchVisible) {
                appState.toggleProjectSearch()
            }
        }
    }

    // MARK: - Extensions

    @ViewBuilder
    private var extensionsItems: some View {
        sidebarSection("EXTENSION SURFACE", icon: "puzzlepiece.extension") {
            infoItem("Marketplace", icon: "square.grid.2x2", detail: "Discover installable tools")
            infoItem("Installed Set", icon: "checkmark.circle", detail: "Enabled and disabled packages")
            infoItem("Capability Layers", icon: "square.3.layers.3d", detail: "Language, AI, UI, and workflow")
        }
        sidebarSection("WORKSPACE ACTIONS", icon: "bolt") {
            navItem("Command Palette", icon: "command", shortcut: "\u{2318}K", isActive: appState.isCommandPaletteVisible) {
                appState.toggleCommandPalette()
            }
            navItem("Project Info", icon: "info.circle", shortcut: nil, isActive: appState.isProjectInfoVisible) {
                appState.toggleProjectInfo()
            }
            navItem("Switch Project", icon: "rectangle.2.swap", shortcut: "\u{2318}\u{21E7}O", isActive: appState.isProjectSwitcherVisible) {
                appState.toggleProjectSwitcher()
            }
        }
    }

    // MARK: - Shared Components

    private func sidebarSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if collapsedSections.contains(title) {
                        collapsedSections.remove(title)
                    } else {
                        collapsedSections.insert(title)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: collapsedSections.contains(title) ? "chevron.right" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .frame(width: 10)
                    AnvilSidebarSectionHeader(title: title, icon: icon)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .background(Color.primary.opacity(0.03))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !collapsedSections.contains(title) {
                content()
            }
        }
    }

    private func navItem(_ title: String, icon: String, shortcut: String?, isActive: Bool = false, action: @escaping () -> Void = {}) -> some View {
        AnvilSidebarRowButton(
            title: title,
            icon: icon,
            isActive: isActive,
            shortcut: shortcut,
            action: action
        )
    }

    private func infoItem(_ title: String, icon: String, detail: String) -> some View {
        AnvilSidebarInfoRow(title: title, icon: icon, detail: detail)
    }
}

private struct TerminalSessionList: View {
    @ObservedObject var viewModel: TerminalViewModel
    let onSelect: (UUID) -> Void

    var body: some View {
        ForEach(viewModel.sessions) { session in
            AnvilSidebarRowButton(
                title: session.title,
                icon: session.isRunning ? "terminal" : "terminal.fill",
                subtitle: session.isRunning ? "running" : "exited",
                isActive: isSelected(session),
                action: {
                    onSelect(session.id)
                }
            )
        }
    }

    private func isSelected(_ session: TerminalSession) -> Bool {
        viewModel.selectedSessionId == session.id
    }
}
