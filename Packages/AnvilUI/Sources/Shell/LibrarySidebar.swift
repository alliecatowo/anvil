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

    private var notificationsList: some View {
        let viewModel = appState.notificationsViewModel
        return Group {
            if viewModel.inboxItems.isEmpty {
                Text("No notifications")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.inboxItems) { item in
                        Button {
                            viewModel.selectedItemID = item.id
                            viewModel.markAsRead(item.id)
                        } label: {
                            notificationRow(item, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.notification.isRead ? "" : "Unread, ")\(item.notification.title), \(item.notification.body)")
                        .accessibilityAddTraits(.isButton)
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.sidebar)
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
            isSelected: viewModel.selectedItemID == item.id,
            isCompact: false
        )
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

    private var scheduleSidebarList: some View {
        let viewModel = appState.scheduleViewModel
        return Group {
            if viewModel.entries.isEmpty {
                VStack(spacing: AnvilSpacing.md) {
                    Text("No events today")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Button {
                        viewModel.loadSampleData()
                    } label: {
                        Label("Load Demo Data", systemImage: "tray.and.arrow.down")
                            .font(AnvilFont.body)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    AnvilSidebarSection(title: "Schedule", icon: "calendar", count: viewModel.entries.count) {
                        ForEach(viewModel.entries) { entry in
                            scheduleEntryRow(entry, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func scheduleEntryRow(_ entry: ScheduleEntry, viewModel: ScheduleViewModel) -> some View {
        let isSelected = viewModel.selectedEntryID == entry.id
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()

        return Button {
            viewModel.selectedEntryID = entry.id
        } label: {
            AnvilListItem(
                icon: entry.kindIcon,
                title: entry.title,
                subtitle: entry.duration,
                tag: entry.kindLabel,
                tagColor: entry.kindColor,
                timestamp: timeFormatter.string(from: entry.start),
                isSelected: isSelected,
                isCompact: false
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(timeFormatter.string(from: entry.start))")
        .accessibilityAddTraits(.isButton)
        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Extensions Sidebar (compact list for sidebar)

struct ExtensionsSidebarView: View {
    @ObservedObject var viewModel: PluginMarketplaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.installedPlugins.isEmpty && viewModel.plugins.isEmpty {
                // Not yet loaded
                VStack(spacing: AnvilSpacing.md) {
                    Text("No extensions installed")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Button {
                        viewModel.viewMode = .browse
                    } label: {
                        Label("Browse Marketplace", systemImage: "puzzlepiece.extension")
                            .font(AnvilFont.body)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !viewModel.installedPlugins.isEmpty {
                        AnvilSidebarSection(title: "Installed", icon: "puzzlepiece.extension", count: viewModel.installedPlugins.count) {
                            ForEach(viewModel.installedPlugins) { plugin in
                                extensionRow(plugin)
                            }
                        }
                    }

                    AnvilSidebarSection(title: "Browse", icon: "square.grid.2x2", count: nil) {
                        Button {
                            viewModel.viewMode = .browse
                        } label: {
                            Label("Browse Marketplace", systemImage: "puzzlepiece.extension")
                                .font(AnvilFont.sidebarItem)
                                .foregroundStyle(AnvilColor.accentBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear {
            if viewModel.plugins.isEmpty {
                viewModel.loadBuiltInPlugins()
            }
        }
    }

    private func extensionRow(_ plugin: MarketplacePlugin) -> some View {
        Button {
            viewModel.selectPlugin(plugin.id)
        } label: {
            AnvilListItem(
                icon: plugin.icon,
                title: plugin.name,
                subtitle: plugin.author,
                tag: plugin.isEnabled ? "Enabled" : "Disabled",
                tagColor: plugin.isEnabled ? AnvilColor.accentGreen : AnvilColor.textTertiary
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plugin.name), \(plugin.isEnabled ? "Enabled" : "Disabled")")
        .accessibilityAddTraits(.isButton)
    }
}
