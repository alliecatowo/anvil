import SwiftUI
import AnvilApplication

/// Quick-switch overlay for projects, similar to the command palette.
/// Triggered by Cmd+Shift+O.
public struct ProjectSwitcher: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer
    @State private var query = ""
    @State private var projects: [Project] = []
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    public init() {}

    private var filteredProjects: [Project] {
        if query.isEmpty { return projects }
        let lowered = query.lowercased()
        return projects.filter {
            $0.name.lowercased().contains(lowered)
                || $0.description.lowercased().contains(lowered)
                || $0.repoPaths.contains(where: { $0.lowercased().contains(lowered) })
        }
    }

    public var body: some View {
        ZStack {
            // Backdrop — clear so sidebar remains clickable
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    appState.toggleProjectSwitcher()
                }

            // Switcher panel
            VStack(spacing: 0) {
                // Search
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "folder.badge.magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .accessibilityHidden(true)

                    TextField("Switch project...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.commandPaletteInput)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .focused($isSearchFocused)
                }
                .padding(AnvilSpacing.md)

                Divider()

                // Project list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if filteredProjects.isEmpty && !query.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No matching projects")
                                        .font(AnvilFont.body)
                                        .foregroundStyle(AnvilColor.textTertiary)
                                    Spacer()
                                }
                                .padding(AnvilSpacing.xl)
                            }

                            ForEach(Array(filteredProjects.enumerated()), id: \.element.id) { index, project in
                                ProjectRow(
                                    project: project,
                                    isSelected: index == selectedIndex,
                                    isCurrent: appState.currentProject?.id == project.id
                                )
                                .id(project.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectProject(project)
                                }
                            }

                            // "Open New" button at bottom
                            Divider()

                            Button {
                                openNewProject()
                            } label: {
                                HStack(spacing: AnvilSpacing.sm) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AnvilColor.accentPurple)
                                    Text("Open New Project...")
                                        .font(AnvilFont.body)
                                        .foregroundStyle(AnvilColor.accentPurple)
                                    Spacer()
                                    Text("\u{2318}O")
                                        .font(AnvilFont.label)
                                        .foregroundStyle(AnvilColor.textTertiary)
                                }
                                .padding(.horizontal, AnvilSpacing.md)
                                .padding(.vertical, AnvilSpacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: selectedIndex) { _, newIndex in
                        guard !filteredProjects.isEmpty,
                              newIndex >= 0,
                              newIndex < filteredProjects.count else { return }
                        withAnimation {
                            proxy.scrollTo(filteredProjects[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: AnvilSpacing.commandPaletteWidth)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(.top, 100)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            isSearchFocused = true
            Task {
                projects = await container.projectManager.allProjects()
            }
        }
        .onKeyPress(.upArrow) {
            moveSelection(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(1)
            return .handled
        }
        .onKeyPress(.return) {
            confirmSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            appState.toggleProjectSwitcher()
            return .handled
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }

    // MARK: - Actions

    private func moveSelection(_ delta: Int) {
        let count = filteredProjects.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func confirmSelection() {
        guard !filteredProjects.isEmpty,
              selectedIndex >= 0,
              selectedIndex < filteredProjects.count else { return }
        selectProject(filteredProjects[selectedIndex])
    }

    private func selectProject(_ project: Project) {
        Task {
            await container.switchToProject(project.id)
            if let adapter = container.getOrCreateGitAdapter() {
                await appState.loadGitStatus(from: adapter)
            }
            appState.currentProject = project
        }
        appState.toggleProjectSwitcher()
    }

    private func openNewProject() {
        appState.toggleProjectSwitcher()
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await container.openProject(at: url.path)
                let project = await container.projectManager.currentProject()
                appState.currentProject = project
                appState.currentProjectPath = url.path
                if let adapter = container.getOrCreateGitAdapter() {
                    await appState.loadGitStatus(from: adapter)
                }
            }
        }
    }
}

// MARK: - ProjectRow

struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AnvilSpacing.xs) {
                    Text(project.name)
                        .font(AnvilFont.body)
                        .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)

                    if isCurrent {
                        Text("current")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AnvilColor.accentGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentGreen.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    if project.repoPaths.count > 1 {
                        Text("\(project.repoPaths.count) repos")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AnvilColor.accentPurple)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentPurple.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                if let path = project.primaryRepoPath {
                    Text(abbreviatePath(path))
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text(relativeDate(project.lastOpenedAt))
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(isSelected ? AnvilColor.selectionBackground : .clear)
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
