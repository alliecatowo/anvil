import SwiftUI

struct PluginCard: View {
    let plugin: MarketplacePlugin
    let onSelect: () -> Void
    let onInstall: () -> Void
    let onUninstall: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                // Top row: icon + name + author
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: plugin.icon)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(AnvilColor.accentPurple)
                        .frame(width: 40, height: 40)
                        .background(AnvilColor.accentPurple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(plugin.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AnvilColor.textPrimary)
                            .lineLimit(1)

                        Text(plugin.author)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }

                    Spacer()

                    installButton
                }

                // Description
                Text(plugin.pluginDescription)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Bottom row: stats
                HStack(spacing: AnvilSpacing.md) {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 10))
                        Text(plugin.downloadCountFormatted)
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.textTertiary)

                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.accentAmber)
                        Text(String(format: "%.1f", plugin.rating))
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }

                    Spacer()

                    Text("v\(plugin.version)")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }
            .padding(AnvilSpacing.cardPadding)
            .background(isHovered ? AnvilColor.backgroundTertiary : AnvilColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                    .stroke(AnvilColor.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var installButton: some View {
        if plugin.isInstalled {
            AnvilBadge(text: "Installed", color: AnvilColor.accentGreen)
        } else {
            Button {
                onInstall()
            } label: {
                Text("Install")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, 3)
                    .background(AnvilColor.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
    }
}
