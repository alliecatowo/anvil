import SwiftUI

// MARK: - Models

struct EditorFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let content: String
    let language: String

    var pathComponents: [String] {
        path.components(separatedBy: "/").filter { !$0.isEmpty }
    }
}

struct FileTreeNode: Identifiable {
    let id = UUID()
    let name: String
    let isFolder: Bool
    let children: [FileTreeNode]
    let filePath: String?

    init(name: String, isFolder: Bool = false, children: [FileTreeNode] = [], filePath: String? = nil) {
        self.name = name
        self.isFolder = isFolder
        self.children = children
        self.filePath = filePath
    }
}

struct EditorSymbol: Identifiable {
    let id = UUID()
    let name: String
    let kind: SymbolKind
    let line: Int
}

enum SymbolKind: String {
    case classDecl = "class"
    case structDecl = "struct"
    case function = "func"
    case property = "property"
    case enumDecl = "enum"
    case protocolDecl = "protocol"

    var icon: String {
        switch self {
        case .classDecl: "c.square"
        case .structDecl: "s.square"
        case .function: "f.square"
        case .property: "p.square"
        case .enumDecl: "e.square"
        case .protocolDecl: "p.square.fill"
        }
    }

    var color: Color {
        switch self {
        case .classDecl: AnvilColor.accentPurple
        case .structDecl: AnvilColor.accentGreen
        case .function: AnvilColor.accentBlue
        case .property: AnvilColor.accentAmber
        case .enumDecl: AnvilColor.accentTeal
        case .protocolDecl: AnvilColor.accentRed
        }
    }
}

// MARK: - ViewModel

@MainActor
class EditorViewModel: ObservableObject {
    @Published var openFiles: [EditorFile] = []
    @Published var selectedFileId: UUID?
    @Published var cursorLine: Int = 12
    @Published var cursorColumn: Int = 1
    @Published var isSymbolOutlineVisible: Bool = true
    @Published var expandedFolders: Set<UUID> = []

    var selectedFile: EditorFile? {
        openFiles.first { $0.id == selectedFileId }
    }

    var symbols: [EditorSymbol] {
        guard let file = selectedFile else { return [] }
        return extractSymbols(from: file.content)
    }

    @Published var fileTree: [FileTreeNode] = []

    /// The project root path, if loaded from a real directory.
    private var projectPath: String?

    init() {
        // Default empty state — call loadFileTree(from:) to populate from a real directory.
    }

    // MARK: - Real File System Loading

    /// Build the file tree from a real project directory using FileSystemService.
    func loadFileTree(from path: String, using service: FileSystemService) {
        projectPath = path
        let nodes = service.readTree(at: path, maxDepth: 3)
        fileTree = nodes.map { convertToTreeNode($0) }

        // Expand top-level folders by default
        for node in fileTree where node.isFolder {
            expandedFolders.insert(node.id)
        }

        // Auto-open the first Swift file we find
        if let firstSwift = findFirstFile(in: fileTree, matching: { $0.hasSuffix(".swift") }),
           let path = firstSwift.filePath {
            openFileFromTree(path)
        }
    }

    /// Open a file from the tree, reading its content from disk.
    func openFileFromTree(_ path: String) {
        if let existing = openFiles.first(where: { $0.path == path }) {
            selectedFileId = existing.id
            return
        }

        // Read content from disk
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let language = Self.languageForExtension(ext)

        let content: String
        if let data = FileManager.default.contents(atPath: path),
           let text = String(data: data, encoding: .utf8) {
            content = text
        } else {
            content = "// Unable to read file"
        }

        let file = EditorFile(name: name, path: path, content: content, language: language)
        openFiles.append(file)
        selectedFileId = file.id
        cursorLine = 1
        cursorColumn = 1
    }

    // MARK: - Helpers

    private func convertToTreeNode(_ node: FileSystemService.FileNode) -> FileTreeNode {
        if node.isDirectory {
            let children = (node.children ?? []).map { convertToTreeNode($0) }
            return FileTreeNode(name: node.name, isFolder: true, children: children, filePath: nil)
        } else {
            return FileTreeNode(name: node.name, isFolder: false, children: [], filePath: node.path)
        }
    }

    private func findFirstFile(in nodes: [FileTreeNode], matching predicate: (String) -> Bool) -> FileTreeNode? {
        for node in nodes {
            if !node.isFolder, let fp = node.filePath, predicate(fp) {
                return node
            }
            if node.isFolder {
                if let found = findFirstFile(in: node.children, matching: predicate) {
                    return found
                }
            }
        }
        return nil
    }

    private static func languageForExtension(_ ext: String) -> String {
        switch ext {
        case "swift": return "swift"
        case "ts", "tsx": return "typescript"
        case "js", "jsx": return "javascript"
        case "py": return "python"
        case "rs": return "rust"
        case "go": return "go"
        case "json": return "json"
        case "yml", "yaml": return "yaml"
        case "md", "markdown": return "markdown"
        case "html": return "html"
        case "css": return "css"
        case "sql": return "sql"
        case "sh", "bash", "zsh": return "shell"
        default: return "text"
        }
    }

    // MARK: - Actions

    func selectFile(_ id: UUID) {
        selectedFileId = id
        cursorLine = 1
        cursorColumn = 1
    }

    func closeFile(_ id: UUID) {
        openFiles.removeAll { $0.id == id }
        if selectedFileId == id {
            selectedFileId = openFiles.first?.id
        }
    }

    func toggleFolder(_ id: UUID) {
        if expandedFolders.contains(id) {
            expandedFolders.remove(id)
        } else {
            expandedFolders.insert(id)
        }
    }

    func toggleSymbolOutline() {
        withAnimation(AnvilAnimation.standard) {
            isSymbolOutlineVisible.toggle()
        }
    }

    func navigateToSymbol(_ symbol: EditorSymbol) {
        cursorLine = symbol.line
    }

    // MARK: - Symbol Extraction

    private func extractSymbols(from content: String) -> [EditorSymbol] {
        var symbols: [EditorSymbol] = []
        let lines = content.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if trimmed.contains("class ") && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") {
                let name = extractName(from: trimmed, after: "class ")
                if !name.isEmpty {
                    symbols.append(EditorSymbol(name: name, kind: .classDecl, line: lineNumber))
                }
            } else if trimmed.contains("struct ") && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") {
                let name = extractName(from: trimmed, after: "struct ")
                if !name.isEmpty {
                    symbols.append(EditorSymbol(name: name, kind: .structDecl, line: lineNumber))
                }
            } else if trimmed.contains("protocol ") && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") {
                let name = extractName(from: trimmed, after: "protocol ")
                if !name.isEmpty {
                    symbols.append(EditorSymbol(name: name, kind: .protocolDecl, line: lineNumber))
                }
            } else if trimmed.contains("enum ") && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") {
                let name = extractName(from: trimmed, after: "enum ")
                if !name.isEmpty {
                    symbols.append(EditorSymbol(name: name, kind: .enumDecl, line: lineNumber))
                }
            } else if trimmed.hasPrefix("func ") || trimmed.contains(" func ") {
                let name = extractFuncName(from: trimmed)
                if !name.isEmpty {
                    symbols.append(EditorSymbol(name: name, kind: .function, line: lineNumber))
                }
            }
        }

        return symbols
    }

    private func extractName(from line: String, after keyword: String) -> String {
        guard let range = line.range(of: keyword) else { return "" }
        let rest = String(line[range.upperBound...])
        let name = rest.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })
        return String(name)
    }

    private func extractFuncName(from line: String) -> String {
        guard let range = line.range(of: "func ") else { return "" }
        let rest = String(line[range.upperBound...])
        let name = rest.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })
        return String(name)
    }
}
