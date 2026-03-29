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
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                ForEach(spaces) { entry in
                    RailButton(
                        icon: entry.icon,
                        title: entry.label,
                        isActive: appState.currentSpace == entry.space,
                        action: { appState.switchSpace(entry.space) }
                    )
                }
            }

            Spacer()

            railDivider
            RailButton(
                icon: "magnifyingglass",
                title: "Find in Project",
                isActive: appState.isProjectSearchVisible,
                action: { appState.toggleProjectSearch() }
            )
            RailButton(
                icon: "sidebar.right",
                title: "Toggle Inspector",
                isActive: appState.isInspectorVisible,
                action: { appState.toggleInspector() }
            )
        }
        .padding(.vertical, AnvilSpacing.sm)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(width: 1)
        }
    }

    private var railDivider: some View {
        Rectangle()
            .fill(AnvilColor.borderSubtle)
            .frame(height: 1)
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)
            .accessibilityHidden(true)
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
            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(width: 1)
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

    @State private var isHovered = false
    @GestureState private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .frame(width: 36, height: 32)
                .background(
                    isActive
                        ? Color.accentColor.opacity(0.14)
                        : (isHovered ? Color.primary.opacity(0.08) : .clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, pressed, _ in pressed = true }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .help(title)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
