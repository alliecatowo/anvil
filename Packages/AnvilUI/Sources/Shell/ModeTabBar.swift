import SwiftUI

public struct ModeTabBar: View {
    @EnvironmentObject var appState: AppState
    @State private var hoveredMode: AnvilMode?

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Traffic light spacer
            Color.clear.frame(width: 78, height: 1)

            // Core modes
            ForEach(AnvilMode.coreModes) { mode in
                ModeTab(
                    mode: mode,
                    isActive: appState.currentMode == mode,
                    isHovered: hoveredMode == mode,
                    badgeCount: badgeCount(for: mode)
                ) {
                    appState.switchMode(mode)
                }
                .onHover { isHovered in
                    hoveredMode = isHovered ? mode : nil
                }
            }

            Divider()
                .frame(height: 16)
                .overlay(AnvilColor.borderSubtle)
                .padding(.horizontal, AnvilSpacing.sm)

            // Auxiliary modes
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
                .onHover { isHovered in
                    hoveredMode = isHovered ? mode : nil
                }
            }

            Spacer()

            // Profile avatar
            ProfileAvatar()
                .padding(.trailing, AnvilSpacing.sm)

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
        .background(.ultraThinMaterial)
        .background(AnvilColor.backgroundSecondary.opacity(0.7))
    }

    private func badgeCount(for mode: AnvilMode) -> Int {
        switch mode {
        case .agent:
            // Count pending tool calls across all running sessions
            return appState.agentViewModel.sessions
                .filter { $0.status == .running }
                .flatMap(\.messages)
                .flatMap(\.toolCalls)
                .filter { $0.status == .pending }
                .count
        case .review:
            return appState.reviewViewModel.reviews.filter { $0.status == .pending }.count
        case .messaging:
            // Unread message count (channels with activity)
            return appState.intentViewModel.tickets.filter { $0.labels.contains("unread") }.count
        case .notifications:
            return appState.intentViewModel.tickets.filter { $0.status == "open" }.count
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
            VStack(spacing: 0) {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: mode.icon)
                        .font(.system(size: isCompact ? 12 : 13, weight: isActive ? .semibold : .regular))

                    if !isCompact {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    }

                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentRed)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, isCompact ? AnvilSpacing.sm : AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xxs)
                .background(backgroundFill)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(height: 34)

                // Active indicator line
                RoundedRectangle(cornerRadius: 1)
                    .fill(isActive ? AnvilColor.accentPurple : .clear)
                    .frame(height: 2)
                    .padding(.horizontal, isCompact ? AnvilSpacing.xs : AnvilSpacing.sm)
            }
        }
        .buttonStyle(.plain)
        .help(isCompact ? mode.rawValue : "")
        .animation(AnvilAnimation.modeSwitch, value: isActive)
    }

    private var foregroundColor: Color {
        if isActive { return AnvilColor.textPrimary }
        if isHovered { return AnvilColor.textSecondary }
        return AnvilColor.textTertiary
    }

    private var backgroundFill: Color {
        if isActive { return AnvilColor.backgroundTertiary }
        if isHovered { return AnvilColor.backgroundTertiary.opacity(0.5) }
        return .clear
    }
}

// MARK: - ProfileAvatar

struct ProfileAvatar: View {
    @State private var isHovered = false

    var body: some View {
        Button {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } label: {
            ZStack {
                Circle()
                    .fill(AnvilColor.accentPurple.opacity(0.2))
                    .frame(width: 24, height: 24)

                Text(initials)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AnvilColor.accentPurple)
            }
            .overlay(
                Circle()
                    .stroke(isHovered ? AnvilColor.accentPurple.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Settings")
    }

    private var initials: String {
        // Use first letter of username from system
        let name = NSFullUserName()
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
