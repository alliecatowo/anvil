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
            break // TODO: new agent session
        case .newItem:
            break // TODO: new item
        case .settings:
            break // TODO: open settings
        case .quickCapture:
            appState.toggleQuickCapture()
        case .searchInFiles:
            break // TODO: search in files
        }
    }
}

// MARK: - Command Item

struct CommandItem: Identifiable, Sendable {
    let id: String
    let title: String
    let icon: String
    let shortcut: String?
    let category: CommandCategory
    let action: CommandAction
}

enum CommandCategory: String, CaseIterable, Sendable {
    case actions = "Actions"
    case modes = "Modes"
    case navigation = "Navigation"
}

// MARK: - View Model

@MainActor
final class CommandPaletteViewModel: ObservableObject {
    @Published var query = "" {
        didSet { search(query) }
    }
    @Published var selectedIndex = 0
    @Published private(set) var filteredItems: [CommandItem] = []
    @Published private(set) var matchedIndicesMap: [String: Set<Int>] = [:]

    private var allItems: [CommandItem] = []

    init() {
        registerAllCommands()
        filteredItems = allItems
    }

    // MARK: - Registration

    private func registerAllCommands() {
        var items: [CommandItem] = []

        // --- Actions ---

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
            title: "New Item",
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

        // --- Modes ---

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

        // --- Navigation / Toggles ---

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

    // MARK: - Search

    func search(_ query: String) {
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

    // MARK: - Selection

    func moveSelection(_ direction: Int) {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = (selectedIndex + direction + filteredItems.count) % filteredItems.count
    }

    func execute(appState: AppState) {
        guard !filteredItems.isEmpty,
              selectedIndex >= 0,
              selectedIndex < filteredItems.count else { return }
        let item = filteredItems[selectedIndex]
        item.action.perform(on: appState)
        appState.toggleCommandPalette()
    }

    // MARK: - Grouped results

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
