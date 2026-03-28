import SwiftUI

struct InstalledPluginsView: View {
    @ObservedObject var viewModel: PluginMarketplaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installed Extensions")
                        .font(AnvilFont.heading)
                    Text("\(viewModel.installedCount) extension\(viewModel.installedCount == 1 ? "" : "s") installed")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                AnvilButton("Browse Marketplace", icon: "puzzlepiece.extension", style: .secondary) {
                    viewModel.viewMode = .browse
                }
            }
            .padding(AnvilSpacing.lg)

            Divider()

            if viewModel.installedPlugins.isEmpty {
                AnvilEmptyState(
                    icon: "puzzlepiece.extension",
                    title: "No extensions installed",
                    message: "Browse the marketplace to find extensions.",
                    actions: [
                        EmptyStateAction("Browse Marketplace", icon: "magnifyingglass", style: .primary) {
                            viewModel.viewMode = .browse
                        }
                    ]
                )
            } else {
                List {
                    ForEach(viewModel.installedPlugins) { plugin in
                        InstalledPluginRow(
                            plugin: plugin,
                            onToggle: { viewModel.togglePlugin(plugin.id) },
                            onUninstall: { viewModel.uninstallPlugin(plugin.id) },
                            onSelect: { viewModel.selectPlugin(plugin.id) }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(.background)
    }
}

// MARK: - Installed Plugin Row

struct InstalledPluginRow: View {
    let plugin: MarketplacePlugin
    let onToggle: () -> Void
    let onUninstall: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: AnvilSpacing.md) {
            // Plugin icon
            Image(systemName: plugin.icon)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(AnvilColor.accentPurple)
                .frame(width: 36, height: 36)
                .background(AnvilColor.accentPurple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AnvilSpacing.xs) {
                    Text(plugin.name)
                        .font(.system(size: 13, weight: .medium))

                    Text("v\(plugin.version)")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                }

                Text(plugin.author)
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Enable/Disable toggle
            Toggle("", isOn: Binding(
                get: { plugin.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            // Uninstall button
            Button {
                onUninstall()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Uninstall")

            // Settings / detail
            Button {
                onSelect()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .contentShape(Rectangle())
    }
}
