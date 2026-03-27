import SwiftUI
import AnvilApplication

// MARK: - WelcomePage

/// Full-window welcome/start page shown when no project is open.
/// Displayed instead of the normal mode content area.
public struct WelcomePage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    @State private var recentProjects: [Project] = []
    @State private var hoveredProjectId: String?
    @State private var isLoadingProject = false
    @State private var appeared = false

    public init() {}

    public var body: some View {
        ZStack {
            // Background
            AnvilColor.backgroundPrimary
                .ignoresSafeArea()

            // Subtle radial gradient behind center content
            RadialGradient(
                colors: [AnvilColor.accentPurple.opacity(0.04), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    // Anvil wordmark + tagline
                    headerSection

                    Spacer().frame(height: 56)

                    // Primary actions row
                    primaryActionsRow

                    Spacer().frame(height: 48)

                    // Recent projects
                    if !recentProjects.isEmpty {
                        recentProjectsSection
                        Spacer().frame(height: 48)
                    }

                    // Quick-start tips
                    tipsSection

                    Spacer().frame(height: 80)
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: appeared)
        .task {
            await loadRecentProjects()
            withAnimation {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AnvilSpacing.sm) {
            // App icon placeholder — square with anvil icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                AnvilColor.accentPurple.opacity(0.3),
                                AnvilColor.accentBlue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AnvilColor.accentPurple.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: "hammer.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(AnvilColor.accentPurple)
            }

            Spacer().frame(height: AnvilSpacing.sm)

            Text("Anvil")
                .font(.system(size: 32, weight: .semibold, design: .default))
                .foregroundStyle(AnvilColor.textPrimary)

            Text("Agent-native development environment")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
        }
    }

    // MARK: - Primary Actions

    private var primaryActionsRow: some View {
        HStack(spacing: AnvilSpacing.md) {
            WelcomeActionCard(
                icon: "folder.badge.plus",
                title: "Open Project",
                subtitle: "Open a local repository",
                shortcut: "⌘O",
                isPrimary: true
            ) {
                openProject()
            }

            WelcomeActionCard(
                icon: "square.and.arrow.down",
                title: "Clone Repository",
                subtitle: "Clone from GitHub or URL",
                shortcut: nil
            ) {
                // Future: show clone sheet
            }

            WelcomeActionCard(
                icon: "plus.square",
                title: "New Project",
                subtitle: "Create from scratch",
                shortcut: nil
            ) {
                // Future: show new project sheet
            }
        }
        .padding(.horizontal, AnvilSpacing.xl)
    }

    // MARK: - Recent Projects

    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            HStack {
                Text("Recent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.8)
                    .textCase(.uppercase)

                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.xl)

            VStack(spacing: AnvilSpacing.xxs) {
                ForEach(recentProjects.prefix(8)) { project in
                    RecentProjectRow(
                        project: project,
                        isHovered: hoveredProjectId == project.id,
                        isLoading: isLoadingProject
                    ) {
                        openRecentProject(project)
                    }
                    .onHover { hovered in
                        hoveredProjectId = hovered ? project.id : nil
                    }
                }
            }
            .padding(.horizontal, AnvilSpacing.xl)
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(spacing: AnvilSpacing.md) {
            HStack {
                Text("Getting started")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.8)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.xl)

            HStack(alignment: .top, spacing: AnvilSpacing.md) {
                WelcomeTipCard(
                    icon: "cpu",
                    iconColor: AnvilColor.accentPurple,
                    title: "Agent mode",
                    tip: "Press ⌘2 or click Agent. Type your intent — the agent reads your codebase and works autonomously."
                )

                WelcomeTipCard(
                    icon: "target",
                    iconColor: AnvilColor.accentBlue,
                    title: "Intent mode",
                    tip: "Track tickets in ⌘1. Press ⌘↵ on any ticket to start an agent session scoped to that work."
                )

                WelcomeTipCard(
                    icon: "command",
                    iconColor: AnvilColor.accentTeal,
                    title: "Command palette",
                    tip: "⌘K opens everything: files, tickets, branches, agent sessions, settings — from anywhere."
                )
            }
            .padding(.horizontal, AnvilSpacing.xl)
        }
    }

    // MARK: - Actions

    private func openProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project folder"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            isLoadingProject = true
            Task {
                await container.openProject(at: url.path)
                isLoadingProject = false
            }
        }
    }

    private func openRecentProject(_ project: Project) {
        guard let path = project.primaryRepoPath else { return }
        isLoadingProject = true
        Task {
            await container.openProject(at: path)
            isLoadingProject = false
        }
    }

    private func loadRecentProjects() async {
        let projects = await container.projectManager.allProjects()
        await MainActor.run {
            recentProjects = projects
        }
    }
}

// MARK: - WelcomeActionCard

private struct WelcomeActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let shortcut: String?
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isPrimary ? AnvilColor.accentBlue : AnvilColor.textSecondary)
                        .frame(width: 24, height: 24)

                    Spacer()

                    if let shortcut {
                        Text(shortcut)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AnvilColor.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AnvilColor.textSecondary)
                }
            }
            .padding(AnvilSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(
                isHovered
                    ? AnvilColor.backgroundElevated
                    : (isPrimary ? AnvilColor.accentBlue.opacity(0.06) : AnvilColor.backgroundTertiary)
            )
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                    .stroke(
                        isPrimary
                            ? (isHovered ? AnvilColor.accentBlue.opacity(0.5) : AnvilColor.accentBlue.opacity(0.25))
                            : (isHovered ? AnvilColor.borderMedium : AnvilColor.borderSubtle),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - RecentProjectRow

private struct RecentProjectRow: View {
    let project: Project
    let isHovered: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AnvilSpacing.md) {
                // Project icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(projectColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Text(project.name.prefix(1).uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(projectColor)
                }

                // Name + path
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    if let path = project.primaryRepoPath {
                        Text(abbreviatedPath(path))
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Last opened
                Text(relativeDate(project.lastOpenedAt))
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                // Arrow on hover
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .background(isHovered ? AnvilColor.backgroundTertiary : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .disabled(isLoading)
    }

    private var projectColor: Color {
        // Deterministic color from project name hash
        let colors: [Color] = [
            AnvilColor.accentBlue,
            AnvilColor.accentPurple,
            AnvilColor.accentTeal,
            AnvilColor.accentGreen,
            AnvilColor.accentAmber
        ]
        let index = abs(project.name.hashValue) % colors.count
        return colors[index]
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func relativeDate(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 7 * 86400 { return "\(Int(diff / 86400))d ago" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - WelcomeTipCard

private struct WelcomeTipCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let tip: String

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AnvilColor.textPrimary)
            }

            Text(tip)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AnvilColor.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AnvilSpacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(AnvilColor.borderSubtle, lineWidth: 1)
        )
    }
}
