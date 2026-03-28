import SwiftUI
import AnvilDomain

/// A code block that renders progressively as content streams in.
/// Shows a typing cursor at the end when streaming is active.
struct StreamingCodeBlock: View {
    let code: String
    let language: String?
    let isStreaming: Bool

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                // Language label header
                HStack {
                    if let language, !language.isEmpty {
                        Text(language)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    Spacer()
                    if isStreaming {
                        HStack(spacing: AnvilSpacing.xxs) {
                            StreamingDot()
                            Text("Streaming...")
                                .font(.system(size: 10))
                                .foregroundStyle(AnvilColor.accentPurple)
                        }
                    } else {
                        copyButton
                    }
                }
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xxs)

                Divider()

                // Code content with line numbers and highlighting
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 0) {
                        // Line number gutter
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                                Text("\(index + 1)")
                                    .font(AnvilFont.code)
                                    .foregroundStyle(AnvilColor.textTertiary)
                                    .frame(minWidth: 30, alignment: .trailing)
                                    .padding(.trailing, AnvilSpacing.sm)
                            }
                        }

                        // Code with highlighting
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                HStack(spacing: 0) {
                                    highlightedLine(line)

                                    // Streaming cursor on the last line
                                    if isStreaming && index == lines.count - 1 {
                                        StreamingCursor()
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    .padding(AnvilSpacing.sm)
                }
                .frame(maxHeight: 400)
            }
        }
    }

    // MARK: - Lines

    private var lines: [String] {
        let result = code.components(separatedBy: "\n")
        // Ensure at least one line for empty blocks
        return result.isEmpty ? [""] : result
    }

    // MARK: - Syntax Highlighting

    private static let keywords: Set<String> = [
        // Swift
        "func", "let", "var", "class", "struct", "import", "if", "return",
        "else", "guard", "switch", "case", "enum", "protocol", "extension",
        "public", "private", "internal", "static", "self", "true", "false",
        "nil", "for", "in", "while", "break", "continue", "throws", "throw",
        "try", "catch", "async", "await", "some", "any", "init", "deinit",
        // TypeScript/JS
        "const", "function", "export", "default", "from", "new", "this",
        "type", "interface", "implements", "extends", "abstract", "readonly",
        // Python
        "def", "class", "self", "None", "True", "False", "and", "or", "not",
        "elif", "except", "finally", "lambda", "yield", "with", "as", "pass",
        // Rust
        "fn", "impl", "use", "mod", "pub", "crate", "mut", "ref", "match",
        "where", "trait", "unsafe", "move", "loop",
    ]

    private func highlightedLine(_ line: String) -> Text {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Full-line comment
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
            return Text(line.isEmpty ? " " : line)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
        }

        var result = Text("")
        var remaining = line[line.startIndex...]

        while !remaining.isEmpty {
            // String literal
            if remaining.first == "\"" {
                let endIdx = findStringEnd(in: remaining)
                let segment = String(remaining[remaining.startIndex...endIdx])
                result = result + Text(segment)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.accentGreen)
                remaining = remaining[remaining.index(after: endIdx)...]
                continue
            }

            // Inline comment
            if remaining.hasPrefix("//") || remaining.hasPrefix("#") {
                result = result + Text(String(remaining))
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textTertiary)
                break
            }

            // Word (keyword candidate)
            if remaining.first?.isLetter == true || remaining.first == "_" {
                let wordEnd = remaining.firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "_" }) ?? remaining.endIndex
                let word = String(remaining[remaining.startIndex..<wordEnd])

                if Self.keywords.contains(word) {
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

            // Number literal
            if remaining.first?.isNumber == true {
                let numEnd = remaining.firstIndex(where: { !$0.isNumber && $0 != "." }) ?? remaining.endIndex
                let num = String(remaining[remaining.startIndex..<numEnd])
                result = result + Text(num)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.accentAmber)
                remaining = remaining[numEnd...]
                continue
            }

            // Default: single character
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

// MARK: - Streaming Cursor

/// A blinking cursor that indicates code is still streaming.
struct StreamingCursor: View {
    @State private var isVisible = true

    var body: some View {
        Rectangle()
            .fill(AnvilColor.accentPurple)
            .frame(width: 2, height: 14)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
    }
}

// MARK: - Streaming Dot

/// A pulsing dot indicator for streaming state.
struct StreamingDot: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(AnvilColor.accentPurple)
            .frame(width: 6, height: 6)
            .scaleEffect(isAnimating ? 1.3 : 0.8)
            .opacity(isAnimating ? 1 : 0.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
