import AppKit
import SwiftUI
import AnvilDomain
import AnvilTerminal
import UniformTypeIdentifiers

struct BuildSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            SidebarTabBar(
                sections: Array(AppState.BuildSection.allCases),
                active: appState.buildActiveSection,
                icon: { $0.icon },
                label: { $0.rawValue },
                onSelect: { appState.buildActiveSection = $0 }
            )

            Divider()

            switch appState.buildActiveSection {
            case .sessions:
                AgentSidebar(viewModel: appState.agentViewModel)
            case .files:
                BuildFilesSidebar(viewModel: appState.editorViewModel)
            case .terminal:
                TerminalSidebarSection(viewModel: appState.terminalViewModel)
            case .data:
                DatabaseSidebarView(viewModel: appState.databaseViewModel)
            case .tests:
                TestSuiteList(viewModel: appState.testingViewModel)
            }
        }
    }
}

// MARK: - Files Sidebar

struct BuildFilesSidebar: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                    projectSection
                    openTabsSection
                    recentFilesSection
                }
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.md)
            }
        }
    }

    private var header: some View {
        HStack(spacing: AnvilSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Files")
                    .font(.headline)

                Text("Open tabs and recent files")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            Button {
                appState.openFilePalette()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Find File")
            .accessibilityLabel("Find File")
            .accessibilityAddTraits(.isButton)

            Button {
                appState.openSymbolPalette()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Search Symbols")
            .accessibilityLabel("Search Symbols")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            AnvilSidebarSectionHeader(
                title: "Project",
                icon: "folder",
                count: appState.currentProjectPath == nil ? nil : 1
            )

            if let projectPath = appState.currentProjectPath {
                let projectURL = URL(fileURLWithPath: projectPath)
                AnvilSidebarInfoRow(
                    title: projectURL.lastPathComponent,
                    icon: "folder.fill",
                    detail: projectPath
                )

                HStack(spacing: AnvilSpacing.xs) {
                    Button("Find File") {
                        appState.openFilePalette()
                    }
                    .buttonStyle(.borderless)

                    Button("Search Symbols") {
                        appState.openSymbolPalette()
                    }
                    .buttonStyle(.borderless)
                }
                .font(AnvilFont.label)
            } else {
                AnvilSidebarInfoRow(
                    title: "No Project Open",
                    icon: "folder",
                    detail: "Open a project to browse and edit files."
                )
            }
        }
    }

    private var openTabsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            AnvilSidebarSectionHeader(title: "Open Tabs", icon: "doc.on.doc", count: viewModel.openFiles.count)

            if viewModel.openFiles.isEmpty {
                emptyState(text: "No files are open.")
            } else {
                VStack(spacing: 2) {
                    ForEach(viewModel.openFiles) { file in
                        Button {
                            viewModel.selectFile(file.id)
                        } label: {
                            AnvilListItem(
                                icon: fileIcon(for: file.name),
                                title: file.name,
                                subtitle: file.relativePath,
                                tag: viewModel.isFileDirty(file.id) ? "Dirty" : (viewModel.isFileReadOnly(file.id) ? "Read-only" : nil),
                                tagColor: viewModel.isFileDirty(file.id) ? AnvilColor.accentAmber : AnvilColor.textTertiary,
                                isSelected: viewModel.selectedFileId == file.id,
                                isCompact: false
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open file \(file.name)")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
    }

    private var recentFilesSection: some View {
        let recentPaths = recentEditablePaths

        return VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            AnvilSidebarSectionHeader(title: "Recent", icon: "clock", count: recentPaths.count)

            if recentPaths.isEmpty {
                emptyState(text: "Files you edit will appear here.")
            } else {
                VStack(spacing: 2) {
                    ForEach(recentPaths.prefix(8), id: \.self) { path in
                        Button {
                            viewModel.openFileFromTree(path)
                        } label: {
                            AnvilListItem(
                                icon: fileIcon(for: path),
                                title: URL(fileURLWithPath: path).lastPathComponent,
                                subtitle: relativePath(for: path),
                                tag: "Recent",
                                tagColor: AnvilColor.accentBlue,
                                isCompact: false
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Recent file \(path)")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
    }

    private var recentEditablePaths: [String] {
        let openPaths = Set(viewModel.openFiles.map(\.path))
        return viewModel.recentlyEditedPaths.filter { !openPaths.contains($0) }
    }

    private func relativePath(for path: String) -> String {
        guard let projectPath = appState.currentProjectPath, path.hasPrefix(projectPath) else {
            return path
        }

        var relative = String(path.dropFirst(projectPath.count))
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        return relative.isEmpty ? path : relative
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(AnvilFont.label)
            .foregroundStyle(AnvilColor.textTertiary)
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
    }

    private func fileIcon(for path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "md": return "doc.richtext"
        case "json": return "curlybraces"
        case "yml", "yaml": return "doc.text"
        default: return "doc"
        }
    }
}

// MARK: - Database Sidebar

struct DatabaseSidebarView: View {
    @ObservedObject var viewModel: DatabaseViewModel
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        Group {
            if viewModel.isConnected {
                SchemaExplorer(viewModel: viewModel) {
                    exportResults()
                }
            } else {
                disconnectedView
            }
        }
        .onAppear {
            viewModel.configure(service: container.databaseService)
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Spacer()

            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)

            Text("No connections")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textSecondary)

            Text("Connect to a database to browse schemas and run queries.")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AnvilSpacing.md)

            if !viewModel.availableProviders.isEmpty {
                VStack(spacing: AnvilSpacing.sm) {
                    Picker("Provider", selection: $viewModel.selectedProviderId) {
                        ForEach(viewModel.availableProviders) { provider in
                            Text(provider.title).tag(Optional(provider.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if viewModel.selectedProvider?.connectionStyle == .file {
                        HStack(spacing: 8) {
                            TextField("Database file path", text: $viewModel.connectionPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)

                            Button {
                                openFilePanel()
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                            .help("Browse for database file")
                        }
                    }

                    Button {
                        Task { await viewModel.connectCurrentProvider() }
                    } label: {
                        Label("Connect", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(
                        viewModel.selectedProvider?.connectionStyle == .file
                        && viewModel.connectionPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(.horizontal, AnvilSpacing.md)
            } else {
                Text("No database providers available.")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AnvilFont.label)
                    .foregroundStyle(.red)
                    .padding(.horizontal, AnvilSpacing.md)
            }

            Spacer()
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .data,
            UTType(filenameExtension: "sqlite"),
            UTType(filenameExtension: "sqlite3"),
            UTType(filenameExtension: "db"),
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open Database"
        panel.message = "Choose a database file."

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.connectionPath = url.path
        }
    }

    private func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = viewModel.connectionTitle
            .replacingOccurrences(of: " ", with: "-")
            .lowercased() + "-results.csv"
        panel.title = "Export Query Results"
        panel.message = "Save the current result set as CSV."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try viewModel.exportResults(to: url)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
