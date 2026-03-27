import SwiftUI

public struct ModeTabBar: View {
    @EnvironmentObject var appState: AppState
    @State private var hoveredMode: AnvilMode?

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Traffic light spacer
            Color.clear.frame(width: 78, height: 1)

            // Core modes (always visible with labels)
            ForEach(AnvilMode.coreModes) { mode in
                ModeTab(
                    mode: mode,
                    isActive: appState.currentMode == mode,
                    isHovered: hoveredMode == mode,
                    badgeCount: badgeCount(for: mode)
                ) {
                    appState.switchMode(mode)
                }
                .onHover { hoveredMode = $0 ? mode : nil }
            }

            Divider()
                .frame(height: 14)
                .overlay(AnvilColor.borderSubtle)
                .padding(.horizontal, 6)

            // Auxiliary modes (compact icons only, tightly packed)
            HStack(spacing: 2) {
                ForEach(AnvilMode.auxiliaryModes) { mode in
                    ModeTab(
                        mode: mode,
                        isActive: appState.currentMode == mode,
                        isHovered: hoveredMode == mode,
                        isCompact: true,
                        badgeCount: badgeCount(for: mode)
                    ) {
                        appState.switchMode(mode)
                    }
                    .onHover { hoveredMode = $0 ? mode : nil }
                }
            }

            Spacer()

            // Search trigger
            Button {
                appState.toggleCommandPalette()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                    Text("\u{2318}K")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .foregroundStyle(AnvilColor.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AnvilColor.backgroundTertiary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)

            // Settings gear
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Settings")
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(AnvilColor.backgroundSecondary)
    }

    private func badgeCount(for mode: AnvilMode) -> Int {
        switch mode {
        case .agent:
            return appState.agentViewModel.sessions
                .filter { $0.status == .running }
                .flatMap(\.messages)
                .flatMap(\.toolCalls)
                .filter { $0.status == .pending }
                .count
        case .review:
            return appState.reviewViewModel.reviews.filter { $0.status == .pending }.count
        default:
            return 0
        }
    }
}

// MARK: - ModeTab

struct ModeTab: View {
    let mode: AnvilMode
    let isActive: Bool
    var isHovered: Bool = false
    var isCompact: Bool = false
    var badgeCount: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: mode.icon)
                    .font(.system(size: isCompact ? 13 : 13, weight: isActive ? .semibold : .regular))

                if !isCompact {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                }

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(AnvilColor.accentRed)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, isCompact ? 8 : 10)
            .padding(.vertical, 5)
            .background(isActive ? AnvilColor.backgroundTertiary : (isHovered ? AnvilColor.backgroundTertiary.opacity(0.4) : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(isCompact ? mode.rawValue : "")
    }

    private var foregroundColor: Color {
        if isActive { return AnvilColor.textPrimary }
        if isHovered { return AnvilColor.textSecondary }
        return AnvilColor.textTertiary
    }
}
