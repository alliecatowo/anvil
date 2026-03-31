import SwiftUI
import AppKit
import AnvilDomain
import AnvilEditor

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

    /// Language-aware syntax highlighter derived from the open file's extension.
    private var syntaxHighlighter: SyntaxHighlighter {
        let ext = viewModel.selectedFile?.name.components(separatedBy: ".").last ?? ""
        let lang = SyntaxHighlighter.language(forExtension: ext)
        return SyntaxHighlighter(language: lang)
    }

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
                .accessibilityHidden(true)

            Text("No File Open")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textSecondary)

            Text("Open a file from the sidebar to start editing")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnvilColor.backgroundPrimary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No file open. Open a file from the sidebar to start editing.")
    }

    // MARK: - Code View

    private func codeView(for file: EditorFile) -> some View {
        ZStack(alignment: .topLeading) {
            AnvilCodeEditor(viewModel: viewModel, file: file)

            // Inline edit overlay (positioned over the selected lines)
            InlineEditOverlay(viewModel: viewModel)

            // "No definition found" toast
            if let message = viewModel.definitionNotFoundMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .padding(.horizontal, AnvilSpacing.md)
                        .padding(.vertical, AnvilSpacing.xs)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .padding(.bottom, AnvilSpacing.lg)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.definitionNotFoundMessage)
                        .accessibilityLabel(message)
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .onChange(of: viewModel.cursorLine) { _, _ in
            viewModel.dismissCompletionPopup()
        }
        .onChange(of: viewModel.selectedFileId) { _, _ in
            viewModel.loadBlameForSelectedFile()
        }
    }

    /// Insert the accepted ghost text at the end of the current cursor line.
    private func insertGhostText(_ text: String, lines: [String]) {
        guard let file = viewModel.selectedFile,
              let fileIndex = viewModel.openFiles.firstIndex(where: { $0.id == file.id }) else { return }

        var mutableLines = lines
        let lineIdx = viewModel.cursorLine - 1
        guard lineIdx >= 0, lineIdx < mutableLines.count else { return }
        mutableLines[lineIdx] += text
        let newContent = mutableLines.joined(separator: "\n")
        let updated = EditorFile(
            name: file.name,
            path: file.path,
            content: newContent,
            language: file.language,
            relativePath: file.relativePath
        )
        viewModel.openFiles[fileIndex] = updated
        viewModel.selectedFileId = updated.id
    }

    // MARK: - Completion Popup Positioning

    /// Approximate X offset for the completion popup (below cursor column).
    private func completionPopupX(lines: [String]) -> CGFloat {
        let charWidth: CGFloat = 7.7
        let gutterWidth = gutterWidth(for: lines.count)
        let gutterExtra: CGFloat = AnvilSpacing.sm + (viewModel.codeFoldingEnabled ? 14 : 0) + 1 + AnvilSpacing.md + 3
        return gutterWidth + gutterExtra + CGFloat(viewModel.cursorColumn - 1) * charWidth
    }

    /// Y offset for the completion popup (below cursor line).
    private var completionPopupY: CGFloat {
        let lineHeight: CGFloat = 20
        return CGFloat(viewModel.cursorLine) * lineHeight + 2
    }

    // MARK: - Hover Popover Positioning

    /// X offset for hover popover (above hovered column).
    private func hoverPopoverX(lines: [String]) -> CGFloat {
        let charWidth: CGFloat = 7.7
        let gutterWidth = gutterWidth(for: lines.count)
        let gutterExtra: CGFloat = AnvilSpacing.sm + (viewModel.codeFoldingEnabled ? 14 : 0) + 1 + AnvilSpacing.md + 3
        return gutterWidth + gutterExtra + CGFloat(viewModel.hoverColumn - 1) * charWidth
    }

    /// Y offset for hover popover (above the hovered line).
    private var hoverPopoverY: CGFloat {
        let lineHeight: CGFloat = 20
        // Position above the line
        return CGFloat(viewModel.hoverLine - 1) * lineHeight - 4
    }

    /// Insert completion text at the cursor, replacing the word prefix.
    private func insertCompletionText(_ text: String, lines: [String]) {
        guard let file = viewModel.selectedFile,
              let fileIndex = viewModel.openFiles.firstIndex(where: { $0.id == file.id }) else { return }

        var mutableLines = lines
        let lineIdx = viewModel.cursorLine - 1
        guard lineIdx >= 0, lineIdx < mutableLines.count else { return }

        let line = mutableLines[lineIdx]
        let col = min(viewModel.cursorColumn - 1, line.count)

        // Find the word prefix at cursor to replace
        let prefixEnd = line.index(line.startIndex, offsetBy: col)
        var wordStart = prefixEnd
        while wordStart > line.startIndex {
            let prev = line.index(before: wordStart)
            let c = line[prev]
            if c.isLetter || c.isNumber || c == "_" {
                wordStart = prev
            } else {
                break
            }
        }

        let before = String(line[line.startIndex..<wordStart])
        let after = String(line[prefixEnd...])
        mutableLines[lineIdx] = before + text + after

        let newContent = mutableLines.joined(separator: "\n")
        let updated = EditorFile(
            name: file.name,
            path: file.path,
            content: newContent,
            language: file.language,
            relativePath: file.relativePath
        )
        viewModel.openFiles[fileIndex] = updated
        viewModel.selectedFileId = updated.id
        viewModel.cursorColumn = (before.count + text.count) + 1
    }

    /// Trigger ghost completion fetch after cursor moves.
    private func triggerGhostCompletion(fileContent: String) {
        viewModel.onCursorPositionChanged(
            fileContent: fileContent,
            cursorLine: viewModel.cursorLine,
            cursorChar: viewModel.cursorColumn
        )
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
                            .accessibilityLabel(isCollapsed ? "Expand code fold at line \(lineNumber)" : "Collapse code fold at line \(lineNumber)")
                            .accessibilityAddTraits(.isButton)
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

    // MARK: - Blame Gutter

    @State private var blamePopoverLine: Int?

    private func blameGutter(lines: [String], foldRegions: [EditorViewModel.FoldRegion]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(1...max(lines.count, 1), id: \.self) { lineNumber in
                if !viewModel.isLineHidden(lineNumber, regions: foldRegions) {
                    if let blame = viewModel.blameLines[lineNumber] {
                        let compact = EditorViewModel.compactBlame(blame)
                        Text(compact)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(1)
                            .frame(width: 120, height: 20, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                blamePopoverLine = lineNumber
                            }
                            .popover(isPresented: Binding(
                                get: { blamePopoverLine == lineNumber },
                                set: { if !$0 { blamePopoverLine = nil } }
                            )) {
                                blamePopoverContent(blame)
                            }
                            .accessibilityLabel("Blame: \(blame.author), \(blame.commitHash.prefix(7))")
                    } else {
                        Color.clear
                            .frame(width: 120, height: 20)
                    }
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary.opacity(0.3))
    }

    private func blamePopoverContent(_ blame: BlameLine) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: "person.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(AnvilColor.accentBlue)
                Text(blame.author)
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)
            }

            HStack(spacing: AnvilSpacing.xs) {
                Text(String(blame.commitHash.prefix(7)))
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.accentPurple)
                Text(blame.date, style: .date)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                Text(blame.date, style: .time)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Text(blame.content)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .lineLimit(3)
        }
        .padding(AnvilSpacing.md)
        .frame(minWidth: 280, maxWidth: 400)
    }

    // MARK: - Git Change Indicator

    @ViewBuilder
    private func gitChangeIndicator(_ change: GitLineChange) -> some View {
        switch change {
        case .added:
            RoundedRectangle(cornerRadius: 1)
                .fill(AnvilColor.accentGreen)
                .frame(width: 3)
                .accessibilityLabel("Line added")
        case .modified:
            RoundedRectangle(cornerRadius: 1)
                .fill(AnvilColor.accentBlue)
                .frame(width: 3)
                .accessibilityLabel("Line modified")
        case .deleted:
            Triangle()
                .fill(AnvilColor.accentRed)
                .frame(width: 6, height: 6)
                .accessibilityLabel("Line deleted")
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

                    HStack(spacing: 0) {
                        highlightedLine(line)

                        // Ghost text overlay: show inline after cursor line content
                        if isCursor, let ghost = viewModel.ghostCompletion {
                            Text(ghost)
                                .font(AnvilFont.code)
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineLimit(1)
                                .allowsHitTesting(false)
                                .accessibilityLabel("Ghost completion: \(ghost)")
                        }
                    }
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 20, alignment: .leading)
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
                        .overlay(alignment: .bottomLeading) {
                            let diags = viewModel.diagnosticsOnLine(lineNumber)
                            if !diags.isEmpty {
                                diagnosticUnderline(diags)
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
                                    if NSEvent.modifierFlags.contains(.command) {
                                        handleCmdClick(lineNumber: lineNumber, line: line)
                                    } else {
                                        handleLineClick(lineNumber: lineNumber)
                                    }
                                }
                        )
                        .accessibilityLabel("Line \(lineNumber)")
                        .accessibilityAddTraits(.isButton)

                    // Collapsed fold placeholder in code area
                    if isCollapsed {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 10))
                                .foregroundStyle(AnvilColor.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .frame(height: 16)
                        .padding(.horizontal, AnvilSpacing.md)
                        .background(AnvilColor.backgroundTertiary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .accessibilityLabel("Collapsed code region")
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

    // MARK: - Diagnostic Underline

    private func diagnosticUnderline(_ diagnostics: [LSPDiagnostic]) -> some View {
        let worstSeverity = diagnostics.map(\.severity).min(by: { $0.rawValue < $1.rawValue }) ?? .hint
        let color: Color = switch worstSeverity {
        case .error:       AnvilColor.accentRed
        case .warning:     AnvilColor.accentAmber
        case .information: AnvilColor.accentBlue
        case .hint:        AnvilColor.textTertiary
        }

        return ZStack(alignment: .bottomLeading) {
            // Squiggly underline approximated with a dashed line
            Path { path in
                let charWidth: CGFloat = 7.7
                // Underline from first diagnostic's character to end of word
                let startCol = diagnostics.map(\.character).min() ?? 0
                let endCol = diagnostics.map(\.endCharacter).max() ?? (startCol + 10)
                let x0 = CGFloat(startCol) * charWidth
                let x1 = max(CGFloat(endCol) * charWidth, x0 + charWidth * 3)

                var x = x0
                var up = true
                path.move(to: CGPoint(x: x, y: up ? 0 : 2))
                while x < x1 {
                    x += 3
                    up.toggle()
                    path.addLine(to: CGPoint(x: min(x, x1), y: up ? 0 : 2))
                }
            }
            .stroke(color, lineWidth: 1.2)
            .frame(height: 3)
        }
        .allowsHitTesting(false)
        .accessibilityLabel(diagnostics.map(\.message).joined(separator: "; "))
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

    // MARK: - Selection Text Helper

    /// Returns the currently selected text (from inline edit range), or nil if no multi-char selection.
    private func currentSelectionText(lines: [String]) -> String? {
        let range = viewModel.inlineEditSelectedRange
        guard range.count > 1 || (range.count == 1 && range.lowerBound != range.upperBound) else { return nil }
        let startIdx = max(range.lowerBound - 1, 0)
        let endIdx = min(range.upperBound - 1, lines.count - 1)
        guard startIdx <= endIdx, startIdx < lines.count else { return nil }
        let selectedLines = lines[startIdx...endIdx]
        return selectedLines.joined(separator: "\n")
    }

    // MARK: - Cmd+Click Go-to-Definition

    /// Handle Cmd+Click on a code line to trigger go-to-definition.
    /// Uses the clicked line and approximates column from cursor position.
    private func handleCmdClick(lineNumber: Int, line: String) {
        // Move cursor to the clicked line first
        viewModel.cursorLine = lineNumber
        // Use the current cursor column (best approximation for click position)
        let col = min(viewModel.cursorColumn, line.count + 1)
        viewModel.goToDefinition(line: lineNumber, column: col)
    }

    // MARK: - Syntax Highlighting (powered by SyntaxHighlighter)

    private func highlightedLine(_ line: String) -> Text {
        let wsMode = viewModel.whitespaceMode

        if wsMode != .none {
            return tokenizeLineWithWhitespace(line, wsMode: wsMode)
        }

        return tokenizeLine(line)
    }

    private func tokenizeLine(_ line: String) -> Text {
        let tokens = syntaxHighlighter.tokenize(line)
        var result = Text("")
        for token in tokens {
            result = result + Text(token.text)
                .font(AnvilFont.code)
                .foregroundColor(colorForTokenKind(token.kind))
        }
        return result
    }

    private func colorForTokenKind(_ kind: SyntaxTokenKind) -> Color {
        switch kind {
        case .keyword:      AnvilColor.accentPurple
        case .type:         AnvilColor.accentTeal
        case .string:       AnvilColor.accentGreen
        case .number:       AnvilColor.accentAmber
        case .comment:      AnvilColor.textTertiary
        case .function:     AnvilColor.accentBlue
        case .property:     AnvilColor.accentBlue.opacity(0.85)
        case .operator:     AnvilColor.textSecondary
        case .preprocessor: AnvilColor.accentAmber
        case .attribute:    AnvilColor.accentPurple.opacity(0.8)
        case .plain:        AnvilColor.textPrimary
        }
    }

    // MARK: - Whitespace Visualization

    /// Tokenizes a line using SyntaxHighlighter, with whitespace characters rendered as visible symbols.
    private func tokenizeLineWithWhitespace(_ line: String, wsMode: WhitespaceMode) -> Text {
        let leadingCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
        let trailingCount = line.reversed().prefix(while: { $0 == " " || $0 == "\t" }).count
        let trailingStart = line.count - trailingCount

        // Get syntax tokens first
        let tokens = syntaxHighlighter.tokenize(line)
        var result = Text("")
        var charOffset = 0

        for token in tokens {
            for char in token.text {
                let isWS = char == " " || char == "\t"
                let shouldVisualize: Bool
                if wsMode == .all {
                    shouldVisualize = isWS
                } else {
                    shouldVisualize = isWS && (charOffset < leadingCount || charOffset >= trailingStart)
                }

                if shouldVisualize {
                    let symbol: String = char == "\t" ? "\u{2192}" : "\u{00B7}"
                    result = result + Text(symbol)
                        .font(AnvilFont.code)
                        .foregroundColor(AnvilColor.textTertiary.opacity(0.4))
                } else {
                    result = result + Text(String(char))
                        .font(AnvilFont.code)
                        .foregroundColor(colorForTokenKind(token.kind))
                }
                charOffset += 1
            }
        }

        return result
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

// MARK: - Hover Popover

struct HoverPopover: View {
    let result: LSPHoverResult

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
            // Type signature in code font
            Text(result.typeSignature)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .textSelection(.enabled)

            // Documentation in body font
            if let doc = result.documentation {
                Divider()

                Text(doc)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .lineLimit(8)
            }
        }
        .padding(AnvilSpacing.sm)
        .frame(maxWidth: 400, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hover documentation: \(result.typeSignature)")
    }
}
