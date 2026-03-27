import SwiftUI

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
                case .editor, .database, .terminal, .docs, .messaging, .notifications, .testing:
                    AuxiliarySidebar(mode: appState.currentMode)
                }
            }
        }
        .background(AnvilColor.backgroundSecondary)
    }
}

struct CollapsedSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: AnvilSpacing.sm) {
            // Show mode icon as expand button
            Button {
                appState.isSidebarCollapsed = false
            } label: {
                Image(systemName: appState.currentMode.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AnvilColor.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help(appState.currentMode.rawValue)

            Spacer()
        }
        .padding(.top, AnvilSpacing.sm)
    }
}

struct AuxiliarySidebar: View {
    let mode: AnvilMode

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

            Divider().overlay(AnvilColor.borderSubtle)

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
                    default:
                        EmptyView()
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorItems: some View {
        sidebarSection("EXPLORER", icon: "folder") {
            navItem("Open Files", icon: "doc.text", shortcut: "Cmd+O")
            navItem("File Tree", icon: "list.triangle", shortcut: "Cmd+Shift+E")
            navItem("Symbol Outline", icon: "list.bullet.indent", shortcut: "Cmd+Shift+O")
        }
        sidebarSection("SOURCE CONTROL", icon: "arrow.triangle.branch") {
            navItem("Changes", icon: "pencil.circle", shortcut: "Ctrl+Shift+G")
            navItem("Branches", icon: "arrow.triangle.branch", shortcut: nil)
            navItem("Stashes", icon: "tray.and.arrow.down", shortcut: nil)
        }
        sidebarSection("SEARCH", icon: "magnifyingglass") {
            navItem("Find in Files", icon: "doc.text.magnifyingglass", shortcut: "Cmd+Shift+F")
            navItem("Find & Replace", icon: "arrow.left.arrow.right", shortcut: "Cmd+H")
        }
    }

    // MARK: - Database

    @ViewBuilder
    private var databaseItems: some View {
        sidebarSection("SCHEMA", icon: "cylinder") {
            navItem("Tables", icon: "tablecells", shortcut: nil)
            navItem("Views", icon: "eye", shortcut: nil)
            navItem("Functions", icon: "function", shortcut: nil)
            navItem("Indexes", icon: "list.number", shortcut: nil)
        }
        sidebarSection("TOOLS", icon: "wrench.and.screwdriver") {
            navItem("Query Console", icon: "terminal", shortcut: "Cmd+Enter")
            navItem("Query History", icon: "clock.arrow.circlepath", shortcut: nil)
            navItem("Export Data", icon: "arrow.down.doc", shortcut: nil)
        }
    }

    // MARK: - Terminal

    @ViewBuilder
    private var terminalItems: some View {
        sidebarSection("SESSIONS", icon: "terminal") {
            navItem("zsh", icon: "terminal.fill", shortcut: nil)
            navItem("node", icon: "chevron.left.forwardslash.chevron.right", shortcut: nil)
            navItem("docker", icon: "shippingbox", shortcut: nil)
        }
        sidebarSection("ACTIONS", icon: "bolt") {
            navItem("New Terminal", icon: "plus", shortcut: "Cmd+Shift+T")
            navItem("Split Pane", icon: "rectangle.split.1x2", shortcut: "Cmd+D")
            navItem("Clear Buffer", icon: "xmark.circle", shortcut: "Cmd+K")
        }
    }

    // MARK: - Docs

    @ViewBuilder
    private var docsItems: some View {
        sidebarSection("DOCUMENTS", icon: "book") {
            navItem("Guide", icon: "folder", shortcut: nil)
            navItem("Reference", icon: "folder", shortcut: nil)
            navItem("Changelog.md", icon: "doc.richtext", shortcut: nil)
        }
        sidebarSection("ACTIONS", icon: "bolt") {
            navItem("New Document", icon: "plus", shortcut: "Cmd+N")
            navItem("Search Docs", icon: "magnifyingglass", shortcut: "Cmd+Shift+F")
        }
    }

    // MARK: - Messaging

    @ViewBuilder
    private var messagingItems: some View {
        sidebarSection("CHANNELS", icon: "number") {
            navItem("general", icon: "number", shortcut: nil)
            navItem("engineering", icon: "number", shortcut: nil)
            navItem("design-system", icon: "number", shortcut: nil)
            navItem("ship-it", icon: "number", shortcut: nil)
            navItem("random", icon: "number", shortcut: nil)
        }
        sidebarSection("DIRECT MESSAGES", icon: "person.2") {
            navItem("Sarah Kim", icon: "person.fill", shortcut: nil)
            navItem("Alex Rivera", icon: "person.fill", shortcut: nil)
            navItem("Jordan Lee", icon: "person.fill", shortcut: nil)
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationsItems: some View {
        sidebarSection("VIEWS", icon: "bell") {
            navItem("Inbox", icon: "tray", shortcut: nil)
            navItem("Activity Feed", icon: "list.bullet", shortcut: nil)
        }
        sidebarSection("FILTERS", icon: "line.3.horizontal.decrease.circle") {
            navItem("Unread", icon: "circle.badge.fill", shortcut: nil)
            navItem("Pull Requests", icon: "arrow.triangle.pull", shortcut: nil)
            navItem("Deploys", icon: "shippingbox", shortcut: nil)
            navItem("Errors", icon: "exclamationmark.triangle", shortcut: nil)
            navItem("Mentions", icon: "at", shortcut: nil)
        }
    }

    // MARK: - Testing

    @ViewBuilder
    private var testingItems: some View {
        sidebarSection("TEST SUITES", icon: "testtube.2") {
            navItem("All Tests", icon: "list.bullet", shortcut: nil)
            navItem("Failed", icon: "xmark.circle", shortcut: nil)
            navItem("Recent Runs", icon: "clock.arrow.circlepath", shortcut: nil)
        }
        sidebarSection("ACTIONS", icon: "bolt") {
            navItem("Run All", icon: "play.fill", shortcut: "Cmd+U")
            navItem("Run Failed", icon: "arrow.counterclockwise", shortcut: nil)
            navItem("Coverage Report", icon: "chart.bar", shortcut: nil)
        }
    }

    // MARK: - Shared Components

    private func sidebarSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
                Text(title)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .tracking(0.3)
                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)

            content()
        }
    }

    private func navItem(_ title: String, icon: String, shortcut: String?) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 16)

            Text(title)
                .font(AnvilFont.sidebarItem)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Spacer()

            if let shortcut {
                Text(shortcut)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: AnvilSpacing.listItemHeight)
        .contentShape(Rectangle())
    }
}
