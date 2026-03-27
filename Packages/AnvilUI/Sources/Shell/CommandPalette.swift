import SwiftUI

public struct CommandPalette: View {
    @EnvironmentObject var appState: AppState
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

            // Palette
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(AnvilColor.textTertiary)

                    TextField("Search commands, files, work items...", text: $viewModel.query)
                        .textFieldStyle(.plain)
                        .font(AnvilFont.commandPaletteInput)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .focused($isSearchFocused)
                }
                .padding(AnvilSpacing.md)

                Divider()
                    .overlay(AnvilColor.borderSubtle)

                // Results
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.groupedItems, id: \.category) { group in
                                CommandSection(title: group.category.rawValue) {
                                    ForEach(group.items, id: \.item.id) { entry in
                                        CommandResultItem(
                                            icon: entry.item.icon,
                                            title: entry.item.title,
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
                    .frame(maxHeight: AnvilSpacing.commandPaletteMaxHeight - 52)
                    .onChange(of: viewModel.selectedIndex) { _, newIndex in
                        guard !viewModel.filteredItems.isEmpty,
                              newIndex >= 0,
                              newIndex < viewModel.filteredItems.count else { return }
                        withAnimation {
                            proxy.scrollTo(viewModel.filteredItems[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: AnvilSpacing.commandPaletteWidth)
            .background(AnvilColor.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
            .padding(.top, 100)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
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
}

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

struct CommandResultItem: View {
    let icon: String
    let title: String
    let shortcut: String?
    let isSelected: Bool
    var matchedIndices: Set<Int> = []

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textSecondary)
                .frame(width: 20)

            highlightedTitle
                .font(AnvilFont.commandPaletteResult)

            Spacer()

            if let shortcut {
                Text(shortcut)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(isSelected ? AnvilColor.selectionBackground : .clear)
    }

    private var highlightedTitle: Text {
        let baseColor = isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary
        let matchColor = AnvilColor.accentBlue

        if matchedIndices.isEmpty {
            return Text(title)
                .foregroundColor(baseColor)
        }

        let chars = Array(title)
        var result = Text("")
        for (index, char) in chars.enumerated() {
            let segment = Text(String(char))
            if matchedIndices.contains(index) {
                result = result + segment
                    .foregroundColor(matchColor)
                    .bold()
            } else {
                result = result + segment
                    .foregroundColor(baseColor)
            }
        }
        return result
    }
}
