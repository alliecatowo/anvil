import SwiftUI

public struct AnvilMarkdownRenderer: View {
    let markdown: String

    public init(_ markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    private enum MarkdownBlock {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case codeBlock(code: String, language: String?)
        case bulletItem(text: String, indentLevel: Int)
        case blockquote(text: String)
        case blank
    }

    // MARK: - Parser

    private func parseBlocks() -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Fenced code block
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let language: String? = lang.isEmpty ? nil : lang
                var codeLines: [String] = []
                index += 1
                while index < lines.count {
                    if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(lines[index])
                    index += 1
                }
                blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: language))
                continue
            }

            // Heading
            if let headingMatch = parseHeading(line) {
                blocks.append(headingMatch)
                index += 1
                continue
            }

            // Blockquote
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("> ") {
                let text = String(line.trimmingCharacters(in: .whitespaces).dropFirst(2))
                blocks.append(.blockquote(text: text))
                index += 1
                continue
            }

            // Bullet list item
            if let bullet = parseBullet(line) {
                blocks.append(bullet)
                index += 1
                continue
            }

            // Blank line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.blank)
                index += 1
                continue
            }

            // Default: paragraph (accumulate consecutive non-special lines)
            var paragraphLines: [String] = [line]
            index += 1
            while index < lines.count {
                let nextLine = lines[index]
                let trimmedNext = nextLine.trimmingCharacters(in: .whitespaces)
                if trimmedNext.isEmpty || trimmedNext.hasPrefix("#") || trimmedNext.hasPrefix("```")
                    || trimmedNext.hasPrefix("> ") || trimmedNext.hasPrefix("- ")
                    || trimmedNext.hasPrefix("* ")
                {
                    break
                }
                paragraphLines.append(nextLine)
                index += 1
            }
            blocks.append(.paragraph(text: paragraphLines.joined(separator: " ")))
        }

        return blocks
    }

    private func parseHeading(_ line: String) -> MarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("### ") {
            return .heading(level: 3, text: String(trimmed.dropFirst(4)))
        } else if trimmed.hasPrefix("## ") {
            return .heading(level: 2, text: String(trimmed.dropFirst(3)))
        } else if trimmed.hasPrefix("# ") {
            return .heading(level: 1, text: String(trimmed.dropFirst(2)))
        }
        return nil
    }

    private func parseBullet(_ line: String) -> MarkdownBlock? {
        // Count leading spaces for indent level
        let stripped = line.replacingOccurrences(of: "\t", with: "    ")
        let leadingSpaces = stripped.prefix(while: { $0 == " " }).count
        let trimmed = stripped.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("- ") {
            return .bulletItem(text: String(trimmed.dropFirst(2)), indentLevel: leadingSpaces / 2)
        } else if trimmed.hasPrefix("* ") {
            return .bulletItem(text: String(trimmed.dropFirst(2)), indentLevel: leadingSpaces / 2)
        }
        return nil
    }

    // MARK: - Renderer

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(headingFont(level))
                .foregroundStyle(AnvilColor.textPrimary)
                .padding(.top, level == 1 ? AnvilSpacing.md : AnvilSpacing.sm)

        case .paragraph(let text):
            renderInlineText(text)

        case .codeBlock(let code, let language):
            AnvilCodeBlock(code: code, language: language, showLineNumbers: false)

        case .bulletItem(let text, let indentLevel):
            HStack(alignment: .firstTextBaseline, spacing: AnvilSpacing.xs) {
                Text("\u{2022}")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                renderInlineText(text)
            }
            .padding(.leading, CGFloat(indentLevel) * AnvilSpacing.lg)

        case .blockquote(let text):
            HStack(spacing: AnvilSpacing.sm) {
                Rectangle()
                    .fill(AnvilColor.accentBlue)
                    .frame(width: 3)
                renderInlineText(text)
                    .foregroundStyle(AnvilColor.textSecondary)
            }
            .padding(.vertical, AnvilSpacing.xxs)

        case .blank:
            Spacer()
                .frame(height: AnvilSpacing.xs)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: AnvilFont.heading
        case 2: AnvilFont.subheading
        default: AnvilFont.sidebarHeader
        }
    }

    // MARK: - Inline Rendering

    /// Renders inline markdown (bold, italic, code, links) as a composed Text view.
    private func renderInlineText(_ input: String) -> Text {
        var result = Text("")
        var remaining = input[input.startIndex...]

        while !remaining.isEmpty {
            // Inline code: `...`
            if remaining.first == "`", let endIdx = remaining.dropFirst().firstIndex(of: "`") {
                let codeText = String(remaining[remaining.index(after: remaining.startIndex)..<endIdx])
                result = result + Text(codeText)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                remaining = remaining[remaining.index(after: endIdx)...]
                continue
            }

            // Bold: **...**
            if remaining.hasPrefix("**") {
                let afterStars = remaining.index(remaining.startIndex, offsetBy: 2)
                if let closeRange = remaining[afterStars...].range(of: "**") {
                    let boldText = String(remaining[afterStars..<closeRange.lowerBound])
                    result = result + Text(boldText).bold()
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textPrimary)
                    remaining = remaining[closeRange.upperBound...]
                    continue
                }
            }

            // Italic: *...*
            if remaining.hasPrefix("*") && !remaining.hasPrefix("**") {
                let afterStar = remaining.index(after: remaining.startIndex)
                if let closeIdx = remaining[afterStar...].firstIndex(of: "*") {
                    let italicText = String(remaining[afterStar..<closeIdx])
                    result = result + Text(italicText).italic()
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textPrimary)
                    remaining = remaining[remaining.index(after: closeIdx)...]
                    continue
                }
            }

            // Link: [text](url)
            if remaining.hasPrefix("[") {
                if let closeBracket = remaining.firstIndex(of: "]"),
                   remaining.index(after: closeBracket) < remaining.endIndex,
                   remaining[remaining.index(after: closeBracket)] == "("
                {
                    let afterParen = remaining.index(closeBracket, offsetBy: 2)
                    if let closeParen = remaining[afterParen...].firstIndex(of: ")") {
                        let linkText = String(remaining[remaining.index(after: remaining.startIndex)..<closeBracket])
                        result = result + Text(linkText)
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.accentBlue)
                            .underline()
                        remaining = remaining[remaining.index(after: closeParen)...]
                        continue
                    }
                }
            }

            // Regular character: consume until next special char
            let nextSpecial = remaining.dropFirst().firstIndex(where: { "`*[".contains($0) }) ?? remaining.endIndex
            let plain = String(remaining[remaining.startIndex..<nextSpecial])
            result = result + Text(plain)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
            remaining = remaining[nextSpecial...]
        }

        return result
    }
}
