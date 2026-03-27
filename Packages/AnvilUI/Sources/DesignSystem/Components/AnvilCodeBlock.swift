import SwiftUI

public struct AnvilCodeBlock: View {
    let code: String
    let language: String?
    let showLineNumbers: Bool

    public init(code: String, language: String? = nil, showLineNumbers: Bool = true) {
        self.code = code
        self.language = language
        self.showLineNumbers = showLineNumbers
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language {
                HStack {
                    Spacer()
                    Text(language)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .padding(.horizontal, AnvilSpacing.sm)
                        .padding(.vertical, AnvilSpacing.xxs)
                }
            }

            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    if showLineNumbers {
                        lineNumberGutter
                    }
                    codeContent
                }
                .padding(AnvilSpacing.sm)
            }
            .frame(maxHeight: 400)

            HStack {
                Spacer()
                copyButton
                    .padding(AnvilSpacing.xs)
            }
        }
        .background(AnvilColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(AnvilColor.borderSubtle, lineWidth: 1)
        )
    }

    private var lines: [String] {
        code.components(separatedBy: "\n")
    }

    private var lineNumberGutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(minWidth: 30, alignment: .trailing)
                    .padding(.trailing, AnvilSpacing.sm)
            }
        }
    }

    private var codeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                highlightedLine(line)
            }
        }
    }

    private func highlightedLine(_ line: String) -> some View {
        Group {
            if language?.lowercased() == "swift" {
                swiftHighlightedText(line)
            } else {
                Text(line.isEmpty ? " " : line)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
            }
        }
    }

    // MARK: - Basic Swift Syntax Highlighting

    private static let swiftKeywords: Set<String> = [
        "func", "let", "var", "class", "struct", "import", "if", "return",
        "else", "guard", "switch", "case", "enum", "protocol", "extension",
        "public", "private", "internal", "static", "self", "true", "false",
        "nil", "for", "in", "while", "break", "continue", "throws", "throw",
        "try", "catch", "async", "await", "some", "any", "init", "deinit",
    ]

    private func swiftHighlightedText(_ line: String) -> Text {
        // Handle full-line comments
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") {
            return Text(line.isEmpty ? " " : line)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
        }

        var result = Text("")
        var remaining = line[line.startIndex...]

        while !remaining.isEmpty {
            // Check for string literal
            if remaining.first == "\"" {
                let stringEnd = findStringEnd(in: remaining)
                let segment = String(remaining[remaining.startIndex...stringEnd])
                result = result + Text(segment)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.accentGreen)
                remaining = remaining[remaining.index(after: stringEnd)...]
                continue
            }

            // Check for inline comment
            if remaining.hasPrefix("//") {
                result = result + Text(String(remaining))
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textTertiary)
                break
            }

            // Check for word boundary (keyword candidate)
            if remaining.first?.isLetter == true || remaining.first == "_" {
                let wordEnd = remaining.firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "_" }) ?? remaining.endIndex
                let word = String(remaining[remaining.startIndex..<wordEnd])

                if Self.swiftKeywords.contains(word) {
                    result = result + Text(word)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentPurple)
                } else {
                    result = result + Text(word)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textPrimary)
                }
                remaining = remaining[wordEnd...]
                continue
            }

            // Default: consume one character
            result = result + Text(String(remaining.first!))
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
            remaining = remaining[remaining.index(after: remaining.startIndex)...]
        }

        if line.isEmpty {
            return Text(" ").font(AnvilFont.code)
        }

        return result
    }

    private func findStringEnd(in text: Substring) -> String.Index {
        var index = text.index(after: text.startIndex)
        while index < text.endIndex {
            if text[index] == "\\" {
                index = text.index(after: index)
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                continue
            }
            if text[index] == "\"" {
                return index
            }
            index = text.index(after: index)
        }
        return text.index(before: text.endIndex)
    }

    // MARK: - Copy

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .buttonStyle(.plain)
        .help("Copy code")
    }
}
