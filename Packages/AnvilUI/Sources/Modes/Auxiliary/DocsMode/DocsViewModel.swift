import SwiftUI

// MARK: - Models

struct DocNode: Identifiable {
    let id: String // file path as stable ID
    let name: String
    let isFolder: Bool
    let children: [DocNode]
    let filePath: String?

    init(name: String, isFolder: Bool = false, children: [DocNode] = [], filePath: String? = nil) {
        self.id = filePath ?? UUID().uuidString
        self.name = name
        self.isFolder = isFolder
        self.children = children
        self.filePath = filePath
    }
}

// MARK: - ViewModel

@MainActor
final class DocsViewModel: ObservableObject {
    @Published var docTree: [DocNode] = []
    @Published var selectedDocId: String?
    @Published var expandedFolderIds: Set<String> = []
    @Published var editorContent: String = ""
    @Published var isModified: Bool = false
    @Published var projectPath: String?
    @Published var showNewDocSheet: Bool = false
    @Published var newDocName: String = ""

    private var currentFilePath: String?

    var selectedDoc: DocNode? {
        findNode(id: selectedDocId, in: docTree)
    }

    init() {
        // Start with demo data; will reload from filesystem when project path is set
        loadDemoTree()
    }

    // MARK: - Filesystem

    func loadFromProject(_ path: String) {
        projectPath = path
        let fm = FileManager.default

        // Scan for .md files in the project root
        let rootURL = URL(fileURLWithPath: path)
        docTree = scanDirectory(rootURL, fm: fm, depth: 0, maxDepth: 3)

        // Auto-expand top-level folders
        for node in docTree where node.isFolder {
            expandedFolderIds.insert(node.id)
        }

        // Select first doc if available
        if let firstDoc = findFirstFile(in: docTree) {
            selectDoc(firstDoc.id)
        }
    }

    private func scanDirectory(_ url: URL, fm: FileManager, depth: Int, maxDepth: Int) -> [DocNode] {
        guard depth < maxDepth else { return [] }
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var folders: [DocNode] = []
        var files: [DocNode] = []

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir {
                let children = scanDirectory(item, fm: fm, depth: depth + 1, maxDepth: maxDepth)
                // Only include folders that contain markdown files (directly or nested)
                if containsMarkdown(children) {
                    folders.append(DocNode(
                        name: item.lastPathComponent,
                        isFolder: true,
                        children: children,
                        filePath: item.path
                    ))
                }
            } else if item.pathExtension.lowercased() == "md" {
                files.append(DocNode(
                    name: item.lastPathComponent,
                    filePath: item.path
                ))
            }
        }

        return folders + files
    }

    private func containsMarkdown(_ nodes: [DocNode]) -> Bool {
        for node in nodes {
            if !node.isFolder { return true }
            if containsMarkdown(node.children) { return true }
        }
        return false
    }

    private func findFirstFile(in nodes: [DocNode]) -> DocNode? {
        for node in nodes {
            if !node.isFolder { return node }
            if let found = findFirstFile(in: node.children) { return found }
        }
        return nil
    }

    // MARK: - Actions

    func selectDoc(_ id: String) {
        // Save current before switching
        saveCurrentIfModified()

        selectedDocId = id
        if let doc = findNode(id: id, in: docTree), let path = doc.filePath {
            currentFilePath = path
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                editorContent = content
            } else {
                editorContent = ""
            }
            isModified = false
        } else if let doc = findNode(id: id, in: docTree), let content = doc.filePath {
            // Fallback for demo tree nodes without real files
            editorContent = content
            currentFilePath = nil
            isModified = false
        }
    }

    func toggleFolder(_ id: String) {
        if expandedFolderIds.contains(id) {
            expandedFolderIds.remove(id)
        } else {
            expandedFolderIds.insert(id)
        }
    }

    func saveCurrentDocument() {
        guard let path = currentFilePath else { return }
        do {
            try editorContent.write(toFile: path, atomically: true, encoding: .utf8)
            isModified = false
        } catch {
            // Save failed silently for now
        }
    }

    func createNewDocument() {
        guard !newDocName.isEmpty else { return }
        let name = newDocName.hasSuffix(".md") ? newDocName : "\(newDocName).md"

        if let projectPath {
            let filePath = (projectPath as NSString).appendingPathComponent(name)
            let template = "# \(newDocName.replacingOccurrences(of: ".md", with: ""))\n\n"
            FileManager.default.createFile(atPath: filePath, contents: template.data(using: .utf8))

            // Reload tree and select the new file
            loadFromProject(projectPath)
            if let node = findNodeByPath(filePath, in: docTree) {
                selectDoc(node.id)
            }
        } else {
            // Demo mode: add to tree
            let newNode = DocNode(name: name, filePath: nil)
            docTree.append(newNode)
            selectedDocId = newNode.id
            editorContent = "# \(newDocName.replacingOccurrences(of: ".md", with: ""))\n\n"
            currentFilePath = nil
            isModified = false
        }

        newDocName = ""
        showNewDocSheet = false
    }

    func markModified() {
        isModified = true
    }

    // MARK: - Private

    private func saveCurrentIfModified() {
        guard isModified else { return }
        saveCurrentDocument()
    }

    private func findNode(id: String?, in nodes: [DocNode]) -> DocNode? {
        guard let id else { return nil }
        for node in nodes {
            if node.id == id { return node }
            if let found = findNode(id: id, in: node.children) { return found }
        }
        return nil
    }

    private func findNodeByPath(_ path: String, in nodes: [DocNode]) -> DocNode? {
        for node in nodes {
            if node.filePath == path { return node }
            if let found = findNodeByPath(path, in: node.children) { return found }
        }
        return nil
    }

    // MARK: - Demo Data

    private func loadDemoTree() {
        let architectureContent = """
        # Architecture

        ## Overview

        Anvil uses a modular Swift Package structure with three core packages:

        - **AnvilDomain** - Domain primitives, protocols, and value types
        - **AnvilEngine** - Business logic, services, and orchestration
        - **AnvilUI** - SwiftUI views, design system, and mode implementations

        ## Design Principles

        1. **Separation of concerns** - Each package has a clear responsibility
        2. **Protocol-driven** - Dependencies are expressed as protocols
        3. **Unidirectional data flow** - State flows down, actions flow up
        4. **Composability** - Modes are self-contained and independently testable

        ## Space System

        Each space represents a distinct workspace context:

        ```
        Spaces/
        ├── Plan
        ├── Build
        ├── Review
        ├── Operate
        └── Library
        ```

        Spaces are routed through `ContentArea.swift` based on the active `AnvilSpace` enum case.
        """

        let gettingStartedContent = """
        # Getting Started

        ## Prerequisites

        - macOS 15.0 or later
        - Xcode 16.0 or later
        - Swift 6.0

        ## Setup

        ```bash
        git clone https://github.com/example/anvil.git
        cd anvil
        ./scripts/dev
        ```

        ## Running

        1. Open `Anvil.xcodeproj` in Xcode
        2. Select the Anvil scheme
        3. Press Cmd+R to build and run

        ## Project Structure

        The project is organized as a macOS app project backed by multiple local Swift packages.
        See the Architecture doc for details on each package.
        """

        let apiReferenceContent = """
        # API Reference

        ## AppState

        The central state object shared across the app via `@EnvironmentObject`.

        ```swift
        public class AppState: ObservableObject {
            @Published public var currentSpace: AnvilSpace
            @Published public var isSidebarVisible: Bool
        }
        ```

        ## AnvilSpace

        An enum representing available workspace spaces.

        ## Design System

        ### Colors
        Use `AnvilColor` for all color values. Never use raw `Color` literals.

        ### Typography
        Use `AnvilFont` for all font values. Available presets: `.body`, `.label`, `.code`, `.heading`.

        ### Spacing
        Use `AnvilSpacing` tokens for all padding and spacing values.
        """

        let changelogContent = """
        # Changelog

        ## v0.4.0 (2026-03-27)

        - Added DatabaseMode with schema explorer and query console
        - Added TerminalMode with tabbed terminal sessions
        - Added DocsMode with document browser and editor
        - Added MessagingMode with channels and chat

        ## v0.3.0 (2026-03-20)

        - Added EditorMode with syntax highlighting
        - Added Symbol Outline panel
        - Improved design system with new color tokens

        ## v0.2.0 (2026-03-10)

        - Core spaces: Plan, Build, Review, Operate
        - Command palette
        - Space switcher sidebar
        """

        docTree = [
            DocNode(name: "Guide", isFolder: true, children: [
                DocNode(name: "Getting Started.md", filePath: gettingStartedContent),
                DocNode(name: "Architecture.md", filePath: architectureContent),
            ]),
            DocNode(name: "Reference", isFolder: true, children: [
                DocNode(name: "API Reference.md", filePath: apiReferenceContent),
            ]),
            DocNode(name: "Changelog.md", filePath: changelogContent),
        ]

        // Expand top-level folders
        for node in docTree where node.isFolder {
            expandedFolderIds.insert(node.id)
        }

        // Select first document
        if let firstDoc = docTree.first?.children.first {
            selectedDocId = firstDoc.id
            editorContent = firstDoc.filePath ?? ""
            currentFilePath = nil
        }
    }
}
