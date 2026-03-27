import SwiftUI

struct PluginDetailView: View {
    @ObservedObject var viewModel: PluginMarketplaceViewModel
    let pluginId: String

    private var plugin: MarketplacePlugin? {
        viewModel.plugins.first { $0.id == pluginId }
    }

    var body: some View {
        if let plugin {
            VStack(spacing: 0) {
                // Back navigation
                HStack {
                    Button {
                        viewModel.viewMode = .browse
                        viewModel.selectedPluginId = nil
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .medium))
                            Text("Back")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentBlue)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.lg)
                .padding(.vertical, AnvilSpacing.sm)

                Divider().overlay(AnvilColor.borderSubtle)

                ScrollView {
                    VStack(alignment: .leading, spacing: AnvilSpacing.xl) {
                        // Plugin header
                        pluginHeader(plugin)

                        Divider().overlay(AnvilColor.borderSubtle)

                        // Description
                        descriptionSection(plugin)

                        Divider().overlay(AnvilColor.borderSubtle)

                        // Details
                        detailsSection(plugin)

                        if plugin.isInstalled {
                            Divider().overlay(AnvilColor.borderSubtle)
                            settingsSection(plugin)
                        }
                    }
                    .padding(AnvilSpacing.lg)
                }
            }
            .background(AnvilColor.backgroundPrimary)
        } else {
            AnvilEmptyState(
                icon: "puzzlepiece.extension",
                title: "Plugin not found",
                message: "This plugin may have been removed."
            )
        }
    }

    // MARK: - Sections

    private func pluginHeader(_ plugin: MarketplacePlugin) -> some View {
        HStack(spacing: AnvilSpacing.lg) {
            Image(systemName: plugin.icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AnvilColor.accentPurple)
                .frame(width: 64, height: 64)
                .background(AnvilColor.accentPurple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                Text(plugin.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AnvilColor.textPrimary)

                HStack(spacing: AnvilSpacing.md) {
                    Text(plugin.author)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)

                    AnvilBadge(text: plugin.category.rawValue, color: AnvilColor.accentPurple)
                }

                HStack(spacing: AnvilSpacing.md) {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                        Text(plugin.downloadCountFormatted + " downloads")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.textTertiary)

                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AnvilColor.accentAmber)
                        Text(String(format: "%.1f", plugin.rating))
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: AnvilSpacing.sm) {
                if plugin.isInstalled {
                    AnvilButton("Uninstall", icon: "trash", style: .destructive) {
                        viewModel.uninstallPlugin(pluginId)
                    }

                    HStack(spacing: AnvilSpacing.xs) {
                        Circle()
                            .fill(plugin.isEnabled ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                            .frame(width: 8, height: 8)
                        Text(plugin.isEnabled ? "Enabled" : "Disabled")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                } else {
                    AnvilButton("Install", icon: "arrow.down.circle", style: .primary) {
                        viewModel.installPlugin(pluginId)
                    }
                }
            }
        }
    }

    private func descriptionSection(_ plugin: MarketplacePlugin) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Description")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AnvilColor.textPrimary)

            Text(plugin.pluginDescription)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailsSection(_ plugin: MarketplacePlugin) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AnvilColor.textPrimary)

            LazyVGrid(columns: [
                GridItem(.fixed(120), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
            ], spacing: AnvilSpacing.sm) {
                detailRow("Version", plugin.version)
                detailRow("Author", plugin.author)
                detailRow("Category", plugin.category.rawValue)
                detailRow("ID", plugin.id)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        Group {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
            Text(value)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
        }
    }

    private func settingsSection(_ plugin: MarketplacePlugin) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AnvilColor.textPrimary)

            VStack(spacing: AnvilSpacing.sm) {
                settingToggle("Enable on startup", isOn: true)
                settingToggle("Show notifications", isOn: true)
                settingToggle("Auto-update", isOn: false)
            }
            .padding(AnvilSpacing.md)
            .background(AnvilColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AnvilColor.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func settingToggle(_ label: String, isOn: Bool) -> some View {
        HStack {
            Text(label)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
            Spacer()
            Toggle("", isOn: .constant(isOn))
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
