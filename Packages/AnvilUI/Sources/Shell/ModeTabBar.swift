import SwiftUI

public struct ModeTabBar: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Traffic light spacer
            Color.clear.frame(width: 78, height: 1)

            // Core modes
            ForEach(AnvilMode.coreModes) { mode in
                ModeTab(mode: mode, isActive: appState.currentMode == mode) {
                    appState.switchMode(mode)
                }
            }

            Divider()
                .frame(height: 16)
                .overlay(AnvilColor.borderSubtle)
                .padding(.horizontal, AnvilSpacing.sm)

            // Auxiliary modes
            ForEach(AnvilMode.auxiliaryModes) { mode in
                ModeTab(mode: mode, isActive: appState.currentMode == mode, isCompact: true) {
                    appState.switchMode(mode)
                }
            }

            Spacer()

            // Search trigger
            Button {
                appState.toggleCommandPalette()
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                        .font(AnvilFont.label)
                    Text("\u{2318}K")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .foregroundStyle(AnvilColor.textSecondary)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xxs)
                .background(AnvilColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(.trailing, AnvilSpacing.md)
        }
        .frame(height: 38)
        .background(AnvilColor.backgroundSecondary)
    }
}

struct ModeTab: View {
    let mode: AnvilMode
    let isActive: Bool
    var isCompact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AnvilSpacing.xxs) {
                Image(systemName: mode.icon)
                    .font(.system(size: isCompact ? 12 : 13, weight: isActive ? .semibold : .regular))

                if !isCompact {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                }
            }
            .foregroundStyle(isActive ? AnvilColor.textPrimary : AnvilColor.textSecondary)
            .padding(.horizontal, isCompact ? AnvilSpacing.sm : AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xxs)
            .background(isActive ? AnvilColor.backgroundTertiary : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(isCompact ? mode.rawValue : "")
    }
}
