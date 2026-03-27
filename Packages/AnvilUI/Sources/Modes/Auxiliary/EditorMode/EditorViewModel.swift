import SwiftUI

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
class EditorViewModel: ObservableObject {
    @Published var openFiles: [EditorFile] = []
    @Published var selectedFileId: UUID?
    @Published var cursorLine: Int = 12
    @Published var cursorColumn: Int = 1
    @Published var isSymbolOutlineVisible: Bool = true
    @Published var expandedFolders: Set<UUID> = []
    @Published var whitespaceMode: WhitespaceMode = .none
    @Published var readOnlyFileIds: Set<UUID> = []
    @Published var isWordWrapEnabled: Bool = false

    // MARK: Find & Replace (⌘F)
    @Published var isFindBarVisible: Bool = false
    @Published var findText: String = "" { didSet { updateFindMatches() } }
    @Published var replaceText: String = ""
    @Published var findMatchCase: Bool = false { didSet { updateFindMatches() } }
    @Published var findWholeWord: Bool = false { didSet { updateFindMatches() } }
    @Published var findUseRegex: Bool = false { didSet { updateFindMatches() } }
    @Published var findMatches: [FindMatch] = []
    @Published var currentMatchIndex: Int = 0

    // MARK: Inline Edit (⌘K)
    @Published var inlineEditPhase: InlineEditPhase = .hidden
    @Published var inlineEditSelectedRange: ClosedRange<Int> = 1...1   // 1-based line range
    @Published var inlineEditPrompt: String = ""
    @Published var inlineEditDiff: InlineEditDiff? = nil
    @Published var inlineEditStreamingText: String = ""

    private var inlineEditTask: Task<Void, Never>?

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

        let file = EditorFile(name: name, path: path, content: content, language: language)
        openFiles.append(file)
        selectedFileId = file.id
        cursorLine = 1
        cursorColumn = 1

        // Auto-detect read-only files
        if shouldAutoMarkReadOnly(path) {
            readOnlyFileIds.insert(file.id)
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

        let updated = EditorFile(name: file.name, path: file.path, content: lines.joined(separator: "\n"), language: file.language)
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

        let updated = EditorFile(name: file.name, path: file.path, content: content, language: file.language)
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
            language: file.language
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

    // MARK: - Edit Generation (stub — replace with real ACP call)

    private func generateInlineEdit(originalLines: [String], prompt: String) async -> [String] {
        // Simulate streaming delay
        try? await Task.sleep(nanoseconds: 800_000_000)

        // Stub: apply simple transformations based on common prompt keywords
        // In production this calls ACPClient with the file context + prompt
        let lower = prompt.lowercased()

        if lower.contains("comment") || lower.contains("document") || lower.contains("explain") {
            return addDocComments(to: originalLines)
        } else if lower.contains("async") || lower.contains("await") {
            return makeAsync(lines: originalLines)
        } else if lower.contains("guard") || lower.contains("unwrap") {
            return addGuardStatements(to: originalLines)
        } else if lower.contains("todo") {
            return originalLines.map { "// TODO: \($0.trimmingCharacters(in: .whitespaces))" }
        } else {
            // Return original with a comment showing the prompt was received
            var result = originalLines
            result.insert("// AI edit: \(prompt)", at: 0)
            return result
        }
    }

    private func addDocComments(to lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("func ") {
                let indent = String(line.prefix(while: { $0 == " " }))
                let name = trimmed.dropFirst(5).prefix(while: { $0 != "(" })
                result.append("\(indent)/// \(name) performs the described operation.")
                result.append(line)
            } else {
                result.append(line)
            }
        }
        return result
    }

    private func makeAsync(lines: [String]) -> [String] {
        lines.map { line in
            if line.contains("func ") && !line.contains("async") {
                return line.replacingOccurrences(of: "func ", with: "func ")
                    .replacingOccurrences(of: ") {", with: ") async {")
            }
            return line
        }
    }

    private func addGuardStatements(to lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            result.append(line)
            if line.contains("let ") && line.contains("= ") && !line.contains("guard") {
                let indent = String(line.prefix(while: { $0 == " " }))
                result.append("\(indent)// guard let ... else { return } — add guard here")
            }
        }
        return result
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
