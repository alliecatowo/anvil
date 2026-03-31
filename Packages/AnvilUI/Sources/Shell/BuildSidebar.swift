import AppKit
import SwiftUI
import AnvilDomain
import AnvilTerminal
import UniformTypeIdentifiers

struct BuildSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.buildActiveSource {
            case .sessions:
                AgentSidebar(viewModel: appState.agentViewModel)
            case .files:
                BuildFilesSidebar(viewModel: appState.editorViewModel)
            case .data:
                DatabaseSidebarView(viewModel: appState.databaseViewModel)
            case .tests:
                TestSuiteList(viewModel: appState.testingViewModel)
            case .problems:
                // Future: problems/issues list
                AnvilSidebarEmptyState(icon: "checkmark.circle", title: "No problems", message: "Issues will appear here.")
            case .output:
                // Future: build output list
                AnvilSidebarEmptyState(icon: "text.alignleft", title: "No output", message: "Build output will appear here.")
            }
        }
    }
}

// MARK: - Files Sidebar

struct BuildFilesSidebar: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var deps: DependencyContainer
    @ObservedObject var viewModel: EditorViewModel

    @State private var isProjectTreeExpanded = true
    @State private var isOpenTabsExpanded = true
    @State private var isRecentExpanded = true

    @State private var renamingNodeId: UUID?
    @State private var renameText: String = ""
    @State private var newFileName: String = ""
    @State private var creatingFileInFolder: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            List {
                // -- Project File Tree --
                Section(isExpanded: $isProjectTreeExpanded) {
                    if viewModel.fileTree.isEmpty {
                        if appState.currentProjectPath == nil {
                            Text("No project open.")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textTertiary)
                        } else {
                            Text("Loading...")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textTertiary)
                        }
                    } else {
                        ForEach(flattenedTree) { entry in
                            fileTreeRow(entry: entry)
                                .listRowInsets(EdgeInsets(
                                    top: 0,
                                    leading: CGFloat(entry.depth) * 16 + 4,
                                    bottom: 0,
                                    trailing: 4
                                ))
                        }
                    }
                } header: {
                    sectionHeader(title: "Project", icon: "folder.fill")
                }

                // -- Open Tabs --
                Section(isExpanded: $isOpenTabsExpanded) {
                    if viewModel.openFiles.isEmpty {
                        Text("No files are open.")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    } else {
                        ForEach(viewModel.openFiles) { file in
                            openTabRow(file: file)
                        }
                    }
                } header: {
                    sectionHeader(
                        title: "Open Tabs",
                        icon: "doc.on.doc",
                        count: viewModel.openFiles.isEmpty ? nil : viewModel.openFiles.count
                    )
                }

                // -- Recent --
                Section(isExpanded: $isRecentExpanded) {
                    let recentPaths = recentEditablePaths
                    if recentPaths.isEmpty {
                        Text("Files you edit will appear here.")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    } else {
                        ForEach(recentPaths.prefix(8), id: \.self) { path in
                            recentFileRow(path: path)
                        }
                    }
                } header: {
                    sectionHeader(
                        title: "Recent",
                        icon: "clock",
                        count: recentEditablePaths.isEmpty ? nil : recentEditablePaths.count
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .alert("Rename", isPresented: Binding(
            get: { renamingNodeId != nil },
            set: { if !$0 { renamingNodeId = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let nodeId = renamingNodeId,
                   let entry = flattenedTree.first(where: { $0.id == nodeId }),
                   let path = entry.node.filePath,
                   !renameText.isEmpty {
                    viewModel.renameFileOrFolder(atPath: path, to: renameText, using: deps.fileSystemService)
                }
                renamingNodeId = nil
            }
            Button("Cancel", role: .cancel) {
                renamingNodeId = nil
            }
        }
        .alert("New File", isPresented: Binding(
            get: { creatingFileInFolder != nil },
            set: { if !$0 { creatingFileInFolder = nil } }
        )) {
            TextField("Filename", text: $newFileName)
            Button("Create") {
                if let folderId = creatingFileInFolder,
                   let entry = flattenedTree.first(where: { $0.id == folderId }),
                   let dirPath = entry.node.filePath,
                   !newFileName.isEmpty {
                    viewModel.createNewFile(inDirectory: dirPath, name: newFileName, using: deps.fileSystemService)
                }
                creatingFileInFolder = nil
            }
            Button("Cancel", role: .cancel) {
                creatingFileInFolder = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AnvilSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Files")
                    .font(.headline)

                Text("Project tree, tabs, and recents")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            Button {
                viewModel.expandedFolders.removeAll()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Collapse All Folders")
            .accessibilityLabel("Collapse All Folders")
            .accessibilityAddTraits(.isButton)

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
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, count: Int? = nil) -> some View {
        HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if let count {
                Text("\(count)")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    // MARK: - Flattened File Tree

    private struct FlatTreeEntry: Identifiable {
        let id: UUID
        let node: FileTreeNode
        let depth: Int
    }

    private var flattenedTree: [FlatTreeEntry] {
        var result: [FlatTreeEntry] = []
        func walk(_ nodes: [FileTreeNode], depth: Int) {
            for node in nodes {
                result.append(FlatTreeEntry(id: node.id, node: node, depth: depth))
                if node.isFolder && viewModel.expandedFolders.contains(node.id) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(viewModel.fileTree, depth: 0)
        return result
    }

    // MARK: - File Tree Row

    private func fileTreeRow(entry: FlatTreeEntry) -> some View {
        let node = entry.node
        let isExpanded = viewModel.expandedFolders.contains(node.id)
        let isSelected = node.filePath != nil
            && viewModel.selectedFile?.path == node.filePath

        return Button {
            if node.isFolder {
                viewModel.toggleFolder(node.id)
            } else if let path = node.filePath {
                viewModel.openFileFromTree(path)
            }
        } label: {
            HStack(spacing: AnvilSpacing.xxs) {
                if node.isFolder {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                        .accessibilityHidden(true)
                } else {
                    Spacer().frame(width: 12)
                }

                Image(systemName: node.isFolder ? (isExpanded ? "folder.fill" : "folder") : fileIcon(for: node.name))
                    .font(.system(size: 12))
                    .foregroundStyle(node.isFolder ? AnvilColor.accentAmber : fileColor(for: node.name))
                    .frame(width: 16)
                    .accessibilityHidden(true)

                Text(node.name)
                    .font(AnvilFont.code)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer()

                if !node.isFolder, let path = node.filePath {
                    let counts = viewModel.diagnosticCount(forPath: path)
                    if counts.errors > 0 {
                        Text("\(counts.errors)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentRed)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(counts.errors) errors")
                    }
                    if counts.warnings > 0 {
                        Text("\(counts.warnings)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentAmber)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(counts.warnings) warnings")
                    }
                }
            }
            .frame(height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(node.isFolder ? "Folder: \(node.name)" : "\(node.name), \(fileTypeDescription(for: node.name))")
        .accessibilityAddTraits(.isButton)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .contextMenu {
            fileContextMenu(for: node)
        }
    }

    // MARK: - Open Tab Row

    private func openTabRow(file: EditorFile) -> some View {
        AnvilSidebarRowButton(
            title: file.name,
            icon: fileIcon(for: file.name),
            subtitle: file.relativePath,
            isActive: viewModel.selectedFileId == file.id
        ) {
            viewModel.selectFile(file.id)
        } trailing: {
            if viewModel.isFileDirty(file.id) {
                AnvilBadge(text: "Dirty", color: AnvilColor.accentAmber)
            } else if viewModel.isFileReadOnly(file.id) {
                AnvilBadge(text: "Read-only", color: AnvilColor.textTertiary)
            }
        }
        .accessibilityLabel("Open file \(file.name)")
    }

    // MARK: - Recent File Row

    private func recentFileRow(path: String) -> some View {
        AnvilSidebarRowButton(
            title: URL(fileURLWithPath: path).lastPathComponent,
            icon: fileIcon(for: path),
            subtitle: relativePath(for: path)
        ) {
            viewModel.openFileFromTree(path)
        } trailing: {
            AnvilBadge(text: "Recent", color: AnvilColor.accentBlue)
        }
        .accessibilityLabel("Recent file \(path)")
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func fileContextMenu(for node: FileTreeNode) -> some View {
        if node.isFolder {
            Button("New File...") {
                creatingFileInFolder = node.id
                newFileName = "untitled.swift"
                if !viewModel.expandedFolders.contains(node.id) {
                    viewModel.toggleFolder(node.id)
                }
            }
        }

        if let path = node.filePath {
            if !node.isFolder {
                Button("Open") {
                    viewModel.openFileFromTree(path)
                }
            }

            Divider()

            Button("Rename...") {
                renamingNodeId = node.id
                renameText = node.name
            }

            Button("Delete", role: .destructive) {
                viewModel.deleteFileOrFolder(atPath: path, using: deps.fileSystemService)
            }

            Divider()

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            }

            Button("Copy Relative Path") {
                let relPath: String
                if let root = deps.currentProjectPath, path.hasPrefix(root) {
                    var rel = String(path.dropFirst(root.count))
                    if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
                    relPath = rel
                } else {
                    relPath = path
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(relPath, forType: .string)
            }
        }
    }

    // MARK: - Helpers

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

    private func fileTypeDescription(for name: String) -> String {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return "Swift file"
        case "md": return "Markdown file"
        case "json": return "JSON file"
        case "yml", "yaml": return "YAML file"
        case "txt": return "Text file"
        default: return "file"
        }
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

    private func fileColor(for name: String) -> Color {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return AnvilColor.accentRed
        case "md": return AnvilColor.accentBlue
        case "json": return AnvilColor.accentAmber
        case "yml", "yaml": return AnvilColor.accentPurple
        default: return Color.secondary
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
