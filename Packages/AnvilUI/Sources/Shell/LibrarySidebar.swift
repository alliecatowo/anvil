import SwiftUI
import AnvilApplication

struct LibrarySidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            SidebarTabBar(
                sections: Array(AppState.LibrarySection.allCases),
                active: appState.libraryActiveSection,
                icon: { $0.icon },
                label: { $0.rawValue },
                onSelect: { appState.libraryActiveSection = $0 }
            )

            Divider()

            switch appState.libraryActiveSection {
            case .docs:
                DocBrowser(viewModel: appState.libraryDocsViewModel)
            case .rules:
                rulesSidebar
            case .extensions:
                ExtensionsSidebarView(viewModel: appState.pluginMarketplaceViewModel)
            case .notifications:
                notificationsList
            case .messages:
                ChannelList(viewModel: appState.messagingViewModel)
            case .schedule:
                scheduleSidebarList
            }
        }
    }

    // MARK: - Compact Notifications List

    @State private var selectedNotificationID: String?

    private var notificationsList: some View {
        let viewModel = appState.notificationsViewModel
        return Group {
            if viewModel.inboxItems.isEmpty {
                AnvilSidebarEmptyState(
                    icon: "bell.slash",
                    title: "No notifications",
                    message: "Notifications will appear here when received."
                )
            } else {
                List(selection: $selectedNotificationID) {
                    ForEach(viewModel.inboxItems) { item in
                        notificationRow(item, viewModel: viewModel)
                            .tag(item.id)
                            .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedNotificationID) { _, newId in
                    guard let id = newId else { return }
                    viewModel.selectedItemID = id
                    viewModel.markAsRead(id)
                }
                .onChange(of: viewModel.selectedItemID) { _, newId in
                    selectedNotificationID = newId
                }
                .onAppear {
                    selectedNotificationID = viewModel.selectedItemID
                }
            }
        }
    }

    private func notificationRow(_ item: InboxItem, viewModel: NotificationsViewModel) -> some View {
        AnvilListItem(
            icon: item.source.icon,
            title: item.notification.title,
            subtitle: item.notification.body,
            tag: item.notification.isRead ? nil : "Unread",
            tagColor: AnvilColor.accentBlue,
            isSelected: selectedNotificationID == item.id,
            isCompact: false
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.notification.isRead ? "" : "Unread, ")\(item.notification.title), \(item.notification.body)")
    }

    // MARK: - Rules Sidebar

    private var rulesSidebar: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text("Project Rules")
                .font(AnvilFont.subheading)
                .foregroundStyle(AnvilColor.textPrimary)

            if let projectPath = appState.currentProjectPath {
                let rulesPath = ProjectRulesService().rulesPath(projectPath: projectPath)
                Text(rulesPath)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                Button {
                    appState.switchSpace(.build)
                    appState.buildActiveSection = .files
                    appState.pendingFileToOpen = rulesPath
                } label: {
                    Label("Open in Editor", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Open a project to edit and apply rules.")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
            }

            Spacer()
        }
        .padding(AnvilSpacing.md)
    }
    // MARK: - Compact Schedule List

    @State private var selectedScheduleEntryID: String?

    private var scheduleSidebarList: some View {
        let viewModel = appState.scheduleViewModel
        return Group {
            if viewModel.entries.isEmpty {
                AnvilSidebarEmptyState(
                    icon: "calendar",
                    title: "No events today",
                    message: "Scheduled events will appear here.",
                    actions: [
                        EmptyStateAction("Load Demo Data", icon: "tray.and.arrow.down") {
                            viewModel.loadSampleData()
                        }
                    ]
                )
            } else {
                List(selection: $selectedScheduleEntryID) {
                    AnvilSidebarSection(title: "Schedule", icon: "calendar", count: viewModel.entries.count) {
                        ForEach(viewModel.entries) { entry in
                            scheduleEntryRow(entry)
                                .tag(entry.id)
                                .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedScheduleEntryID) { _, newId in
                    viewModel.selectedEntryID = newId
                }
                .onChange(of: viewModel.selectedEntryID) { _, newId in
                    selectedScheduleEntryID = newId
                }
                .onAppear {
                    selectedScheduleEntryID = viewModel.selectedEntryID
                }
            }
        }
    }

    private func scheduleEntryRow(_ entry: ScheduleEntry) -> some View {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()

        return AnvilListItem(
            icon: entry.kindIcon,
            title: entry.title,
            subtitle: entry.duration,
            tag: entry.kindLabel,
            tagColor: entry.kindColor,
            timestamp: timeFormatter.string(from: entry.start),
            isSelected: selectedScheduleEntryID == entry.id,
            isCompact: false
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(timeFormatter.string(from: entry.start))")
    }
}

// MARK: - Extensions Sidebar (compact list for sidebar)

struct ExtensionsSidebarView: View {
    @ObservedObject var viewModel: PluginMarketplaceViewModel
    @State private var selectedPluginID: String?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.installedPlugins.isEmpty && viewModel.plugins.isEmpty {
                AnvilSidebarEmptyState(
                    icon: "puzzlepiece.extension",
                    title: "No extensions installed",
                    message: "Browse the marketplace to discover extensions.",
                    actions: [
                        EmptyStateAction("Browse Marketplace", icon: "puzzlepiece.extension") {
                            viewModel.viewMode = .browse
                        }
                    ]
                )
            } else {
                List(selection: $selectedPluginID) {
                    if !viewModel.installedPlugins.isEmpty {
                        AnvilSidebarSection(title: "Installed", icon: "puzzlepiece.extension", count: viewModel.installedPlugins.count) {
                            ForEach(viewModel.installedPlugins) { plugin in
                                extensionRow(plugin)
                                    .tag(plugin.id)
                            }
                        }
                    }

                    AnvilSidebarSection(title: "Browse", icon: "square.grid.2x2", count: nil) {
                        AnvilSidebarRowButton(
                            title: "Browse Marketplace",
                            icon: "puzzlepiece.extension"
                        ) {
                            viewModel.viewMode = .browse
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedPluginID) { _, newId in
                    guard let id = newId else { return }
                    viewModel.selectPlugin(id)
                }
            }
        }
        .onAppear {
            if viewModel.plugins.isEmpty {
                viewModel.loadBuiltInPlugins()
            }
        }
    }

    private func extensionRow(_ plugin: MarketplacePlugin) -> some View {
        AnvilListItem(
            icon: plugin.icon,
            title: plugin.name,
            subtitle: plugin.author,
            tag: plugin.isEnabled ? "Enabled" : "Disabled",
            tagColor: plugin.isEnabled ? AnvilColor.accentGreen : AnvilColor.textTertiary,
            isSelected: selectedPluginID == plugin.id
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plugin.name), \(plugin.isEnabled ? "Enabled" : "Disabled")")
    }
}
