import SwiftUI
import AnvilDomain

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AgentMessage
    var isStreaming: Bool = false
    var onApproveToolCall: ((Bool) -> Void)?
    var onRejectToolCall: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Role header
            HStack {
                Image(systemName: message.role == .user ? "person.circle" : "cpu")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(message.role == .user ? AnvilColor.accentBlue : AnvilColor.accentPurple)
                    .accessibilityHidden(true)

                Text(message.role == .user ? "You" : "Agent")
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                Text(message.timestamp, style: .time)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Content — use streaming-aware rendering for assistant messages
            if message.role == .assistant && !message.content.isEmpty {
                if isStreaming {
                    StreamingMarkdownContent(markdown: message.content)
                        .textSelection(.enabled)
                } else {
                    AnvilMarkdownRenderer(message.content)
                        .textSelection(.enabled)
                }
            } else if !message.content.isEmpty {
                Text(message.content)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .textSelection(.enabled)
            }

            // Tool calls
            ForEach(message.toolCalls) { toolCall in
                ToolCallView(
                    toolCall: toolCall,
                    onApprove: onApproveToolCall,
                    onReject: onRejectToolCall
                )
            }
        }
        .padding(AnvilSpacing.md)
        .background(message.role == .user ? AnvilColor.accentBlue.opacity(0.04) : .clear)
    }
}

/// Renders markdown with streaming-aware code blocks.
/// Detects in-progress (unclosed) code fences and renders them with StreamingCodeBlock.
struct StreamingMarkdownContent: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    private enum StreamBlock {
        case text(String)
        case codeBlock(code: String, language: String?, isComplete: Bool)
    }

    private func parseBlocks() -> [StreamBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [StreamBlock] = []
        var textBuffer: [String] = []
        var inCodeBlock = false
        var codeLines: [String] = []
        var codeLanguage: String?
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !inCodeBlock && trimmed.hasPrefix("```") {
                // Flush text buffer
                if !textBuffer.isEmpty {
                    blocks.append(.text(textBuffer.joined(separator: "\n")))
                    textBuffer = []
                }
                // Start code block
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeLanguage = lang.isEmpty ? nil : lang
                codeLines = []
                inCodeBlock = true
                i += 1
                continue
            }

            if inCodeBlock {
                if trimmed.hasPrefix("```") {
                    // Close code block
                    blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: codeLanguage, isComplete: true))
                    inCodeBlock = false
                    codeLines = []
                    codeLanguage = nil
                    i += 1
                    continue
                }
                codeLines.append(line)
                i += 1
                continue
            }

            textBuffer.append(line)
            i += 1
        }

        // Handle unclosed code block (still streaming)
        if inCodeBlock {
            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: codeLanguage, isComplete: false))
        }

        // Flush remaining text
        if !textBuffer.isEmpty {
            blocks.append(.text(textBuffer.joined(separator: "\n")))
        }

        return blocks
    }

    @ViewBuilder
    private func renderBlock(_ block: StreamBlock) -> some View {
        switch block {
        case .text(let text):
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AnvilMarkdownRenderer(text)
            }
        case .codeBlock(let code, let language, let isComplete):
            StreamingCodeBlock(
                code: code,
                language: language,
                isStreaming: !isComplete
            )
        }
    }
}
