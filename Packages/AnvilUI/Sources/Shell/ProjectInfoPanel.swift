import SwiftUI
import AnvilApplication

/// Sheet for viewing and editing project metadata: name, description, repos.
public struct ProjectInfoPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer
    @State private var editName: String = ""
    @State private var editDescription: String = ""
    @State private var editRepoPaths: [String] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Project Info")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Spacer()
                Button {
                    appState.toggleProjectInfo()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(AnvilSpacing.lg)

            Divider()

            if appState.currentProject != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: AnvilSpacing.xl) {
                        // Name
                        fieldSection("Name") {
                            TextField("Project name", text: $editName)
                                .textFieldStyle(.roundedBorder)
                                .font(AnvilFont.body)
                        }

                        // Description
                        fieldSection("Description") {
                            TextField("What is this project about?", text: $editDescription, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(AnvilFont.body)
                                .lineLimit(3...6)
                        }

                        // Repos
                        fieldSection("Repositories") {
                            VStack(spacing: AnvilSpacing.sm) {
                                ForEach(Array(editRepoPaths.enumerated()), id: \.offset) { index, path in
                                    HStack(spacing: AnvilSpacing.sm) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AnvilColor.textTertiary)

                                        Text(abbreviatePath(path))
                                            .font(AnvilFont.code)
                                            .foregroundStyle(AnvilColor.textSecondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        Spacer()

                                        if editRepoPaths.count > 1 {
                                            Button {
                                                editRepoPaths.remove(at: index)
                                            } label: {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(AnvilColor.accentRed)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, AnvilSpacing.sm)
                                    .padding(.vertical, AnvilSpacing.xs)
                                }

                                Button {
                                    addRepo()
                                } label: {
                                    HStack(spacing: AnvilSpacing.xs) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 12))
                                        Text("Add Repository")
                                            .font(AnvilFont.label)
                                    }
                                    .foregroundStyle(AnvilColor.accentPurple)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Metadata
                        if let project = appState.currentProject {
                            fieldSection("Details") {
                                VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                                    metadataRow("Created", value: formatDate(project.createdAt))
                                    metadataRow("Last Opened", value: formatDate(project.lastOpenedAt))
                                    metadataRow("ID", value: String(project.id.prefix(8)))
                                }
                            }
                        }
                    }
                    .padding(AnvilSpacing.lg)
                }

                Divider()

                // Footer buttons
                HStack {
                    Button("Delete Project") {
                        deleteProject()
                    }
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.accentRed)
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Save") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(AnvilSpacing.lg)
            } else {
                Spacer()
                Text("No project selected")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                Spacer()
            }
        }
        .background(.background)
        .onAppear {
            loadFromProject()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func fieldSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
            Text(title)
                .font(.headline)

            content()
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
        }
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func loadFromProject() {
        guard let project = appState.currentProject else { return }
        editName = project.name
        editDescription = project.description
        editRepoPaths = project.repoPaths
    }

    private func saveChanges() {
        guard var project = appState.currentProject else { return }
        project.name = editName
        project.description = editDescription
        project.repoPaths = editRepoPaths
        Task {
            await container.updateProject(project)
            appState.currentProject = project
        }
        appState.toggleProjectInfo()
    }

    private func addRepo() {
        let panel = NSOpenPanel()
        panel.title = "Add Repository"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "Choose one or more repository directories"
        if panel.runModal() == .OK {
            for url in panel.urls {
                let path = url.path
                if !editRepoPaths.contains(path) {
                    editRepoPaths.append(path)
                }
            }
        }
    }

    private func deleteProject() {
        guard let project = appState.currentProject else { return }
        Task {
            await container.removeProject(project.id)
            appState.currentProject = nil
            appState.currentProjectPath = nil
        }
        appState.toggleProjectInfo()
    }
}
