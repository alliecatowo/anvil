import SwiftUI

// MARK: - Sidebar Glass

/// Applies Liquid Glass with dark tint (less refractive than default .regular).
/// Falls back to ultraThickMaterial on pre-Tahoe.
struct SidebarGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular.tint(.black.opacity(0.15)), in: .rect(cornerRadius: 10))
        } else {
            content.background(.ultraThickMaterial)
        }
    }
}

extension View {
    func sidebarGlass() -> some View {
        modifier(SidebarGlass())
    }
}

// MARK: - Unified Sidebar Panel (Rail + Content as one glass surface)

/// The sidebar is ONE unified glass panel containing the icon rail and content sidebar.
/// When collapsed, only the rail shows. When expanded, rail + content are one surface.
public struct SidebarPanel: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Icon rail
            railIcons

            // Content sidebar (when expanded)
            if !appState.isSidebarCollapsed {
                Divider()
                    .opacity(0.3)

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
                .frame(width: AnvilSpacing.sidebarWidth)
            }
        }
        .sidebarGlass()
        .padding(4)
    }

    // MARK: - Rail Icons

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

    private var railIcons: some View {
        VStack(spacing: 4) {
            ForEach(spaces) { entry in
                RailButton(
                    icon: entry.icon,
                    title: entry.label,
                    isActive: appState.currentSpace == entry.space,
                    accentColor: entry.space.spaceAccent,
                    action: { appState.switchSpace(entry.space) }
                )
            }
            Spacer()
        }
        .padding(.vertical, AnvilSpacing.sm)
        .frame(width: AnvilSpacing.iconRailWidth)
    }
}

// MARK: - Legacy wrappers (keep for compatibility)

public struct IconRail: View {
    public init() {}
    public var body: some View { EmptyView() }
}

public struct ContentSidebar: View {
    public init() {}
    public var body: some View { EmptyView() }
}

public struct Sidebar: View {
    public init() {}
    public var body: some View { SidebarPanel() }
}

// MARK: - Rail Button

private struct RailButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var accentColor: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? accentColor : .secondary)
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .help(title)
    }
}
