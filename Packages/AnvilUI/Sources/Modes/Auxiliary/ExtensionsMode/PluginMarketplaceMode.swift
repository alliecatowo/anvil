import SwiftUI

struct PluginMarketplaceMode: View {
    @StateObject private var viewModel = PluginMarketplaceViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Navigation tabs (hidden in detail view)
            if !viewModel.viewMode.isDetail {
                extensionsTabs
                Divider().overlay(AnvilColor.borderSubtle)
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
        .background(AnvilColor.backgroundPrimary)
        .onAppear {
            if viewModel.plugins.isEmpty {
                viewModel.loadBuiltInPlugins()
            }
        }
    }

    private var extensionsTabs: some View {
        HStack(spacing: 0) {
            extensionTab("Marketplace", icon: "puzzlepiece.extension", isActive: viewModel.viewMode.isBrowse) {
                viewModel.viewMode = .browse
            }

            extensionTab("Installed (\(viewModel.installedCount))", icon: "checkmark.circle", isActive: viewModel.viewMode.isInstalled) {
                viewModel.viewMode = .installed
            }

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary)
    }

    private func extensionTab(_ title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(AnvilFont.label)
            }
            .foregroundStyle(isActive ? AnvilColor.textPrimary : AnvilColor.textTertiary)
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .background(isActive ? AnvilColor.backgroundTertiary : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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

            Divider().overlay(AnvilColor.borderSubtle)

            // Plugin grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 300, maximum: 400), spacing: AnvilSpacing.md)
                ], spacing: AnvilSpacing.md) {
                    ForEach(viewModel.filteredPlugins) { plugin in
                        PluginCard(plugin: plugin) {
                            viewModel.selectPlugin(plugin.id)
                        } onInstall: {
                            viewModel.installPlugin(plugin.id)
                        } onUninstall: {
                            viewModel.uninstallPlugin(plugin.id)
                        }
                    }
                }
                .padding(AnvilSpacing.lg)
            }

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

            // Category filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AnvilSpacing.xs) {
                    ForEach(PluginCategory.allCases) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, AnvilSpacing.lg)
            }
            .padding(.bottom, AnvilSpacing.sm)
        }
    }

    private func categoryChip(_ category: PluginCategory) -> some View {
        Button {
            viewModel.selectedCategory = category
        } label: {
            HStack(spacing: AnvilSpacing.xxs) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                Text(category.rawValue)
                    .font(AnvilFont.label)
            }
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xxs)
            .foregroundStyle(
                viewModel.selectedCategory == category
                    ? Color.white
                    : AnvilColor.textSecondary
            )
            .background(
                viewModel.selectedCategory == category
                    ? AnvilColor.accentPurple
                    : AnvilColor.backgroundTertiary
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
