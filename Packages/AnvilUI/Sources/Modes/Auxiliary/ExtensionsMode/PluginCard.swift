import SwiftUI

struct PluginCard: View {
    let plugin: MarketplacePlugin
    let onSelect: () -> Void
    let onInstall: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AnvilSpacing.sm) {
                // Plugin icon
                Image(systemName: plugin.icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(AnvilColor.accentPurple)
                    .frame(width: 36, height: 36)
                    .background(AnvilColor.accentPurple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AnvilSpacing.xs) {
                        Text(plugin.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text(plugin.author)
                            .font(AnvilFont.label)
                            .foregroundStyle(.tertiary)
                    }

                    Text(plugin.pluginDescription)
                        .font(AnvilFont.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Stats
                HStack(spacing: AnvilSpacing.md) {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text(plugin.downloadCountFormatted)
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(.tertiary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(plugin.downloadCountFormatted) downloads")

                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.accentAmber)
                            .accessibilityHidden(true)
                        Text(String(format: "%.1f", plugin.rating))
                            .font(AnvilFont.label)
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Rating \(String(format: "%.1f", plugin.rating)) out of 5")

                    Text("v\(plugin.version)")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                }

                installButton
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plugin.name) by \(plugin.author), \(plugin.pluginDescription)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var installButton: some View {
        if plugin.isInstalled {
            AnvilBadge(text: "Installed", color: AnvilColor.accentGreen)
                .accessibilityLabel("Installed")
        } else {
            Button("Install") {
                onInstall()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel("Install \(plugin.name)")
            .accessibilityAddTraits(.isButton)
        }
    }
}
