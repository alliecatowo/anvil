import SwiftUI
import AppKit

struct SearchPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProjectSearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            searchHeader

            Divider()

            // Search inputs
            searchInputs

            Divider()

            // Results
            if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
                AnvilEmptyState(
                    icon: "magnifyingglass",
                    title: "No results",
                    message: "No matches found for \"\(viewModel.searchText)\""
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchText.isEmpty {
                AnvilEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "Search Project",
                    message: "Type to search across all project files"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultsList
            }
        }
        .background(.background)
        .frame(width: 320)
        .onAppear { viewModel.projectPath = appState.currentProjectPath }
        .onChange(of: appState.currentProjectPath) { _, newPath in
            viewModel.projectPath = newPath
        }
    }

    // MARK: - Header

    private var searchHeader: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.textTertiary)

            Text("Search")
                .font(.headline)

            Spacer()

            if viewModel.totalMatchCount > 0 {
                Text("\(viewModel.totalMatchCount) results in \(viewModel.fileCount) files")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Button {
                appState.isProjectSearchVisible = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
    }

    // MARK: - Search Inputs

    private var searchInputs: some View {
        VStack(spacing: AnvilSpacing.xs) {
            // Search row
            HStack(spacing: AnvilSpacing.xs) {
                // Expand/collapse replace
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isReplaceExpanded.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.isReplaceExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                // Search field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    TextField("Search", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.body)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Toggle buttons row
            HStack(spacing: AnvilSpacing.xs) {
                Spacer().frame(width: 16) // align with field

                searchToggle("Aa", isActive: $viewModel.matchCase, help: "Match Case")
                searchToggle("W", isActive: $viewModel.wholeWord, help: "Whole Word")
                searchToggle(".*", isActive: $viewModel.useRegex, help: "Use Regex")

                Spacer()
            }

            // Replace row
            if viewModel.isReplaceExpanded {
                HStack(spacing: AnvilSpacing.xs) {
                    Spacer().frame(width: 16)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        TextField("Replace", text: $viewModel.replaceText)
                            .textFieldStyle(.roundedBorder)
                            .font(AnvilFont.body)
                    }

                    Button("Replace All") {
                        viewModel.replaceAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.replaceText.isEmpty || viewModel.results.isEmpty)
                }
            }

            // File filter
            HStack(spacing: AnvilSpacing.xs) {
                Spacer().frame(width: 16)

                HStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    TextField("Files to include (e.g. *.swift, *.ts)", text: $viewModel.fileFilter)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.label)
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.results) { fileResult in
                    fileResultSection(fileResult)
                }
            }
        }
    }

    private func fileResultSection(_ fileResult: FileSearchResult) -> some View {
        VStack(spacing: 0) {
            // File header
            Button {
                viewModel.toggleFileCollapsed(fileResult.filePath)
            } label: {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: viewModel.collapsedFiles.contains(fileResult.filePath) ? "chevron.right" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .frame(width: 12)

                    Image(systemName: fileIconForPath(fileResult.filePath))
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.accentBlue)

                    Text(fileResult.fileName)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    Text(directoryPart(fileResult.filePath))
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(fileResult.matches.count)")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(AnvilColor.backgroundTertiary)
                        .cornerRadius(8)

                    if viewModel.isReplaceExpanded {
                        Button {
                            viewModel.replaceAllInFile(fileResult.filePath)
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(AnvilColor.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Replace all in this file")
                    }
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .frame(height: AnvilSpacing.listItemHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Match lines
            if !viewModel.collapsedFiles.contains(fileResult.filePath) {
                ForEach(fileResult.matches) { match in
                    matchRow(match, filePath: fileResult.filePath)
                }
            }
        }
    }

    private func matchRow(_ match: SearchMatch, filePath: String) -> some View {
        Button {
            openFileAtLine(filePath: filePath, line: match.lineNumber)
        } label: {
            HStack(spacing: AnvilSpacing.xs) {
                Text("\(match.lineNumber)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 32, alignment: .trailing)

                highlightedLineContent(match)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.leading, AnvilSpacing.md)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func highlightedLineContent(_ match: SearchMatch) -> some View {
        let line = match.lineContent.trimmingCharacters(in: .whitespaces)
        let searchLower = viewModel.matchCase ? viewModel.searchText : viewModel.searchText.lowercased()
        let lineLower = viewModel.matchCase ? line : line.lowercased()

        if let range = lineLower.range(of: searchLower) {
            let before = String(line[line.startIndex..<range.lowerBound])
            let matched = String(line[range])
            let after = String(line[range.upperBound...])

            HStack(spacing: 0) {
                Text(before)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AnvilColor.textSecondary)
                Text(matched)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AnvilColor.accentAmber)
                    .background(AnvilColor.accentAmber.opacity(0.15))
                Text(after)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AnvilColor.textSecondary)
            }
        } else {
            HStack(spacing: 0) {
                Text(line)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AnvilColor.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private func openFileAtLine(filePath: String, line: Int) {
        appState.pendingFileToOpen = filePath
        appState.pendingSymbolLine = line
        appState.switchSpace(.build)
    }

    // MARK: - Helpers

    private func searchToggle(_ label: String, isActive: Binding<Bool>, help: String) -> some View {
        Toggle(isOn: isActive) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .toggleStyle(.button)
        .controlSize(.mini)
        .help(help)
    }

    private func fileIconForPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "ts", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "js", "jsx": return "curlybraces"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "md": return "doc.richtext"
        case "json": return "curlybraces"
        case "yaml", "yml": return "list.bullet.indent"
        default: return "doc.text"
        }
    }

    private func directoryPart(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        if components.count > 1 {
            return components.dropLast().joined(separator: "/")
        }
        return ""
    }
}
