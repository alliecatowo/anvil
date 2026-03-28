import SwiftUI
import AppKit

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel

    @State private var selectionAnchor: Int?

    private let swiftKeywords: Set<String> = [
        "func", "let", "var", "class", "struct", "import", "if", "else",
        "return", "for", "in", "switch", "case", "public", "private",
        "protocol", "enum", "static", "async", "await", "throws", "throw",
        "try", "guard", "defer", "nil", "self", "true", "false", "init",
        "override", "mutating", "some", "any", "where", "extension",
    ]

    var body: some View {
        Group {
            if let file = viewModel.selectedFile {
                codeView(for: file)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Image(systemName: "doc.text")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))

            Text("No File Open")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textSecondary)

            Text("Open a file from the sidebar to start editing")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Code View

    private func codeView(for file: EditorFile) -> some View {
        let lines = file.content.components(separatedBy: "\n")
        let selectedRange: ClosedRange<Int>? = viewModel.inlineEditPhase != .hidden
            ? viewModel.inlineEditSelectedRange
            : nil
        let foldRegions = viewModel.foldRegions(for: lines)

        let scrollAxes: Axis.Set = viewModel.isWordWrapEnabled ? [.vertical] : [.horizontal, .vertical]

        return ZStack(alignment: .topLeading) {
            ScrollView(scrollAxes) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers gutter
                    lineNumberGutter(lines: lines, selectedRange: selectedRange, foldRegions: foldRegions)

                    // Divider between gutter and code
                    Rectangle()
                        .fill(AnvilColor.borderSubtle)
                        .frame(width: 1)

                    // Code content
                    codeContent(lines: lines, selectedRange: selectedRange, foldRegions: foldRegions)
                }
            }

            // Inline edit overlay (positioned over the selected lines)
            InlineEditOverlay(viewModel: viewModel)
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Line Number Gutter

    private func lineNumberGutter(lines: [String], selectedRange: ClosedRange<Int>?, foldRegions: [EditorViewModel.FoldRegion] = []) -> some View {
        let gutterWidth = gutterWidth(for: lines.count)

        return LazyVStack(alignment: .trailing, spacing: 0) {
            ForEach(1...max(lines.count, 1), id: \.self) { lineNumber in
                if !viewModel.isLineHidden(lineNumber, regions: foldRegions) {
                    let isSelected = selectedRange?.contains(lineNumber) ?? false
                    let isCursor = lineNumber == viewModel.cursorLine && selectedRange == nil
                    let foldRegion = viewModel.foldRegionStarting(at: lineNumber, regions: foldRegions)
                    let isCollapsed = viewModel.collapsedLines.contains(lineNumber)

                    HStack(spacing: 0) {
                        // Selection bar
                        if isSelected {
                            Rectangle()
                                .fill(AnvilColor.accentBlue)
                                .frame(width: 3)
                        }

                        // Fold indicator
                        if let _ = foldRegion, viewModel.codeFoldingEnabled {
                            Button {
                                withAnimation(AnvilAnimation.standard) {
                                    viewModel.toggleFold(at: lineNumber)
                                }
                            } label: {
                                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(AnvilColor.textTertiary)
                                    .frame(width: 14, height: 20)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Spacer(minLength: 0)
                                .frame(width: viewModel.codeFoldingEnabled ? 14 : 0)
                        }

                        Text("\(lineNumber)")
                            .font(AnvilFont.code)
                            .foregroundStyle(
                                isSelected ? AnvilColor.accentBlue :
                                isCursor ? AnvilColor.textSecondary :
                                AnvilColor.textTertiary
                            )
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, AnvilSpacing.sm)

                        // Git change indicator
                        if viewModel.showGitGutter, let change = viewModel.gitLineChanges[lineNumber] {
                            gitChangeIndicator(change)
                        } else {
                            Color.clear.frame(width: 3)
                        }
                    }
                    .frame(height: 20)
                    .background(
                        isSelected
                            ? AnvilColor.accentBlue.opacity(0.08)
                            : isCursor
                                ? AnvilColor.backgroundTertiary.opacity(0.5)
                                : Color.clear
                    )

                    // Collapsed fold placeholder
                    if isCollapsed, let region = foldRegion {
                        HStack(spacing: AnvilSpacing.xs) {
                            Text("...")
                                .font(AnvilFont.code)
                                .foregroundStyle(AnvilColor.textTertiary)
                            Text("\(region.endLine - region.startLine) lines")
                                .font(.system(size: 10))
                                .foregroundStyle(AnvilColor.textTertiary.opacity(0.6))
                        }
                        .frame(height: 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(AnvilColor.backgroundTertiary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(.leading, AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary.opacity(0.5))
    }

    // MARK: - Git Change Indicator

    @ViewBuilder
    private func gitChangeIndicator(_ change: GitLineChange) -> some View {
        switch change {
        case .added:
            RoundedRectangle(cornerRadius: 1)
                .fill(AnvilColor.accentGreen)
                .frame(width: 3)
        case .modified:
            RoundedRectangle(cornerRadius: 1)
                .fill(AnvilColor.accentBlue)
                .frame(width: 3)
        case .deleted:
            Triangle()
                .fill(AnvilColor.accentRed)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Code Content

    private func codeContent(lines: [String], selectedRange: ClosedRange<Int>?, foldRegions: [EditorViewModel.FoldRegion] = []) -> some View {
        let activeIndent = viewModel.showIndentGuides
            ? activeIndentLevel(lines: lines, cursorLine: viewModel.cursorLine)
            : 0

        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let lineNumber = index + 1
                if !viewModel.isLineHidden(lineNumber, regions: foldRegions) {
                    let isSelected = selectedRange?.contains(lineNumber) ?? false
                    let isCursor = lineNumber == viewModel.cursorLine && selectedRange == nil
                    let isCollapsed = viewModel.collapsedLines.contains(lineNumber)

                    highlightedLine(line)
                        .frame(height: 20, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, AnvilSpacing.md)
                        .padding(.trailing, AnvilSpacing.xxl)
                        .overlay(alignment: .leading) {
                            if viewModel.showIndentGuides {
                                indentGuides(
                                    for: line,
                                    activeLevel: activeIndent
                                )
                                .padding(.leading, AnvilSpacing.md)
                            }
                        }
                        .overlay(alignment: .leading) {
                            let bracketCols = viewModel.bracketHighlightColumns(forLine: lineNumber)
                            if !bracketCols.isEmpty {
                                bracketHighlights(columns: bracketCols)
                                    .padding(.leading, AnvilSpacing.md)
                            }
                        }
                        .background(
                            lineBackground(
                                lineNumber: lineNumber,
                                isSelected: isSelected,
                                isCursor: isCursor
                            )
                        )
                        .contentShape(Rectangle())
                        .gesture(
                            TapGesture()
                                .onEnded {
                                    handleLineClick(lineNumber: lineNumber)
                                }
                        )

                    // Collapsed fold placeholder in code area
                    if isCollapsed {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 10))
                                .foregroundStyle(AnvilColor.textTertiary)
                        }
                        .frame(height: 16)
                        .padding(.horizontal, AnvilSpacing.md)
                        .background(AnvilColor.backgroundTertiary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
    }

    // MARK: - Indent Guides

    /// Returns the indent level of a line (number of indentation stops).
    private func indentLevel(of line: String) -> Int {
        let tabSize = viewModel.tabSize
        var spaces = 0
        for char in line {
            if char == " " {
                spaces += 1
            } else if char == "\t" {
                spaces += tabSize
            } else {
                break
            }
        }
        return spaces / max(tabSize, 1)
    }

    /// Determines the active indent level based on the cursor line's indentation.
    private func activeIndentLevel(lines: [String], cursorLine: Int) -> Int {
        let index = cursorLine - 1
        guard index >= 0 && index < lines.count else { return 0 }
        let level = indentLevel(of: lines[index])
        // If the cursor line is blank/empty, look at surrounding lines for context
        if lines[index].trimmingCharacters(in: .whitespaces).isEmpty && level == 0 {
            // Search backward for a non-empty line
            for i in stride(from: index - 1, through: 0, by: -1) {
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    return indentLevel(of: lines[i])
                }
            }
        }
        return level
    }

    /// Renders vertical indent guide lines for a given line.
    private func indentGuides(for line: String, activeLevel: Int) -> some View {
        let lineLevel = indentLevel(of: line)
        // Show guides for all indentation levels visible on this line.
        // For a line at level 3, show guides at levels 1, 2, 3.
        // For blank lines, use the maximum of surrounding context (we approximate with lineLevel).
        let maxLevel = max(lineLevel, line.trimmingCharacters(in: .whitespaces).isEmpty ? activeLevel : lineLevel)
        let charWidth: CGFloat = 7.7 // approximate monospace character width at code font size
        let tabSize = CGFloat(viewModel.tabSize)

        return ZStack(alignment: .leading) {
            ForEach(1...max(maxLevel, 1), id: \.self) { level in
                if level <= maxLevel {
                    Rectangle()
                        .fill(
                            level == activeLevel
                                ? AnvilColor.textTertiary.opacity(0.35)
                                : AnvilColor.textTertiary.opacity(0.12)
                        )
                        .frame(width: 1)
                        .offset(x: CGFloat(level - 1) * tabSize * charWidth + tabSize * charWidth * 0.5)
                }
            }
        }
        .frame(height: 20)
        .allowsHitTesting(false)
    }

    // MARK: - Bracket Matching Highlights

    private func bracketHighlights(columns: Set<Int>) -> some View {
        let charWidth: CGFloat = 7.7
        return ZStack(alignment: .leading) {
            ForEach(Array(columns), id: \.self) { col in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AnvilColor.accentAmber.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(AnvilColor.accentAmber.opacity(0.4), lineWidth: 1)
                    )
                    .frame(width: charWidth, height: 18)
                    .offset(x: CGFloat(col) * charWidth)
            }
        }
        .frame(height: 20)
        .allowsHitTesting(false)
    }

    // MARK: - Line Click Handling

    private func handleLineClick(lineNumber: Int) {
        guard viewModel.inlineEditPhase == .hidden else { return }

        if let anchor = selectionAnchor {
            // Extend selection from anchor
            let start = min(anchor, lineNumber)
            let end = max(anchor, lineNumber)
            viewModel.inlineEditSelectedRange = start...end
            viewModel.cursorLine = lineNumber
        } else if NSEvent.modifierFlags.contains(.shift) {
            // Shift-click: select from cursor to clicked line
            let start = min(viewModel.cursorLine, lineNumber)
            let end = max(viewModel.cursorLine, lineNumber)
            viewModel.inlineEditSelectedRange = start...end
            selectionAnchor = viewModel.cursorLine
            viewModel.cursorLine = lineNumber
        } else {
            // Plain click: move cursor, clear selection
            viewModel.cursorLine = lineNumber
            viewModel.inlineEditSelectedRange = lineNumber...lineNumber
            selectionAnchor = nil
        }
    }

    // MARK: - Syntax Highlighting

    private func highlightedLine(_ line: String) -> Text {
        let wsMode = viewModel.whitespaceMode
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Comment line
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") {
            if wsMode != .none {
                return tokenizeLineWithWhitespace(line, wsMode: wsMode, isComment: true)
            }
            return Text(line)
                .font(AnvilFont.code)
                .foregroundColor(AnvilColor.textTertiary)
        }

        if wsMode != .none {
            return tokenizeLineWithWhitespace(line, wsMode: wsMode, isComment: false)
        }

        // Tokenize and color
        return tokenizeLine(line)
    }

    private func tokenizeLine(_ line: String) -> Text {
        var result = Text("")
        var current = line.startIndex
        let end = line.endIndex

        while current < end {
            let char = line[current]

            // String literals
            if char == "\"" {
                let stringResult = consumeString(line, from: current)
                result = result + Text(stringResult.text)
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.accentGreen)
                current = stringResult.end
            }
            // Numbers
            else if char.isNumber && (current == line.startIndex || !line[line.index(before: current)].isLetter) {
                let numResult = consumeNumber(line, from: current)
                result = result + Text(numResult.text)
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.accentAmber)
                current = numResult.end
            }
            // Words (keywords or identifiers)
            else if char.isLetter || char == "_" || char == "@" {
                let wordResult = consumeWord(line, from: current)
                let color: Color = swiftKeywords.contains(wordResult.text)
                    ? AnvilColor.accentPurple
                    : AnvilColor.textPrimary
                result = result + Text(wordResult.text)
                    .font(AnvilFont.code)
                    .foregroundColor(color)
                current = wordResult.end
            }
            // Inline comment
            else if char == "/" && line.index(after: current) < end && line[line.index(after: current)] == "/" {
                let remaining = String(line[current...])
                result = result + Text(remaining)
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.textTertiary)
                current = end
            }
            // Whitespace and punctuation
            else {
                result = result + Text(String(char))
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.textPrimary)
                current = line.index(after: current)
            }
        }

        return result
    }

    // MARK: - Whitespace Visualization

    /// Tokenizes a line with whitespace characters rendered as visible symbols.
    private func tokenizeLineWithWhitespace(_ line: String, wsMode: WhitespaceMode, isComment: Bool) -> Text {
        let leadingCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
        let trailingCount = line.reversed().prefix(while: { $0 == " " || $0 == "\t" }).count
        let trailingStart = line.count - trailingCount

        var result = Text("")
        var current = line.startIndex
        let end = line.endIndex

        while current < end {
            let i = line.distance(from: line.startIndex, to: current)
            let char = line[current]
            let isWS = char == " " || char == "\t"

            let shouldVisualize: Bool
            if wsMode == .all {
                shouldVisualize = isWS
            } else {
                shouldVisualize = isWS && (i < leadingCount || i >= trailingStart)
            }

            if shouldVisualize {
                let symbol: String = char == "\t" ? "\u{2192}" : "\u{00B7}"
                result = result + Text(symbol)
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.textTertiary.opacity(0.4))
                current = line.index(after: current)
            } else if isComment {
                result = result + Text(String(char))
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.textTertiary)
                current = line.index(after: current)
            } else if char == "\"" {
                let stringResult = consumeString(line, from: current)
                result = result + Text(stringResult.text)
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.accentGreen)
                current = stringResult.end
            } else if char.isNumber && (current == line.startIndex || !line[line.index(before: current)].isLetter) {
                let numResult = consumeNumber(line, from: current)
                result = result + Text(numResult.text)
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.accentAmber)
                current = numResult.end
            } else if char.isLetter || char == "_" || char == "@" {
                let wordResult = consumeWord(line, from: current)
                let color: Color = swiftKeywords.contains(wordResult.text)
                    ? AnvilColor.accentPurple
                    : AnvilColor.textPrimary
                result = result + Text(wordResult.text)
                    .font(AnvilFont.code)
                    .foregroundColor(color)
                current = wordResult.end
            } else if char == "/" && line.index(after: current) < end && line[line.index(after: current)] == "/" {
                let remaining = String(line[current...])
                result = result + Text(remaining)
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.textTertiary)
                current = end
            } else {
                result = result + Text(String(char))
                    .font(AnvilFont.code)
                    .foregroundColor(AnvilColor.textPrimary)
                current = line.index(after: current)
            }
        }

        return result
    }

    // MARK: - Tokenizer Helpers

    private func consumeString(_ line: String, from start: String.Index) -> (text: String, end: String.Index) {
        var pos = line.index(after: start)
        while pos < line.endIndex {
            if line[pos] == "\\" && line.index(after: pos) < line.endIndex {
                pos = line.index(pos, offsetBy: 2)
                continue
            }
            if line[pos] == "\"" {
                pos = line.index(after: pos)
                return (String(line[start..<pos]), pos)
            }
            pos = line.index(after: pos)
        }
        return (String(line[start..<line.endIndex]), line.endIndex)
    }

    private func consumeNumber(_ line: String, from start: String.Index) -> (text: String, end: String.Index) {
        var pos = start
        while pos < line.endIndex && (line[pos].isNumber || line[pos] == ".") {
            pos = line.index(after: pos)
        }
        return (String(line[start..<pos]), pos)
    }

    private func consumeWord(_ line: String, from start: String.Index) -> (text: String, end: String.Index) {
        var pos = start
        while pos < line.endIndex && (line[pos].isLetter || line[pos].isNumber || line[pos] == "_" || line[pos] == "@") {
            pos = line.index(after: pos)
        }
        return (String(line[start..<pos]), pos)
    }

    // MARK: - Find Match Highlighting

    private func lineBackground(lineNumber: Int, isSelected: Bool, isCursor: Bool) -> Color {
        let hasMatch = !viewModel.matchRangesOnLine(lineNumber).isEmpty
        let hasCurrentMatch = viewModel.matchRangesOnLine(lineNumber).contains(where: {
            viewModel.isCurrentMatch(line: lineNumber, range: $0)
        })

        if hasCurrentMatch {
            return AnvilColor.accentAmber.opacity(0.15)
        } else if hasMatch {
            return AnvilColor.accentAmber.opacity(0.06)
        } else if isSelected {
            return AnvilColor.accentBlue.opacity(0.06)
        } else if isCursor {
            return AnvilColor.selectionBackground.opacity(0.3)
        }
        return .clear
    }

    // MARK: - Layout Helpers

    private func gutterWidth(for lineCount: Int) -> CGFloat {
        let digits = String(lineCount).count
        return CGFloat(max(digits, 2)) * 8 + 4
    }
}
