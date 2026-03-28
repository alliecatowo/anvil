import SwiftUI
import AnvilACP
import AnvilDomain
import AnvilEditor
import AnvilGit

// MARK: - Whitespace Mode

enum WhitespaceMode: String, CaseIterable {
    case none = "None"
    case boundary = "Boundary"  // Only leading/trailing whitespace
    case all = "All"

    var next: WhitespaceMode {
        switch self {
        case .none: .boundary
        case .boundary: .all
        case .all: .none
        }
    }
}

// MARK: - Models

struct EditorFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let content: String
    let language: String
    /// Path relative to the project root, for display in breadcrumbs.
    let relativePath: String

    init(name: String, path: String, content: String, language: String, relativePath: String? = nil) {
        self.name = name
        self.path = path
        self.content = content
        self.language = language
        self.relativePath = relativePath ?? path
    }

    var pathComponents: [String] {
        relativePath.components(separatedBy: "/").filter { !$0.isEmpty }
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

// MARK: - Git Line Change

enum GitLineChange: Sendable {
    case added
    case modified
    case deleted  // Shown as a marker on the line *after* the deletion
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

// MARK: - Find Match

struct FindMatch: Identifiable, Equatable {
    let id = UUID()
    let line: Int          // 1-based line number
    let range: Range<Int>  // character range within the line
    let text: String       // the matched text
}

// MARK: - Inline Edit State

enum InlineEditPhase: Equatable {
    case hidden
    case prompting          // Prompt bar visible, user typing instruction
    case generating         // Agent streaming the edit
    case reviewing          // Diff shown, waiting for accept/reject
}

struct InlineEditDiff {
    let originalLines: [String]     // The lines being replaced
    let proposedLines: [String]     // The agent's proposed replacement
    let startLine: Int              // 1-based line number of first replaced line
}

// MARK: - ViewModel

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var openFiles: [EditorFile] = []
    @Published var selectedFileId: UUID?
    @Published var cursorLine: Int = 12
    @Published var cursorColumn: Int = 1
    @Published var isSymbolOutlineVisible: Bool = true
    @Published var expandedFolders: Set<UUID> = []
    @Published var whitespaceMode: WhitespaceMode = .none
    @Published var readOnlyFileIds: Set<UUID> = []
    @Published var isWordWrapEnabled: Bool = false
    @Published var showIndentGuides: Bool = true
    @Published var tabSize: Int = 4
    @Published var showGitGutter: Bool = true
    /// Maps line number → change type for the currently open file.
    @Published var gitLineChanges: [Int: GitLineChange] = [:]
    @Published var showBracketMatching: Bool = true
    @Published var codeFoldingEnabled: Bool = true
    /// Line numbers (1-based) that are currently collapsed.
    @Published var collapsedLines: Set<Int> = []

    // MARK: Find & Replace (⌘F)
    @Published var isFindBarVisible: Bool = false
    @Published var findText: String = "" { didSet { updateFindMatches() } }
    @Published var replaceText: String = ""
    @Published var findMatchCase: Bool = false { didSet { updateFindMatches() } }
    @Published var findWholeWord: Bool = false { didSet { updateFindMatches() } }
    @Published var findUseRegex: Bool = false { didSet { updateFindMatches() } }
    @Published var findMatches: [FindMatch] = []
    @Published var currentMatchIndex: Int = 0

    // MARK: Ghost Text (AI inline completions)
    @Published var ghostCompletion: String? = nil
    private var ghostDebounceTask: Task<Void, Never>? = nil

    // MARK: Inline Edit (⌘K)
    @Published var inlineEditPhase: InlineEditPhase = .hidden
    @Published var inlineEditSelectedRange: ClosedRange<Int> = 1...1   // 1-based line range
    @Published var inlineEditPrompt: String = ""
    @Published var inlineEditDiff: InlineEditDiff? = nil
    @Published var inlineEditStreamingText: String = ""

    private var inlineEditTask: Task<Void, Never>?

    // MARK: LSP Integration
    public var lspViewModel = LSPViewModel()

    /// Set by EditorMode on appear so inline edits can call ACP
    /// and git gutter can load diff data.
    weak var container: DependencyContainer?

    /// Cached unstaged diff from git, keyed by relative file path.
    private var cachedFileDiffs: [String: FileDiff] = [:]

    var selectedFile: EditorFile? {
        openFiles.first { $0.id == selectedFileId }
    }

    var symbols: [EditorSymbol] {
        guard let file = selectedFile else { return [] }
        return extractSymbols(from: file.content)
    }

    /// The symbol (function/class/struct) containing the cursor position.
    var symbolAtCursor: EditorSymbol? {
        let sorted = symbols.sorted { $0.line < $1.line }
        var best: EditorSymbol?
        for symbol in sorted {
            if symbol.line <= cursorLine {
                best = symbol
            } else {
                break
            }
        }
        return best
    }

    /// Returns sibling file/folder names at a given path depth in the file tree.
    func siblingsAtPathLevel(_ components: [String], level: Int) -> [FileTreeNode] {
        guard level >= 0 else { return [] }
        var nodes = fileTree
        for i in 0..<level {
            guard i < components.count else { return [] }
            if let parent = nodes.first(where: { $0.name == components[i] && $0.isFolder }) {
                nodes = parent.children
            } else {
                return []
            }
        }
        return nodes.sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
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

        // Compute project-relative path for breadcrumbs
        let relPath: String
        if let root = projectPath, path.hasPrefix(root) {
            var rel = String(path.dropFirst(root.count))
            if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
            relPath = rel
        } else {
            relPath = path
        }

        let file = EditorFile(name: name, path: path, content: content, language: language, relativePath: relPath)
        openFiles.append(file)
        selectedFileId = file.id
        cursorLine = 1
        cursorColumn = 1

        // Auto-detect read-only files
        if shouldAutoMarkReadOnly(path) {
            readOnlyFileIds.insert(file.id)
        }

        loadGitGutterForSelectedFile()

        // Notify LSP about the newly opened document
        let fileUri = "file://\(path)"
        Task {
            await lspViewModel.didOpen(uri: fileUri, languageId: language, text: content)
        }
    }

    /// Notify the LSP server of a content change for the given file path.
    func notifyLSPContentChange(path: String, text: String) {
        let fileUri = "file://\(path)"
        Task {
            await lspViewModel.didChange(uri: fileUri, text: text)
        }
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
        loadGitGutterForSelectedFile()
    }

    func closeFile(_ id: UUID) {
        openFiles.removeAll { $0.id == id }
        if selectedFileId == id {
            selectedFileId = openFiles.first?.id
        }
    }

    // MARK: - File Persistence

    /// Write content to a file on disk. Returns true on success.
    @discardableResult
    func saveFile(atPath path: String, content: String) -> Bool {
        let data = content.data(using: .utf8) ?? Data()
        return FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
    }

    /// Save the currently selected file's content to disk.
    func saveCurrentFile() {
        guard let file = selectedFile else { return }
        saveFile(atPath: file.path, content: file.content)
    }

    /// Reload an open file from disk, refreshing its in-memory content.
    /// If the file is not currently open, this is a no-op.
    func reloadFile(atPath path: String) {
        guard let index = openFiles.firstIndex(where: { $0.path == path }) else { return }
        let existing = openFiles[index]
        let url = URL(fileURLWithPath: path)
        let content: String
        if let data = FileManager.default.contents(atPath: path),
           let text = String(data: data, encoding: .utf8) {
            content = text
        } else {
            return // Cannot read — leave in-memory version alone
        }
        let updated = EditorFile(
            name: existing.name,
            path: existing.path,
            content: content,
            language: existing.language,
            relativePath: existing.relativePath
        )
        let wasSelected = selectedFileId == existing.id
        openFiles[index] = updated
        if wasSelected {
            selectedFileId = updated.id
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

    func cycleWhitespace() {
        whitespaceMode = whitespaceMode.next
    }

    func toggleWordWrap() {
        isWordWrapEnabled.toggle()
    }

    // MARK: - Read-Only

    func isFileReadOnly(_ fileId: UUID) -> Bool {
        readOnlyFileIds.contains(fileId)
    }

    var isSelectedFileReadOnly: Bool {
        guard let id = selectedFileId else { return false }
        return isFileReadOnly(id)
    }

    func toggleReadOnly(for fileId: UUID) {
        if readOnlyFileIds.contains(fileId) {
            readOnlyFileIds.remove(fileId)
        } else {
            readOnlyFileIds.insert(fileId)
        }
    }

    private static let readOnlyPathPatterns = [
        "/node_modules/", "/.build/", "/Pods/", "/DerivedData/",
        "/.git/", "/vendor/", "/dist/", "/build/",
    ]

    private func shouldAutoMarkReadOnly(_ path: String) -> Bool {
        for pattern in Self.readOnlyPathPatterns {
            if path.contains(pattern) { return true }
        }
        if !FileManager.default.isWritableFile(atPath: path) {
            return true
        }
        return false
    }

    func navigateToSymbol(_ symbol: EditorSymbol) {
        cursorLine = symbol.line
    }

    // MARK: - Git Gutter

    /// Refresh the cached git diff data from the working tree.
    func refreshGitDiffs() {
        guard let container, let adapter = container.getOrCreateGitAdapter() else { return }
        Task { @MainActor in
            do {
                let diffs = try await adapter.unstagedDiff()
                cachedFileDiffs = Dictionary(uniqueKeysWithValues: diffs.map { ($0.filePath, $0) })
                loadGitGutterForSelectedFile()
            } catch {
                cachedFileDiffs = [:]
                gitLineChanges = [:]
            }
        }
    }

    /// Populate gitLineChanges for the currently selected file from cached diff data.
    private func loadGitGutterForSelectedFile() {
        guard showGitGutter, let file = selectedFile, let projectPath else {
            gitLineChanges = [:]
            return
        }

        // Compute relative path from project root
        let relativePath: String
        if file.path.hasPrefix(projectPath) {
            var rel = String(file.path.dropFirst(projectPath.count))
            if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
            relativePath = rel
        } else {
            relativePath = file.path
        }

        guard let fileDiff = cachedFileDiffs[relativePath] else {
            gitLineChanges = [:]
            return
        }

        var changes: [Int: GitLineChange] = [:]
        for hunk in fileDiff.hunks {
            for line in hunk.lines {
                switch line.type {
                case .added:
                    if let lineNum = line.newLineNumber {
                        changes[lineNum] = .added
                    }
                case .removed:
                    // Mark the line after the deletion with a delete marker
                    let markerLine = hunk.newStart + hunk.newCount
                    if changes[markerLine] == nil {
                        changes[markerLine] = .deleted
                    }
                case .context:
                    break
                }
            }

            // Lines that appear as both added where removed lines existed nearby are "modified"
            let addedLines = Set(hunk.lines.compactMap { $0.type == .added ? $0.newLineNumber : nil })
            let removedLines = hunk.lines.filter { $0.type == .removed }
            if !removedLines.isEmpty {
                // Pair up: removed lines map to added lines at same hunk-relative position
                var addedInOrder = hunk.lines.compactMap { $0.type == .added ? $0.newLineNumber : nil }
                for _ in removedLines {
                    if let paired = addedInOrder.first {
                        if addedLines.contains(paired) {
                            changes[paired] = .modified
                        }
                        addedInOrder.removeFirst()
                    }
                }
            }
        }

        gitLineChanges = changes
    }

    // MARK: - Bracket Matching

    struct BracketPosition: Equatable {
        let line: Int    // 1-based
        let column: Int  // 0-based character offset within line
    }

    private static let openBrackets: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
    private static let closeBrackets: [Character: Character] = [")": "(", "]": "[", "}": "{"]

    /// Returns the pair of matching bracket positions for the cursor, or nil if not on a bracket.
    var matchedBracketPair: (BracketPosition, BracketPosition)? {
        guard showBracketMatching, let file = selectedFile else { return nil }
        let lines = file.content.components(separatedBy: "\n")
        let lineIdx = cursorLine - 1
        guard lineIdx >= 0 && lineIdx < lines.count else { return nil }
        let line = lines[lineIdx]
        let col = cursorColumn - 1
        guard col >= 0 && col < line.count else { return nil }

        let charIndex = line.index(line.startIndex, offsetBy: col)
        let char = line[charIndex]

        if let close = Self.openBrackets[char] {
            // Search forward for matching close bracket
            if let match = findMatchingForward(lines: lines, fromLine: lineIdx, fromCol: col, open: char, close: close) {
                return (BracketPosition(line: cursorLine, column: col), match)
            }
        } else if let open = Self.closeBrackets[char] {
            // Search backward for matching open bracket
            if let match = findMatchingBackward(lines: lines, fromLine: lineIdx, fromCol: col, open: open, close: char) {
                return (match, BracketPosition(line: cursorLine, column: col))
            }
        }
        return nil
    }

    private func findMatchingForward(lines: [String], fromLine: Int, fromCol: Int, open: Character, close: Character) -> BracketPosition? {
        var depth = 1
        var lineIdx = fromLine
        var col = fromCol + 1

        while lineIdx < lines.count {
            let line = lines[lineIdx]
            while col < line.count {
                let ch = line[line.index(line.startIndex, offsetBy: col)]
                if ch == open { depth += 1 }
                else if ch == close {
                    depth -= 1
                    if depth == 0 {
                        return BracketPosition(line: lineIdx + 1, column: col)
                    }
                }
                col += 1
            }
            lineIdx += 1
            col = 0
        }
        return nil
    }

    private func findMatchingBackward(lines: [String], fromLine: Int, fromCol: Int, open: Character, close: Character) -> BracketPosition? {
        var depth = 1
        var lineIdx = fromLine
        var col = fromCol - 1

        while lineIdx >= 0 {
            let line = lines[lineIdx]
            if col < 0 { col = line.count - 1 }
            while col >= 0 {
                let ch = line[line.index(line.startIndex, offsetBy: col)]
                if ch == close { depth += 1 }
                else if ch == open {
                    depth -= 1
                    if depth == 0 {
                        return BracketPosition(line: lineIdx + 1, column: col)
                    }
                }
                col -= 1
            }
            lineIdx -= 1
            col = -1
        }
        return nil
    }

    /// Returns the set of bracket positions that should be highlighted on a given line.
    func bracketHighlightColumns(forLine lineNumber: Int) -> Set<Int> {
        guard let pair = matchedBracketPair else { return [] }
        var cols: Set<Int> = []
        if pair.0.line == lineNumber { cols.insert(pair.0.column) }
        if pair.1.line == lineNumber { cols.insert(pair.1.column) }
        return cols
    }

    // MARK: - Code Folding

    /// A foldable region: the line that starts it and the line that ends it (both 1-based).
    struct FoldRegion: Equatable {
        let startLine: Int
        let endLine: Int
    }

    /// Detects foldable regions based on indentation increases.
    func foldRegions(for lines: [String]) -> [FoldRegion] {
        guard codeFoldingEnabled else { return [] }
        var regions: [FoldRegion] = []
        let levels = lines.map { indentLevel(of: $0) }
        let count = levels.count

        for i in 0..<count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let currentLevel = levels[i]
            // A line is foldable if the next non-blank line has a deeper indent
            var nextNonBlank = i + 1
            while nextNonBlank < count && lines[nextNonBlank].trimmingCharacters(in: .whitespaces).isEmpty {
                nextNonBlank += 1
            }
            guard nextNonBlank < count && levels[nextNonBlank] > currentLevel else { continue }

            // Find the end of this fold region: last line before indent returns to currentLevel or less
            var endIdx = nextNonBlank
            for j in (nextNonBlank + 1)..<count {
                let t = lines[j].trimmingCharacters(in: .whitespaces)
                if t.isEmpty { continue }
                if levels[j] <= currentLevel { break }
                endIdx = j
            }
            if endIdx > i {
                regions.append(FoldRegion(startLine: i + 1, endLine: endIdx + 1))
            }
        }
        return regions
    }

    private func indentLevel(of line: String) -> Int {
        var spaces = 0
        for char in line {
            if char == " " { spaces += 1 }
            else if char == "\t" { spaces += tabSize }
            else { break }
        }
        return spaces / max(tabSize, 1)
    }

    /// Toggle fold state for the region starting at the given line.
    func toggleFold(at startLine: Int) {
        if collapsedLines.contains(startLine) {
            collapsedLines.remove(startLine)
        } else {
            collapsedLines.insert(startLine)
        }
    }

    /// Returns true if a given line number (1-based) is hidden because it's inside a collapsed fold.
    func isLineHidden(_ lineNumber: Int, regions: [FoldRegion]) -> Bool {
        for region in regions {
            if collapsedLines.contains(region.startLine) &&
               lineNumber > region.startLine && lineNumber <= region.endLine {
                return true
            }
        }
        return false
    }

    /// Returns the fold region that starts at a given line, if any.
    func foldRegionStarting(at lineNumber: Int, regions: [FoldRegion]) -> FoldRegion? {
        regions.first { $0.startLine == lineNumber }
    }

    func foldAll(lines: [String]) {
        for region in foldRegions(for: lines) {
            collapsedLines.insert(region.startLine)
        }
    }

    func unfoldAll() {
        collapsedLines.removeAll()
    }

    // MARK: - Find & Replace

    func toggleFindBar() {
        withAnimation(AnvilAnimation.standard) {
            isFindBarVisible.toggle()
        }
        if !isFindBarVisible {
            findText = ""
            findMatches = []
        }
    }

    func closeFindBar() {
        withAnimation(AnvilAnimation.standard) {
            isFindBarVisible = false
        }
        findText = ""
        findMatches = []
    }

    func findNext() {
        guard !findMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % findMatches.count
        cursorLine = findMatches[currentMatchIndex].line
    }

    func findPrevious() {
        guard !findMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + findMatches.count) % findMatches.count
        cursorLine = findMatches[currentMatchIndex].line
    }

    func replaceCurrent() {
        guard !findMatches.isEmpty,
              currentMatchIndex < findMatches.count,
              let file = selectedFile,
              let fileIndex = openFiles.firstIndex(where: { $0.id == file.id }) else { return }

        let match = findMatches[currentMatchIndex]
        var lines = file.content.components(separatedBy: "\n")
        let lineIdx = match.line - 1
        guard lineIdx >= 0, lineIdx < lines.count else { return }

        var line = lines[lineIdx]
        let startIdx = line.index(line.startIndex, offsetBy: match.range.lowerBound)
        let endIdx = line.index(line.startIndex, offsetBy: match.range.upperBound)
        line.replaceSubrange(startIdx..<endIdx, with: replaceText)
        lines[lineIdx] = line

        let updated = EditorFile(name: file.name, path: file.path, content: lines.joined(separator: "\n"), language: file.language, relativePath: file.relativePath)
        openFiles[fileIndex] = updated
        selectedFileId = updated.id
        updateFindMatches()

        if currentMatchIndex >= findMatches.count && !findMatches.isEmpty {
            currentMatchIndex = 0
        }
    }

    func replaceAll() {
        guard !findMatches.isEmpty,
              let file = selectedFile,
              let fileIndex = openFiles.firstIndex(where: { $0.id == file.id }) else { return }

        var content = file.content
        if findUseRegex {
            let options: NSRegularExpression.Options = findMatchCase ? [] : [.caseInsensitive]
            if let regex = try? NSRegularExpression(pattern: findText, options: options) {
                content = regex.stringByReplacingMatches(
                    in: content,
                    range: NSRange(content.startIndex..., in: content),
                    withTemplate: replaceText
                )
            }
        } else {
            let options: String.CompareOptions = findMatchCase ? [] : [.caseInsensitive]
            content = content.replacingOccurrences(of: findText, with: replaceText, options: options)
        }

        let updated = EditorFile(name: file.name, path: file.path, content: content, language: file.language, relativePath: file.relativePath)
        openFiles[fileIndex] = updated
        selectedFileId = updated.id
        updateFindMatches()
    }

    func updateFindMatches() {
        guard !findText.isEmpty, let file = selectedFile else {
            findMatches = []
            currentMatchIndex = 0
            return
        }

        var matches: [FindMatch] = []
        let lines = file.content.components(separatedBy: "\n")

        if findUseRegex {
            let options: NSRegularExpression.Options = findMatchCase ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: findText, options: options) else {
                findMatches = []
                return
            }
            for (idx, line) in lines.enumerated() {
                let nsLine = line as NSString
                let results = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
                for result in results {
                    let range = result.range
                    matches.append(FindMatch(
                        line: idx + 1,
                        range: range.location..<(range.location + range.length),
                        text: nsLine.substring(with: range)
                    ))
                }
            }
        } else {
            let searchOptions: String.CompareOptions = findMatchCase ? [] : [.caseInsensitive]
            for (idx, line) in lines.enumerated() {
                var searchStart = line.startIndex
                while searchStart < line.endIndex {
                    guard let range = line.range(of: findText, options: searchOptions, range: searchStart..<line.endIndex) else { break }

                    let charStart = line.distance(from: line.startIndex, to: range.lowerBound)
                    let charEnd = line.distance(from: line.startIndex, to: range.upperBound)

                    if findWholeWord {
                        let beforeOk = range.lowerBound == line.startIndex || !line[line.index(before: range.lowerBound)].isLetterOrDigit
                        let afterOk = range.upperBound == line.endIndex || !line[range.upperBound].isLetterOrDigit
                        if beforeOk && afterOk {
                            matches.append(FindMatch(line: idx + 1, range: charStart..<charEnd, text: String(line[range])))
                        }
                    } else {
                        matches.append(FindMatch(line: idx + 1, range: charStart..<charEnd, text: String(line[range])))
                    }

                    searchStart = range.upperBound
                }
            }
        }

        findMatches = matches
        if currentMatchIndex >= matches.count {
            currentMatchIndex = max(0, matches.count - 1)
        }
    }

    /// Returns all match ranges on a given 1-based line number.
    func matchRangesOnLine(_ lineNumber: Int) -> [Range<Int>] {
        findMatches.filter { $0.line == lineNumber }.map { $0.range }
    }

    /// Returns true if the match at the given line/range is the current active match.
    func isCurrentMatch(line: Int, range: Range<Int>) -> Bool {
        guard currentMatchIndex < findMatches.count else { return false }
        let current = findMatches[currentMatchIndex]
        return current.line == line && current.range == range
    }

    // MARK: - Ghost Text (AI Inline Completions)

    /// Called when the cursor moves. Debounces 300ms, then fetches a ghost completion.
    func onCursorPositionChanged(fileContent: String, cursorLine: Int, cursorChar: Int) {
        ghostDebounceTask?.cancel()
        ghostCompletion = nil
        ghostDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await fetchGhostCompletion(context: fileContent, line: cursorLine, char: cursorChar)
        }
    }

    /// Fetches a single-line completion from ACP (using Haiku for speed).
    private func fetchGhostCompletion(context: String, line: Int, char: Int) async {
        guard let container else { return }

        let lines = context.components(separatedBy: "\n")
        let lineIndex = line - 1
        guard lineIndex >= 0, lineIndex < lines.count else { return }

        // Build the context: last ~50 lines up to and including cursor line
        let startLine = max(0, lineIndex - 49)
        let contextLines = Array(lines[startLine...lineIndex])
        let contextText = contextLines.joined(separator: "\n")

        // If the current line is empty or only whitespace, skip
        let currentLine = lines[lineIndex]
        let trimmed = currentLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return }

        let client = await container.getOrCreateACPClient()
        let language = selectedFile?.language ?? "text"

        let systemPrompt = "Complete the following \(language) code with a single line continuation. Reply with ONLY the completion text that follows the cursor, no explanation."

        let haikuModel = ACPModel(
            id: "claude-haiku-4-5-20251001",
            name: "Claude Haiku 4.5",
            provider: "anthropic",
            contextWindow: 200_000,
            inputCostPer1kTokens: 0.0008,
            outputCostPer1kTokens: 0.004,
            capabilities: [.codeGeneration]
        )

        do {
            let result = try await client.complete(
                prompt: contextText,
                systemPrompt: systemPrompt,
                model: haikuModel
            )
            guard !Task.isCancelled else { return }
            let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                self.ghostCompletion = cleaned
            }
        } catch {
            // Silently fail -- ghost text is best-effort
        }
    }

    /// Accept the ghost completion and return the text to insert. Clears the ghost.
    func acceptGhostCompletion() -> String? {
        defer { ghostCompletion = nil }
        return ghostCompletion
    }

    /// Dismiss the ghost completion without inserting.
    func dismissGhostCompletion() {
        ghostDebounceTask?.cancel()
        ghostCompletion = nil
    }

    // MARK: - Inline Edit (⌘K)

    /// Open the inline edit prompt bar for the given line range.
    func beginInlineEdit(range: ClosedRange<Int>) {
        inlineEditSelectedRange = range
        inlineEditPrompt = ""
        inlineEditDiff = nil
        inlineEditStreamingText = ""
        inlineEditPhase = .prompting
    }

    /// Cancel inline edit at any stage.
    func cancelInlineEdit() {
        inlineEditTask?.cancel()
        inlineEditTask = nil
        inlineEditPhase = .hidden
        inlineEditPrompt = ""
        inlineEditDiff = nil
        inlineEditStreamingText = ""
    }

    /// Submit the inline edit prompt — streams a simulated (or real ACP) response.
    func submitInlineEdit() {
        guard inlineEditPhase == .prompting,
              !inlineEditPrompt.isEmpty,
              let file = selectedFile else { return }

        inlineEditPhase = .generating
        inlineEditStreamingText = ""

        let lines = file.content.components(separatedBy: "\n")
        let start = max(0, inlineEditSelectedRange.lowerBound - 1)
        let end = min(lines.count - 1, inlineEditSelectedRange.upperBound - 1)
        let selectedLines = Array(lines[start...end])
        let prompt = inlineEditPrompt
        let startLine = inlineEditSelectedRange.lowerBound

        inlineEditTask = Task { @MainActor in
            let proposed = await generateInlineEdit(
                originalLines: selectedLines,
                prompt: prompt
            )
            guard !Task.isCancelled else { return }
            inlineEditDiff = InlineEditDiff(
                originalLines: selectedLines,
                proposedLines: proposed,
                startLine: startLine
            )
            inlineEditPhase = .reviewing
        }
    }

    /// Accept the proposed diff — applies it to the file content.
    func acceptInlineEdit() {
        guard let diff = inlineEditDiff,
              let file = selectedFile,
              let fileIndex = openFiles.firstIndex(where: { $0.id == file.id }) else {
            cancelInlineEdit()
            return
        }

        var lines = file.content.components(separatedBy: "\n")
        let start = max(0, diff.startLine - 1)
        let end = min(lines.count - 1, start + diff.originalLines.count - 1)
        guard start <= end, start < lines.count else {
            cancelInlineEdit()
            return
        }

        lines.replaceSubrange(start...end, with: diff.proposedLines)
        let newContent = lines.joined(separator: "\n")
        let updated = EditorFile(
            name: file.name,
            path: file.path,
            content: newContent,
            language: file.language,
            relativePath: file.relativePath
        )
        openFiles[fileIndex] = updated
        selectedFileId = updated.id

        // Move cursor to end of edited region
        cursorLine = diff.startLine + diff.proposedLines.count - 1

        cancelInlineEdit()
    }

    /// Reject the diff — discard and return to prompting so user can refine.
    func rejectInlineEdit() {
        inlineEditDiff = nil
        inlineEditStreamingText = ""
        inlineEditPhase = .prompting
    }

    // MARK: - Edit Generation (ACP-powered)

    private func generateInlineEdit(originalLines: [String], prompt: String) async -> [String] {
        guard let container else {
            // No ACP client available — return original unchanged
            return originalLines
        }

        let client = await container.getOrCreateACPClient()
        let originalCode = originalLines.joined(separator: "\n")
        let language = selectedFile?.language ?? "text"

        let systemPrompt = """
        You are a code editor assistant. The user has selected a block of \(language) code and wants you to edit it.
        Return ONLY the edited code — no explanations, no markdown fences, no surrounding text.
        Preserve the original indentation style. If the instruction is unclear, make your best judgment.
        """

        let userPrompt = """
        Edit the following code according to this instruction: \(prompt)

        ```
        \(originalCode)
        ```
        """

        do {
            let result = try await client.complete(
                prompt: userPrompt,
                systemPrompt: systemPrompt
            )

            // Strip markdown fences if the model included them despite instructions
            let cleaned = stripMarkdownFences(result)
            let resultLines = cleaned.components(separatedBy: "\n")
            return resultLines.isEmpty ? originalLines : resultLines
        } catch {
            // ACP call failed — return original unchanged
            return originalLines
        }
    }

    /// Strip leading/trailing markdown code fences if present.
    private func stripMarkdownFences(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        if let first = lines.first?.trimmingCharacters(in: .whitespaces),
           first.hasPrefix("```") {
            lines.removeFirst()
        }
        if let last = lines.last?.trimmingCharacters(in: .whitespaces),
           last == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
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

// MARK: - Character Extension

private extension Character {
    var isLetterOrDigit: Bool {
        isLetter || isNumber || self == "_"
    }
}
