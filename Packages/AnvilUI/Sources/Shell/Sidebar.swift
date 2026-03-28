import SwiftUI
import AnvilTerminal

public struct Sidebar: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if appState.isSidebarCollapsed {
                CollapsedSidebar()
            } else {
                // Delegate to space-specific sidebar
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
        }
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(width: 1)
        }
    }
}

struct CollapsedSidebar: View {
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

    var body: some View {
        VStack(spacing: 0) {
            railButton(
                icon: "sidebar.leading",
                title: "Expand Navigation",
                isActive: false,
                action: { appState.isSidebarCollapsed = false }
            )

            railDivider

            VStack(spacing: 4) {
                ForEach(spaces) { entry in
                    railButton(
                        icon: entry.icon,
                        title: entry.label,
                        isActive: appState.currentSpace == entry.space,
                        action: { appState.switchSpace(entry.space) }
                    )
                }
            }

            Spacer()

            railDivider
            railButton(
                icon: "magnifyingglass",
                title: "Find in Project",
                isActive: appState.isProjectSearchVisible,
                action: { appState.toggleProjectSearch() }
            )
            railButton(
                icon: "sidebar.right",
                title: "Toggle Inspector",
                isActive: appState.isInspectorVisible,
                action: { appState.toggleInspector() }
            )
        }
        .padding(.vertical, AnvilSpacing.sm)
    }

    private var railDivider: some View {
        Rectangle()
            .fill(AnvilColor.borderSubtle)
            .frame(height: 1)
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)
    }

    private func railButton(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .frame(width: 36, height: 32)
                .background(isActive ? Color.accentColor.opacity(0.14) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}

struct TerminalSessionList: View {
    @ObservedObject var viewModel: TerminalViewModel
    var onSelect: ((UUID) -> Void)?

    var body: some View {
        ForEach(viewModel.sessions) { session in
            AnvilSidebarRowButton(
                title: session.title,
                icon: session.isRunning ? "terminal" : "terminal.fill",
                subtitle: session.isRunning ? "running" : "exited",
                isActive: isSelected(session),
                action: {
                    viewModel.selectTab(session.id)
                    onSelect?(session.id)
                }
            )
        }
    }

    private func isSelected(_ session: TerminalSession) -> Bool {
        viewModel.selectedSessionId == session.id
    }
}
