import SwiftUI

struct PluginMarketplaceMode: View {
    @StateObject private var viewModel = PluginMarketplaceViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.viewMode.isDetail {
                extensionsTabs
                Divider()
            }

            Group {
                switch viewModel.viewMode {
                case .browse:
                    MarketplaceBrowser(viewModel: viewModel)
                case .installed:
                    InstalledPluginsView(viewModel: viewModel)
                case .detail(let pluginId):
                    PluginDetailView(viewModel: viewModel, pluginId: pluginId)
                }
            }
        }
        .background(.background)
        .onAppear {
            if viewModel.plugins.isEmpty {
                viewModel.loadBuiltInPlugins()
            }
        }
    }

    private var extensionsTabs: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Picker("View", selection: Binding(
                get: { viewModel.viewMode.isInstalled ? 1 : 0 },
                set: { viewModel.viewMode = $0 == 1 ? .installed : .browse }
            )) {
                Text("Marketplace").tag(0)
                Text("Installed (\(viewModel.installedCount))").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(.bar)
    }
}

// MARK: - ViewMode helpers

extension PluginMarketplaceViewModel.ExtensionsViewMode {
    var isBrowse: Bool {
        if case .browse = self { return true }
        return false
    }

    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }

    var isDetail: Bool {
        if case .detail = self { return true }
        return false
    }
}

// MARK: - Marketplace Browser

struct MarketplaceBrowser: View {
    @ObservedObject var viewModel: PluginMarketplaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            marketplaceHeader

            Divider()

            // Plugin list
            List {
                ForEach(viewModel.filteredPlugins) { plugin in
                    PluginCard(plugin: plugin) {
                        viewModel.selectPlugin(plugin.id)
                    } onInstall: {
                        viewModel.installPlugin(plugin.id)
                    } onUninstall: {
                        viewModel.uninstallPlugin(plugin.id)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
            }
            .listStyle(.inset)

            if viewModel.filteredPlugins.isEmpty {
                AnvilEmptyState(
                    icon: "puzzlepiece.extension",
                    title: "No plugins found",
                    message: "Try adjusting your search or category filter."
                )
            }
        }
    }

    private var marketplaceHeader: some View {
        VStack(spacing: AnvilSpacing.sm) {
            HStack(spacing: AnvilSpacing.md) {
                AnvilSearchField(text: $viewModel.searchText, placeholder: "Search extensions...")

                Spacer()

                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(PluginCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.icon).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)

                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(PluginSortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.top, AnvilSpacing.md)
        }
    }
}
