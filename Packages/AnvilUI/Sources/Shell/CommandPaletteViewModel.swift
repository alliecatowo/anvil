import SwiftUI

// MARK: - Fuzzy Match

struct FuzzyMatch: Sendable {
    let score: Int
    let matchedIndices: Set<Int>

    /// Fuzzy-match `query` against `target`. Each character in the query must appear
    /// in order in the target. Scoring: +10 per match, +5 bonus for consecutive,
    /// +8 bonus for word-boundary match, case-exact bonus +1.
    static func match(query: String, target: String) -> FuzzyMatch? {
        guard !query.isEmpty else {
            return FuzzyMatch(score: 0, matchedIndices: [])
        }

        let queryChars = Array(query.lowercased())
        let targetLower = Array(target.lowercased())
        let targetOriginal = Array(target)

        var matchedIndices: [Int] = []
        var queryIndex = 0
        var score = 0
        var lastMatchIndex = -2

        for (targetIndex, char) in targetLower.enumerated() {
            guard queryIndex < queryChars.count else { break }
            if char == queryChars[queryIndex] {
                matchedIndices.append(targetIndex)
                score += 10

                // Consecutive bonus
                if targetIndex == lastMatchIndex + 1 {
                    score += 5
                }

                // Word boundary bonus (start of string or preceded by space/separator)
                if targetIndex == 0 || " -_./".contains(targetLower[targetIndex - 1]) {
                    score += 8
                }

                // Case-exact bonus
                if String(targetOriginal[targetIndex]) == String(queryChars[queryIndex]) {
                    score += 1
                }

                lastMatchIndex = targetIndex
                queryIndex += 1
            }
        }

        // All query characters must match
        guard queryIndex == queryChars.count else { return nil }

        return FuzzyMatch(score: score, matchedIndices: Set(matchedIndices))
    }
}

// MARK: - Command Action

enum CommandAction: Sendable {
    case switchMode(AnvilMode)
    case toggleSidebar
    case toggleInspector
    case toggleTerminal
    case newAgentSession
    case newItem
    case settings
    case quickCapture
    case searchInFiles
    case openFile(path: String)
    case goToSymbol(filePath: String, line: Int)
    // Mode-specific actions
    case toggleSourceControl
    case createTicket
    case switchBoardView
    case switchListView
    case clearFilters
    case refreshPRs
    case refreshDeploys
    case cycleWhitespace

    @MainActor
    func perform(on appState: AppState) {
        switch self {
        case .switchMode(let mode):
            appState.switchMode(mode)
        case .toggleSidebar:
            appState.toggleSidebar()
        case .toggleInspector:
            appState.toggleInspector()
        case .toggleTerminal:
            appState.toggleTerminal()
        case .newAgentSession:
            appState.switchMode(.agent)
            appState.agentViewModel.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        case .newItem:
            appState.switchMode(.intent)
            appState.intentViewModel.isCreatingTicket = true
        case .settings:
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case .quickCapture:
            appState.toggleQuickCapture()
        case .searchInFiles:
            break // Handled externally
        case .openFile(let path):
            appState.switchMode(.editor)
            appState.pendingFileToOpen = path
        case .goToSymbol(let filePath, let line):
            appState.switchMode(.editor)
            appState.pendingFileToOpen = filePath
            appState.pendingSymbolLine = line
        case .toggleSourceControl:
            appState.isSourceControlVisible.toggle()
        case .createTicket:
            appState.switchMode(.intent)
            appState.intentViewModel.isCreatingTicket = true
        case .switchBoardView:
            appState.intentViewModel.viewMode = .board
        case .switchListView:
            appState.intentViewModel.viewMode = .list
        case .clearFilters:
            appState.intentViewModel.clearFilters()
        case .refreshPRs:
            break // Would trigger PR refresh in review mode
        case .refreshDeploys:
            break // Would trigger deploy refresh in ship mode
        case .cycleWhitespace:
            appState.editorViewModel.cycleWhitespace()
        }
    }
}

// MARK: - Palette Mode

public enum PaletteMode: Equatable {
    case commands   // > prefix: existing command list
    case files      // no prefix or ⌘P entry: file search
    case symbols    // @ prefix: symbol search in current file or all files
}

// MARK: - Command Item

struct CommandItem: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color?
    let shortcut: String?
    let category: CommandCategory
    let action: CommandAction

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color? = nil,
        shortcut: String? = nil,
        category: CommandCategory,
        action: CommandAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.shortcut = shortcut
        self.category = category
        self.action = action
    }
}

enum CommandCategory: String, CaseIterable, Sendable {
    case contextual = "Current Mode"
    case actions = "Actions"
    case modes = "Modes"
    case navigation = "Navigation"
    case files = "Files"
    case symbols = "Symbols"
}

// MARK: - File Result

struct FileResult: Sendable {
    let path: String
    let name: String
    let relativePath: String

    var icon: String {
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"  // fallback to doc below
        case "ts", "tsx", "js", "jsx": return "doc.text"
        case "json": return "curlybraces"
        case "md", "markdown": return "doc.richtext"
        case "yml", "yaml": return "gearshape.2"
        case "sh", "bash", "zsh": return "terminal"
        case "py": return "doc.text"
        case "html", "css": return "globe"
        case "sql": return "cylinder"
        default: return "doc"
        }
    }
}

// MARK: - Symbol Result

struct SymbolResult: Sendable {
    let name: String
    let kind: String
    let kindIcon: String
    let kindColor: Color
    let filePath: String
    let fileName: String
    let line: Int
}

// MARK: - View Model

@MainActor
final class CommandPaletteViewModel: ObservableObject {
    @Published var query = "" {
        didSet { handleQueryChange() }
    }
    @Published var selectedIndex = 0
    @Published private(set) var filteredItems: [CommandItem] = []
    @Published private(set) var matchedIndicesMap: [String: Set<Int>] = [:]
    @Published private(set) var fileResults: [FileResult] = []
    @Published private(set) var symbolResults: [SymbolResult] = []
    @Published private(set) var filteredFileResults: [FileResult] = []
    @Published private(set) var filteredSymbolResults: [SymbolResult] = []
    @Published private(set) var fileMatchedIndicesMap: [String: Set<Int>] = [:]
    @Published private(set) var symbolMatchedIndicesMap: [String: Set<Int>] = [:]
    @Published var paletteMode: PaletteMode = .commands
    @Published private(set) var isLoadingFiles = false

    private var allItems: [CommandItem] = []
    private var projectPath: String?
    private var fileSystemService: FileSystemService?
    private var scanTask: Task<Void, Never>?
    private var currentAppMode: AnvilMode?

    init() {
        registerAllCommands(for: nil)
        filteredItems = allItems
    }

    // MARK: - Configuration

    /// Call when the palette is opened to set project context.
    func configure(projectPath: String?, fileSystemService: FileSystemService?, initialMode: PaletteMode = .commands, currentMode: AnvilMode? = nil) {
        self.projectPath = projectPath
        self.fileSystemService = fileSystemService
        self.currentAppMode = currentMode

        // Rebuild commands with mode context
        registerAllCommands(for: currentMode)

        // Reset
        query = ""
        selectedIndex = 0

        // Set initial mode
        paletteMode = initialMode

        // Pre-scan files if entering file or symbol mode
        if initialMode == .files || initialMode == .symbols {
            scanFiles()
        }
    }

    // MARK: - Query Handling

    private func handleQueryChange() {
        // Detect mode from query prefix
        if query.hasPrefix(">") {
            paletteMode = .commands
        } else if query.hasPrefix("@") {
            paletteMode = .symbols
            if fileResults.isEmpty { scanFiles() }
        } else if paletteMode == .files || paletteMode == .symbols {
            // Stay in current mode (file/symbol) when no special prefix
        } else {
            paletteMode = .commands
        }

        switch paletteMode {
        case .commands:
            let effectiveQuery = query.hasPrefix(">") ? String(query.dropFirst()).trimmingCharacters(in: .whitespaces) : query
            searchCommands(effectiveQuery)
        case .files:
            searchFiles(query)
        case .symbols:
            let effectiveQuery = query.hasPrefix("@") ? String(query.dropFirst()).trimmingCharacters(in: .whitespaces) : query
            searchSymbols(effectiveQuery)
        }
    }

    // MARK: - Command Registration

    private func registerAllCommands(for mode: AnvilMode?) {
        var items: [CommandItem] = []

        // Add contextual commands for the current mode first
        if let mode {
            items.append(contentsOf: contextualCommands(for: mode))
        }

        items.append(CommandItem(
            id: "new-agent-session",
            title: "New Agent Session",
            icon: "cpu",
            shortcut: "\u{2318}\u{21E7}A",
            category: .actions,
            action: .newAgentSession
        ))

        items.append(CommandItem(
            id: "new-item",
            title: "New Ticket",
            icon: "plus.square",
            shortcut: "\u{2318}N",
            category: .actions,
            action: .newItem
        ))

        items.append(CommandItem(
            id: "settings",
            title: "Settings",
            icon: "gear",
            shortcut: "\u{2318},",
            category: .actions,
            action: .settings
        ))

        items.append(CommandItem(
            id: "quick-capture",
            title: "Quick Capture",
            icon: "note.text.badge.plus",
            shortcut: "\u{2318}\u{21E7}N",
            category: .actions,
            action: .quickCapture
        ))

        items.append(CommandItem(
            id: "search-in-files",
            title: "Search in Files",
            icon: "magnifyingglass",
            shortcut: "\u{2318}\u{21E7}F",
            category: .actions,
            action: .searchInFiles
        ))

        for mode in AnvilMode.allCases {
            let shortcutHint = mode.shortcutNumber.map { "\u{2318}\($0)" }
            items.append(CommandItem(
                id: "mode-\(mode.rawValue.lowercased())",
                title: "Switch to \(mode.rawValue)",
                icon: mode.icon,
                shortcut: shortcutHint,
                category: .modes,
                action: .switchMode(mode)
            ))
        }

        items.append(CommandItem(
            id: "toggle-sidebar",
            title: "Toggle Sidebar",
            icon: "sidebar.left",
            shortcut: "\u{2318}B",
            category: .navigation,
            action: .toggleSidebar
        ))

        items.append(CommandItem(
            id: "toggle-inspector",
            title: "Toggle Inspector",
            icon: "sidebar.right",
            shortcut: "\u{2318}\u{21E7}I",
            category: .navigation,
            action: .toggleInspector
        ))

        items.append(CommandItem(
            id: "toggle-terminal",
            title: "Toggle Terminal",
            icon: "terminal",
            shortcut: "\u{2318}J",
            category: .navigation,
            action: .toggleTerminal
        ))

        allItems = items
    }

    // MARK: - Contextual Commands

    private func contextualCommands(for mode: AnvilMode) -> [CommandItem] {
        switch mode {
        case .intent:
            return [
                CommandItem(id: "ctx-create-ticket", title: "Create Ticket", icon: "plus.square", iconColor: AnvilColor.accentBlue, category: .contextual, action: .createTicket),
                CommandItem(id: "ctx-board-view", title: "Switch to Board View", icon: "square.grid.3x3", category: .contextual, action: .switchBoardView),
                CommandItem(id: "ctx-list-view", title: "Switch to List View", icon: "list.bullet", category: .contextual, action: .switchListView),
                CommandItem(id: "ctx-clear-filters", title: "Clear All Filters", icon: "line.3.horizontal.decrease.circle", category: .contextual, action: .clearFilters),
            ]
        case .agent:
            return [
                CommandItem(id: "ctx-new-session", title: "New Agent Session", icon: "cpu", iconColor: AnvilColor.accentGreen, shortcut: "\u{2318}\u{21E7}A", category: .contextual, action: .newAgentSession),
            ]
        case .review:
            return [
                CommandItem(id: "ctx-refresh-prs", title: "Refresh Pull Requests", icon: "arrow.clockwise", iconColor: AnvilColor.accentPurple, category: .contextual, action: .refreshPRs),
                CommandItem(id: "ctx-source-control", title: "Toggle Source Control Panel", icon: "arrow.triangle.branch", category: .contextual, action: .toggleSourceControl),
            ]
        case .ship:
            return [
                CommandItem(id: "ctx-refresh-deploys", title: "Refresh Deployments", icon: "arrow.clockwise", iconColor: AnvilColor.accentAmber, category: .contextual, action: .refreshDeploys),
            ]
        case .editor:
            return [
                CommandItem(id: "ctx-source-control", title: "Toggle Source Control Panel", icon: "arrow.triangle.branch", category: .contextual, action: .toggleSourceControl),
                CommandItem(id: "ctx-search-files", title: "Search in Files", icon: "magnifyingglass", shortcut: "\u{2318}\u{21E7}F", category: .contextual, action: .searchInFiles),
                CommandItem(id: "ctx-toggle-whitespace", title: "Toggle Whitespace Visibility", subtitle: "Cycle: None → Boundary → All", icon: "eye", category: .contextual, action: .cycleWhitespace),
            ]
        case .database:
            return [
                CommandItem(id: "ctx-new-query", title: "New Query Tab", icon: "terminal", iconColor: AnvilColor.accentTeal, category: .contextual, action: .switchMode(.database)),
            ]
        case .terminal:
            return [
                CommandItem(id: "ctx-new-terminal", title: "New Terminal Tab", icon: "terminal", iconColor: AnvilColor.accentGreen, category: .contextual, action: .toggleTerminal),
            ]
        default:
            return []
        }
    }

    // MARK: - Command Search

    func searchCommands(_ query: String) {
        var newMap: [String: Set<Int>] = [:]

        if query.isEmpty {
            filteredItems = allItems
            matchedIndicesMap = [:]
            selectedIndex = 0
            return
        }

        var scored: [(item: CommandItem, score: Int)] = []
        for item in allItems {
            if let result = FuzzyMatch.match(query: query, target: item.title) {
                scored.append((item, result.score))
                newMap[item.id] = result.matchedIndices
            }
        }

        scored.sort { $0.score > $1.score }
        filteredItems = scored.map(\.item)
        matchedIndicesMap = newMap
        selectedIndex = 0
    }

    // MARK: - File Scanning

    func scanFiles() {
        guard let path = projectPath, let service = fileSystemService else { return }
        guard !isLoadingFiles else { return }

        scanTask?.cancel()
        isLoadingFiles = true

        scanTask = Task {
            let nodes = service.readTree(at: path, maxDepth: 6)
            var results: [FileResult] = []
            collectFiles(from: nodes, projectRoot: path, into: &results)

            if !Task.isCancelled {
                fileResults = results
                isLoadingFiles = false
                // If we're already in file/symbol mode, re-search
                if paletteMode == .files {
                    searchFiles(query)
                } else if paletteMode == .symbols {
                    let effectiveQuery = query.hasPrefix("@") ? String(query.dropFirst()).trimmingCharacters(in: .whitespaces) : query
                    searchSymbols(effectiveQuery)
                }
            }
        }
    }

    private func collectFiles(
        from nodes: [FileSystemService.FileNode],
        projectRoot: String,
        into results: inout [FileResult]
    ) {
        for node in nodes {
            if node.isDirectory {
                if let children = node.children {
                    collectFiles(from: children, projectRoot: projectRoot, into: &results)
                }
            } else {
                let relativePath = node.path.hasPrefix(projectRoot)
                    ? String(node.path.dropFirst(projectRoot.count + 1))
                    : node.path
                results.append(FileResult(path: node.path, name: node.name, relativePath: relativePath))
            }
        }
    }

    // MARK: - File Search

    func searchFiles(_ query: String) {
        var newMap: [String: Set<Int>] = [:]

        if query.isEmpty {
            filteredFileResults = Array(fileResults.prefix(50))
            fileMatchedIndicesMap = [:]
            selectedIndex = 0
            return
        }

        var scored: [(result: FileResult, score: Int)] = []
        for file in fileResults {
            // Match against file name first (higher weight), then relative path
            if let nameMatch = FuzzyMatch.match(query: query, target: file.name) {
                scored.append((file, nameMatch.score + 20)) // name match bonus
                newMap[file.path] = nameMatch.matchedIndices
            } else if let pathMatch = FuzzyMatch.match(query: query, target: file.relativePath) {
                scored.append((file, pathMatch.score))
                newMap[file.path] = pathMatch.matchedIndices
            }
        }

        scored.sort { $0.score > $1.score }
        filteredFileResults = scored.prefix(50).map(\.result)
        fileMatchedIndicesMap = newMap
        selectedIndex = 0
    }

    // MARK: - Symbol Search

    func searchSymbols(_ query: String) {
        // Build symbol list from all scanned files
        if symbolResults.isEmpty {
            buildSymbolIndex()
        }

        var newMap: [String: Set<Int>] = [:]

        if query.isEmpty {
            filteredSymbolResults = Array(symbolResults.prefix(50))
            symbolMatchedIndicesMap = [:]
            selectedIndex = 0
            return
        }

        var scored: [(result: SymbolResult, score: Int)] = []
        for symbol in symbolResults {
            if let match = FuzzyMatch.match(query: query, target: symbol.name) {
                let symbolId = "\(symbol.filePath):\(symbol.line)"
                scored.append((symbol, match.score))
                newMap[symbolId] = match.matchedIndices
            }
        }

        scored.sort { $0.score > $1.score }
        filteredSymbolResults = scored.prefix(100).map(\.result)
        symbolMatchedIndicesMap = newMap
        selectedIndex = 0
    }

    private func buildSymbolIndex() {
        guard let service = fileSystemService else { return }
        var symbols: [SymbolResult] = []

        for file in fileResults where isCodeFile(file.name) {
            guard let content = service.readFile(at: file.path) else { continue }
            let fileSymbols = extractSymbols(from: content, filePath: file.path, fileName: file.name)
            symbols.append(contentsOf: fileSymbols)
        }

        symbolResults = symbols
    }

    private func isCodeFile(_ name: String) -> Bool {
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        return ["swift", "ts", "tsx", "js", "jsx", "py", "go", "rs", "kt", "java", "cs"].contains(ext)
    }

    private func extractSymbols(from content: String, filePath: String, fileName: String) -> [SymbolResult] {
        var results: [SymbolResult] = []
        let lines = content.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") { continue }

            if let name = extractTypeName(from: trimmed, keyword: "class "), !name.isEmpty {
                results.append(SymbolResult(name: name, kind: "class", kindIcon: "c.square", kindColor: AnvilColor.accentPurple, filePath: filePath, fileName: fileName, line: lineNumber))
            } else if let name = extractTypeName(from: trimmed, keyword: "struct "), !name.isEmpty {
                results.append(SymbolResult(name: name, kind: "struct", kindIcon: "s.square", kindColor: AnvilColor.accentGreen, filePath: filePath, fileName: fileName, line: lineNumber))
            } else if let name = extractTypeName(from: trimmed, keyword: "protocol "), !name.isEmpty {
                results.append(SymbolResult(name: name, kind: "protocol", kindIcon: "p.square.fill", kindColor: AnvilColor.accentRed, filePath: filePath, fileName: fileName, line: lineNumber))
            } else if let name = extractTypeName(from: trimmed, keyword: "enum "), !name.isEmpty {
                results.append(SymbolResult(name: name, kind: "enum", kindIcon: "e.square", kindColor: AnvilColor.accentTeal, filePath: filePath, fileName: fileName, line: lineNumber))
            } else if trimmed.hasPrefix("func ") || trimmed.contains(" func ") {
                let name = extractFuncName(from: trimmed)
                if !name.isEmpty {
                    results.append(SymbolResult(name: name, kind: "func", kindIcon: "f.square", kindColor: AnvilColor.accentBlue, filePath: filePath, fileName: fileName, line: lineNumber))
                }
            }
        }

        return results
    }

    private func extractTypeName(from line: String, keyword: String) -> String? {
        guard line.contains(keyword) else { return nil }
        guard let range = line.range(of: keyword) else { return nil }
        let rest = String(line[range.upperBound...])
        let name = rest.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })
        return name.isEmpty ? nil : String(name)
    }

    private func extractFuncName(from line: String) -> String {
        guard let range = line.range(of: "func ") else { return "" }
        let rest = String(line[range.upperBound...])
        let name = rest.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })
        return String(name)
    }

    // MARK: - Selection

    func moveSelection(_ direction: Int) {
        let count = resultCount
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + direction + count) % count
    }

    private var resultCount: Int {
        switch paletteMode {
        case .commands: return filteredItems.count
        case .files: return filteredFileResults.count
        case .symbols: return filteredSymbolResults.count
        }
    }

    func execute(appState: AppState) {
        switch paletteMode {
        case .commands:
            guard !filteredItems.isEmpty, selectedIndex < filteredItems.count else { return }
            filteredItems[selectedIndex].action.perform(on: appState)

        case .files:
            guard !filteredFileResults.isEmpty, selectedIndex < filteredFileResults.count else { return }
            let file = filteredFileResults[selectedIndex]
            CommandAction.openFile(path: file.path).perform(on: appState)

        case .symbols:
            guard !filteredSymbolResults.isEmpty, selectedIndex < filteredSymbolResults.count else { return }
            let symbol = filteredSymbolResults[selectedIndex]
            CommandAction.goToSymbol(filePath: symbol.filePath, line: symbol.line).perform(on: appState)
        }

        appState.toggleCommandPalette()
    }

    // MARK: - Grouped command results (commands mode only)

    var groupedItems: [(category: CommandCategory, items: [(index: Int, item: CommandItem)])] {
        var groups: [CommandCategory: [(index: Int, item: CommandItem)]] = [:]
        for (flatIndex, item) in filteredItems.enumerated() {
            groups[item.category, default: []].append((flatIndex, item))
        }
        return CommandCategory.allCases.compactMap { cat in
            guard let items = groups[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }
}
