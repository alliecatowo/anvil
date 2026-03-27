import SwiftUI

public struct CommandPalette: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var viewModel = CommandPaletteViewModel()
    @FocusState private var isSearchFocused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.toggleCommandPalette()
                }

            // Palette panel
            VStack(spacing: 0) {
                searchField
                Divider().overlay(AnvilColor.borderSubtle)
                modeHints
                Divider().overlay(AnvilColor.borderSubtle)
                resultsArea
            }
            .frame(width: AnvilSpacing.commandPaletteWidth)
            .background(.ultraThinMaterial)
            .background(AnvilColor.backgroundElevated.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
            .padding(.top, 100)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            viewModel.configure(
                projectPath: container.currentProjectPath,
                fileSystemService: container.currentProjectPath != nil ? container.fileSystemService : nil,
                initialMode: appState.commandPaletteInitialMode,
                currentMode: appState.currentMode
            )
            // Pre-populate query prefix for file/symbol modes
            if appState.commandPaletteInitialMode == .symbols {
                viewModel.query = "@"
            }
            isSearchFocused = true
        }
        .onExitCommand {
            appState.toggleCommandPalette()
        }
        .onKeyPress(.upArrow) {
            viewModel.moveSelection(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveSelection(1)
            return .handled
        }
        .onKeyPress(.return) {
            viewModel.execute(appState: appState)
            return .handled
        }
        .onKeyPress(.escape) {
            appState.toggleCommandPalette()
            return .handled
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Mode icon
            Image(systemName: searchIcon)
                .font(.system(size: 15))
                .foregroundStyle(searchIconColor)
                .frame(width: 20)
                .animation(.easeOut(duration: 0.12), value: viewModel.paletteMode)

            TextField(placeholder, text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(AnvilFont.commandPaletteInput)
                .foregroundStyle(AnvilColor.textPrimary)
                .focused($isSearchFocused)

            if viewModel.isLoadingFiles {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(AnvilSpacing.md)
        .frame(height: 48)
    }

    private var searchIcon: String {
        switch viewModel.paletteMode {
        case .commands: return "magnifyingglass"
        case .files: return "doc.text.magnifyingglass"
        case .symbols: return "at"
        }
    }

    private var searchIconColor: Color {
        switch viewModel.paletteMode {
        case .commands: return AnvilColor.textTertiary
        case .files: return AnvilColor.accentBlue
        case .symbols: return AnvilColor.accentPurple
        }
    }

    private var placeholder: String {
        switch viewModel.paletteMode {
        case .commands: return "Search commands, modes, settings..."
        case .files: return "Search files by name or path..."
        case .symbols: return "Search symbols (type, function, class)..."
        }
    }

    // MARK: - Mode Hints Bar

    private var modeHints: some View {
        HStack(spacing: AnvilSpacing.md) {
            ModeHintChip(label: "Files", shortcut: "⌘P", isActive: viewModel.paletteMode == .files) {
                if viewModel.paletteMode == .files {
                    viewModel.query = ""
                } else {
                    viewModel.query = ""
                    viewModel.paletteMode = .files
                    viewModel.configure(
                        projectPath: container.currentProjectPath,
                        fileSystemService: container.currentProjectPath != nil ? container.fileSystemService : nil,
                        initialMode: .files
                    )
                }
            }

            ModeHintChip(label: "Symbols", shortcut: "@", isActive: viewModel.paletteMode == .symbols) {
                if viewModel.paletteMode == .symbols {
                    viewModel.query = "@"
                } else {
                    viewModel.query = "@"
                }
            }

            ModeHintChip(label: "Commands", shortcut: ">", isActive: viewModel.paletteMode == .commands) {
                viewModel.query = ">"
            }

            Spacer()

            Text("↑↓ navigate · ↵ open · esc close")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: 28)
    }

    // MARK: - Results Area

    private var resultsArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    switch viewModel.paletteMode {
                    case .commands:
                        commandResults(proxy: proxy)
                    case .files:
                        fileResultsList(proxy: proxy)
                    case .symbols:
                        symbolResultsList(proxy: proxy)
                    }
                }
                .padding(.vertical, AnvilSpacing.xxs)
            }
            .frame(maxHeight: AnvilSpacing.commandPaletteMaxHeight - 76)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                scrollToSelected(proxy: proxy, index: newIndex)
            }
        }
    }

    // MARK: - Command Results

    @ViewBuilder
    private func commandResults(proxy: ScrollViewProxy) -> some View {
        if viewModel.filteredItems.isEmpty {
            emptyState(message: "No commands match \"\(viewModel.query.hasPrefix(">") ? String(viewModel.query.dropFirst()).trimmingCharacters(in: .whitespaces) : viewModel.query)\"")
        } else {
            ForEach(viewModel.groupedItems, id: \.category) { group in
                CommandSection(title: group.category.rawValue) {
                    ForEach(group.items, id: \.item.id) { entry in
                        CommandResultItem(
                            icon: entry.item.icon,
                            iconColor: entry.item.iconColor,
                            title: entry.item.title,
                            subtitle: entry.item.subtitle,
                            shortcut: entry.item.shortcut,
                            isSelected: viewModel.selectedIndex == entry.index,
                            matchedIndices: viewModel.matchedIndicesMap[entry.item.id] ?? []
                        )
                        .id(entry.item.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedIndex = entry.index
                            viewModel.execute(appState: appState)
                        }
                    }
                }
            }
        }
    }

    // MARK: - File Results

    @ViewBuilder
    private func fileResultsList(proxy: ScrollViewProxy) -> some View {
        if viewModel.isLoadingFiles {
            HStack {
                Spacer()
                VStack(spacing: AnvilSpacing.sm) {
                    ProgressView()
                    Text("Scanning files...")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                Spacer()
            }
            .padding(.vertical, AnvilSpacing.xl)
        } else if viewModel.filteredFileResults.isEmpty && !viewModel.query.isEmpty {
            emptyState(message: "No files match \"\(viewModel.query)\"")
        } else {
            let results = viewModel.filteredFileResults
            ForEach(Array(results.enumerated()), id: \.element.path) { index, file in
                FileResultItem(
                    file: file,
                    isSelected: viewModel.selectedIndex == index,
                    matchedIndices: viewModel.fileMatchedIndicesMap[file.path] ?? []
                )
                .id(file.path)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedIndex = index
                    viewModel.execute(appState: appState)
                }
            }

            if !viewModel.fileResults.isEmpty && viewModel.query.isEmpty {
                Text("\(viewModel.fileResults.count) files in project")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
            }
        }
    }

    // MARK: - Symbol Results

    @ViewBuilder
    private func symbolResultsList(proxy: ScrollViewProxy) -> some View {
        if viewModel.isLoadingFiles {
            HStack {
                Spacer()
                VStack(spacing: AnvilSpacing.sm) {
                    ProgressView()
                    Text("Indexing symbols...")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                Spacer()
            }
            .padding(.vertical, AnvilSpacing.xl)
        } else if viewModel.filteredSymbolResults.isEmpty {
            let effectiveQuery = viewModel.query.hasPrefix("@") ? String(viewModel.query.dropFirst()).trimmingCharacters(in: .whitespaces) : viewModel.query
            emptyState(message: effectiveQuery.isEmpty ? "Type to search symbols" : "No symbols match \"\(effectiveQuery)\"")
        } else {
            let results = viewModel.filteredSymbolResults
            ForEach(Array(results.enumerated()), id: \.offset) { index, symbol in
                SymbolResultItem(
                    symbol: symbol,
                    isSelected: viewModel.selectedIndex == index,
                    matchedIndices: viewModel.symbolMatchedIndicesMap["\(symbol.filePath):\(symbol.line)"] ?? []
                )
                .id("\(symbol.filePath):\(symbol.line)")
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedIndex = index
                    viewModel.execute(appState: appState)
                }
            }
        }
    }

    // MARK: - Helpers

    private func scrollToSelected(proxy: ScrollViewProxy, index: Int) {
        switch viewModel.paletteMode {
        case .commands:
            guard index < viewModel.filteredItems.count else { return }
            withAnimation { proxy.scrollTo(viewModel.filteredItems[index].id, anchor: .center) }
        case .files:
            guard index < viewModel.filteredFileResults.count else { return }
            withAnimation { proxy.scrollTo(viewModel.filteredFileResults[index].path, anchor: .center) }
        case .symbols:
            guard index < viewModel.filteredSymbolResults.count else { return }
            let s = viewModel.filteredSymbolResults[index]
            withAnimation { proxy.scrollTo("\(s.filePath):\(s.line)", anchor: .center) }
        }
    }

    private func emptyState(message: String) -> some View {
        HStack {
            Spacer()
            Text(message)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
            Spacer()
        }
        .padding(.vertical, AnvilSpacing.xl)
    }
}

// MARK: - Mode Hint Chip

private struct ModeHintChip: View {
    let label: String
    let shortcut: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(isActive ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isActive ? AnvilColor.accentBlue.opacity(0.15) : AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Text(label)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? AnvilColor.textPrimary : AnvilColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CommandSection

struct CommandSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)

            content
        }
    }
}

// MARK: - CommandResultItem

struct CommandResultItem: View {
    let icon: String
    var iconColor: Color? = nil
    let title: String
    var subtitle: String? = nil
    let shortcut: String?
    let isSelected: Bool
    var matchedIndices: Set<Int> = []

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(iconColor ?? (isSelected ? AnvilColor.accentBlue : AnvilColor.textSecondary))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                highlightedTitle
                    .font(AnvilFont.commandPaletteResult)

                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let shortcut {
                Text(shortcut)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, subtitle != nil ? AnvilSpacing.xs : AnvilSpacing.xs)
        .background(isSelected ? AnvilColor.selectionBackground : .clear)
    }

    private var highlightedTitle: Text {
        let baseColor = isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary
        let matchColor = AnvilColor.accentBlue

        if matchedIndices.isEmpty {
            return Text(title).foregroundColor(baseColor)
        }

        let chars = Array(title)
        var result = Text("")
        for (index, char) in chars.enumerated() {
            let segment = Text(String(char))
            if matchedIndices.contains(index) {
                result = result + segment.foregroundColor(matchColor).bold()
            } else {
                result = result + segment.foregroundColor(baseColor)
            }
        }
        return result
    }
}

// MARK: - FileResultItem

private struct FileResultItem: View {
    let file: FileResult
    let isSelected: Bool
    var matchedIndices: Set<Int> = []

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: file.icon)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                highlightedName
                    .font(.system(size: 13, weight: .regular))

                Text(file.relativePath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(isSelected ? AnvilColor.selectionBackground : .clear)
    }

    private var highlightedName: Text {
        let baseColor = isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary
        let matchColor = AnvilColor.accentBlue

        if matchedIndices.isEmpty {
            return Text(file.name).foregroundColor(baseColor)
        }

        let chars = Array(file.name)
        var result = Text("")
        for (index, char) in chars.enumerated() {
            let segment = Text(String(char))
            if matchedIndices.contains(index) {
                result = result + segment.foregroundColor(matchColor).bold()
            } else {
                result = result + segment.foregroundColor(baseColor)
            }
        }
        return result
    }
}

// MARK: - SymbolResultItem

private struct SymbolResultItem: View {
    let symbol: SymbolResult
    let isSelected: Bool
    var matchedIndices: Set<Int> = []

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: symbol.kindIcon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(symbol.kindColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                highlightedName
                    .font(.system(size: 13, weight: .regular))

                HStack(spacing: AnvilSpacing.xxs) {
                    Text(symbol.fileName)
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)

                    Text(":\(symbol.line)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }

            Spacer()

            Text(symbol.kind)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(symbol.kindColor.opacity(0.8))
                .padding(.horizontal, AnvilSpacing.xs)
                .padding(.vertical, 2)
                .background(symbol.kindColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(isSelected ? AnvilColor.selectionBackground : .clear)
    }

    private var highlightedName: Text {
        let baseColor = isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary
        let matchColor = AnvilColor.accentPurple

        if matchedIndices.isEmpty {
            return Text(symbol.name).foregroundColor(baseColor)
        }

        let chars = Array(symbol.name)
        var result = Text("")
        for (index, char) in chars.enumerated() {
            let segment = Text(String(char))
            if matchedIndices.contains(index) {
                result = result + segment.foregroundColor(matchColor).bold()
            } else {
                result = result + segment.foregroundColor(baseColor)
            }
        }
        return result
    }
}
