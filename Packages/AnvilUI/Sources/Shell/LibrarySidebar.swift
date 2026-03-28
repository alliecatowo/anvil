import SwiftUI

struct LibrarySidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $appState.libraryActiveSection) {
                ForEach(AppState.LibrarySection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Library Sidebar Section")
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)

            Divider()

            switch appState.libraryActiveSection {
            case .docs:
                DocBrowser(viewModel: appState.libraryDocsViewModel)
            case .extensions:
                ExtensionsSidebarView(viewModel: appState.pluginMarketplaceViewModel)
            case .notifications:
                notificationsList
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
                        HStack(spacing: AnvilSpacing.sm) {
                            Circle()
                                .fill(item.notification.isRead ? Color.clear : AnvilColor.accentBlue)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)

                            Image(systemName: item.source.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(item.source.color)
                                .frame(width: 16)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.notification.title)
                                    .font(AnvilFont.sidebarItem)
                                    .foregroundStyle(AnvilColor.textPrimary)
                                    .lineLimit(1)

                                Text(item.notification.body)
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.vertical, AnvilSpacing.xxs)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedItemID = item.id
                            viewModel.markAsRead(item.id)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.notification.isRead ? "" : "Unread, ")\(item.notification.title), \(item.notification.body)")
                        .accessibilityAddTraits(.isButton)
                        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 8))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.sidebar)
            }
        }
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
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !viewModel.installedPlugins.isEmpty {
                        Section {
                            ForEach(viewModel.installedPlugins) { plugin in
                                extensionRow(plugin)
                            }
                        } header: {
                            Text("Installed")
                                .font(AnvilFont.label)
                        }
                    }

                    Section {
                        Button {
                            viewModel.viewMode = .browse
                        } label: {
                            Label("Browse Marketplace", systemImage: "puzzlepiece.extension")
                                .font(AnvilFont.sidebarItem)
                                .foregroundStyle(AnvilColor.accentBlue)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 8))
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
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: plugin.icon)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(AnvilColor.accentPurple)
                .frame(width: 22, height: 22)
                .background(AnvilColor.accentPurple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 1) {
                Text(plugin.name)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text(plugin.author)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Circle()
                .fill(plugin.isEnabled ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                .frame(width: 6, height: 6)
                .accessibilityLabel(plugin.isEnabled ? "Enabled" : "Disabled")
        }
        .padding(.vertical, AnvilSpacing.xxs)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectPlugin(plugin.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plugin.name), \(plugin.isEnabled ? "Enabled" : "Disabled")")
        .accessibilityAddTraits(.isButton)
        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 8))
        .listRowSeparator(.hidden)
    }
}
