import SwiftUI

/// Icon rail — always visible 44pt strip with space icons.
/// Matches Xcode Activity Bar behavior: never collapses.
public struct IconRail: View {
    @EnvironmentObject var appState: AppState

    private struct SpaceEntry: Identifiable {
        let space: AnvilSpace
        let icon: String
        let label: String
        var id: AnvilSpace { space }
    }

    private let spaces: [SpaceEntry] = [
        SpaceEntry(space: .plan, icon: "target", label: "Plan"),
        SpaceEntry(space: .build, icon: "hammer", label: "Build"),
        SpaceEntry(space: .review, icon: "checkmark.circle", label: "Review"),
        SpaceEntry(space: .operate, icon: "gauge", label: "Operate"),
        SpaceEntry(space: .library, icon: "books.vertical", label: "Library"),
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            ForEach(spaces) { entry in
                RailButton(
                    icon: entry.icon,
                    title: entry.label,
                    isActive: appState.currentSpace == entry.space,
                    action: { appState.switchSpace(entry.space) }
                )
            }

            Spacer()
        }
        .padding(.vertical, AnvilSpacing.sm)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Divider()
        }
    }
}

/// Content sidebar — the 260pt space-specific panel that collapses with the sidebar toggle.
public struct ContentSidebar: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            switch appState.currentSpace {
            case .plan:
                IntentSidebar(viewModel: appState.intentViewModel)
            case .build:
                BuildSidebar()
            case .review:
                ReviewSidebar(viewModel: appState.reviewViewModel)
            case .operate:
                OperateSidebar()
            case .library:
                LibrarySidebar()
            }
        }
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Divider()
        }
    }
}

/// Legacy Sidebar wrapper — kept for any remaining references.
/// New code should use IconRail + ContentSidebar directly.
public struct Sidebar: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            IconRail()
                .frame(width: AnvilSpacing.iconRailWidth)
            if !appState.isSidebarCollapsed {
                ContentSidebar()
            }
        }
    }
}

private struct RailButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .help(title)
    }
}
