import SwiftUI

struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel

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

        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                // Line numbers gutter
                lineNumberGutter(lineCount: lines.count)

                // Divider between gutter and code
                Rectangle()
                    .fill(AnvilColor.borderSubtle)
                    .frame(width: 1)

                // Code content
                codeContent(lines: lines)
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }

    private func lineNumberGutter(lineCount: Int) -> some View {
        let gutterWidth = gutterWidth(for: lineCount)

        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...max(lineCount, 1), id: \.self) { lineNumber in
                Text("\(lineNumber)")
                    .font(AnvilFont.code)
                    .foregroundStyle(
                        lineNumber == viewModel.cursorLine
                            ? AnvilColor.textSecondary
                            : AnvilColor.textTertiary
                    )
                    .frame(width: gutterWidth, alignment: .trailing)
                    .frame(height: 20)
                    .padding(.trailing, AnvilSpacing.sm)
                    .background(
                        lineNumber == viewModel.cursorLine
                            ? AnvilColor.backgroundTertiary.opacity(0.5)
                            : Color.clear
                    )
            }
        }
        .padding(.leading, AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary.opacity(0.5))
    }

    private func codeContent(lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let lineNumber = index + 1

                highlightedLine(line)
                    .frame(height: 20, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, AnvilSpacing.md)
                    .padding(.trailing, AnvilSpacing.xxl)
                    .background(
                        lineNumber == viewModel.cursorLine
                            ? AnvilColor.selectionBackground.opacity(0.3)
                            : Color.clear
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.cursorLine = lineNumber
                    }
            }
        }
    }

    // MARK: - Syntax Highlighting

    private func highlightedLine(_ line: String) -> Text {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Comment line
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") {
            return Text(line)
                .font(AnvilFont.code)
                .foregroundColor(AnvilColor.textTertiary)
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

    // MARK: - Layout Helpers

    private func gutterWidth(for lineCount: Int) -> CGFloat {
        let digits = String(lineCount).count
        return CGFloat(max(digits, 2)) * 8 + 4
    }
}
