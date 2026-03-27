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
                        .foregroundStyle(AnvilColor.textPrimary)
                    Text("\(viewModel.installedCount) extension\(viewModel.installedCount == 1 ? "" : "s") installed")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                Spacer()

                AnvilButton("Browse Marketplace", icon: "puzzlepiece.extension", style: .secondary) {
                    viewModel.viewMode = .browse
                }
            }
            .padding(AnvilSpacing.lg)

            Divider().overlay(AnvilColor.borderSubtle)

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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.installedPlugins) { plugin in
                            InstalledPluginRow(
                                plugin: plugin,
                                onToggle: { viewModel.togglePlugin(plugin.id) },
                                onUninstall: { viewModel.uninstallPlugin(plugin.id) },
                                onSelect: { viewModel.selectPlugin(plugin.id) }
                            )
                        }
                    }
                    .padding(.vertical, AnvilSpacing.sm)
                }
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }
}

// MARK: - Installed Plugin Row

struct InstalledPluginRow: View {
    let plugin: MarketplacePlugin
    let onToggle: () -> Void
    let onUninstall: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

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
                        .foregroundStyle(AnvilColor.textPrimary)

                    Text("v\(plugin.version)")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                Text(plugin.author)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
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
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Uninstall")

            // Settings / detail
            Button {
                onSelect()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(isHovered ? AnvilColor.backgroundTertiary.opacity(0.5) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
