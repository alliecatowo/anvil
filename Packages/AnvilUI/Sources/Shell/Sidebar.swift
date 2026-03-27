import SwiftUI

public struct Sidebar: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if appState.isSidebarCollapsed {
                CollapsedSidebar()
            } else {
                ExpandedSidebar()
            }
        }
        .background(AnvilColor.backgroundSecondary)
    }
}

struct CollapsedSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: AnvilSpacing.sm) {
            ForEach(sidebarSections, id: \.title) { section in
                Button {
                    appState.isSidebarCollapsed = false
                } label: {
                    Image(systemName: section.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(AnvilColor.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help(section.title)
            }
            Spacer()
        }
        .padding(.top, AnvilSpacing.sm)
    }

    var sidebarSections: [SidebarSection] {
        SidebarSection.sections(for: appState.currentMode)
    }
}

struct ExpandedSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(sidebarSections, id: \.title) { section in
                    SidebarSectionView(section: section)
                }
            }
        }
    }

    var sidebarSections: [SidebarSection] {
        SidebarSection.sections(for: appState.currentMode)
    }
}

struct SidebarSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [SidebarItem]

    static func sections(for mode: AnvilMode) -> [SidebarSection] {
        switch mode {
        case .intent:
            return [
                SidebarSection(title: "My Work", icon: "person.circle", items: [
                    SidebarItem(title: "Active Tickets", icon: "ticket", badge: "3"),
                    SidebarItem(title: "Backlog", icon: "tray"),
                ]),
                SidebarSection(title: "Cycles", icon: "arrow.triangle.2.circlepath", items: [
                    SidebarItem(title: "Current Sprint", icon: "flag"),
                ]),
            ]
        case .agent:
            return [
                SidebarSection(title: "Sessions", icon: "cpu", items: [
                    SidebarItem(title: "New Session", icon: "plus.circle"),
                ]),
                SidebarSection(title: "Recent", icon: "clock", items: []),
            ]
        case .review:
            return [
                SidebarSection(title: "Review Inbox", icon: "tray", items: [
                    SidebarItem(title: "Needs Review", icon: "exclamationmark.circle", badge: "2"),
                    SidebarItem(title: "Reviewed", icon: "checkmark.circle"),
                ]),
                SidebarSection(title: "Branches", icon: "arrow.triangle.branch", items: []),
            ]
        case .ship:
            return [
                SidebarSection(title: "Environments", icon: "server.rack", items: [
                    SidebarItem(title: "Production", icon: "circle.fill"),
                    SidebarItem(title: "Staging", icon: "circle.fill"),
                    SidebarItem(title: "Preview", icon: "circle.fill"),
                ]),
            ]
        default:
            return [
                SidebarSection(title: mode.rawValue, icon: mode.icon, items: []),
            ]
        }
    }
}

struct SidebarItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    var badge: String? = nil
}

struct SidebarSectionView: View {
    let section: SidebarSection
    @State private var isExpanded = true

    var body: some View {
        Section {
            if isExpanded {
                ForEach(section.items) { item in
                    AnvilListItem(
                        icon: item.icon,
                        title: item.title,
                        tag: item.badge,
                        tagColor: AnvilColor.accentAmber,
                        isSelected: false
                    )
                }
            }
        } header: {
            Button {
                withAnimation(AnvilAnimation.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .frame(width: 12)

                    Text(section.title.uppercased())
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .tracking(0.3)

                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .background(AnvilColor.backgroundSecondary)
            }
            .buttonStyle(.plain)
        }
    }
}
