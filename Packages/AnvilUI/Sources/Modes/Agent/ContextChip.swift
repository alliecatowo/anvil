import SwiftUI
import AnvilDomain

/// Represents a piece of context attached to an agent conversation input.
public enum ContextAttachment: Identifiable {
    case file(path: String)
    case ticket(id: String, title: String)
    case error(message: String, file: String?, line: Int?)
    case branch(name: String)
    case codeSelection(filePath: String, startLine: Int, endLine: Int, preview: String)

    public var id: String {
        switch self {
        case .file(let path): "file:\(path)"
        case .ticket(let id, _): "ticket:\(id)"
        case .error(let message, _, _): "error:\(message.prefix(50))"
        case .branch(let name): "branch:\(name)"
        case .codeSelection(let path, let start, let end, _): "selection:\(path):\(start)-\(end)"
        }
    }

    public var icon: String {
        switch self {
        case .file: "doc.text"
        case .ticket: "ticket"
        case .error: "exclamationmark.triangle"
        case .branch: "arrow.triangle.branch"
        case .codeSelection: "text.cursor"
        }
    }

    public var label: String {
        switch self {
        case .file(let path):
            return URL(fileURLWithPath: path).lastPathComponent
        case .ticket(let id, let title):
            return "\(id): \(title)"
        case .error(let message, _, _):
            return String(message.prefix(60))
        case .branch(let name):
            return name
        case .codeSelection(let path, let start, let end, _):
            let file = URL(fileURLWithPath: path).lastPathComponent
            return "\(file):\(start)-\(end)"
        }
    }

    public var color: Color {
        switch self {
        case .file: AnvilColor.accentBlue
        case .ticket: AnvilColor.accentPurple
        case .error: AnvilColor.accentRed
        case .branch: AnvilColor.accentGreen
        case .codeSelection: AnvilColor.accentTeal
        }
    }

    /// Builds the context string to inject into the prompt.
    public var contextString: String {
        switch self {
        case .file(let path):
            return "@file:\(path)"
        case .ticket(let id, let title):
            return "@ticket:\(id) — \(title)"
        case .error(let message, let file, let line):
            var s = "Error: \(message)"
            if let file { s += " (at \(file)" }
            if let line { s += ":\(line)" }
            if file != nil { s += ")" }
            return s
        case .branch(let name):
            return "@branch:\(name)"
        case .codeSelection(let path, let start, let end, let preview):
            return "Code from \(URL(fileURLWithPath: path).lastPathComponent):\(start)-\(end):\n```\n\(preview)\n```"
        }
    }
}

/// A removable chip that represents an attached context item.
struct ContextChipView: View {
    let attachment: ContextAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: attachment.icon)
                .font(.system(size: 10))
                .foregroundStyle(attachment.color)
                .accessibilityHidden(true)

            Text(attachment.label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(attachment.label)")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xxxs)
        .background(attachment.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Context: \(attachment.label)")
    }
}

/// Bar showing all attached context items above the input field.
struct ContextAttachmentBar: View {
    let attachments: [ContextAttachment]
    let onRemove: (String) -> Void

    var body: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AnvilSpacing.xs) {
                    ForEach(attachments) { attachment in
                        ContextChipView(attachment: attachment) {
                            onRemove(attachment.id)
                        }
                    }
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
            }
            .background(AnvilColor.backgroundTertiary)
        }
    }
}
