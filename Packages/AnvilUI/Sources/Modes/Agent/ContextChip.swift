import SwiftUI
import AnvilDomain

/// Represents a piece of context attached to an agent conversation input.
public enum ContextAttachment: Identifiable {
    case file(path: String)
    case ticket(id: String, title: String)
    case error(message: String, file: String?, line: Int?)
    case branch(name: String)
    case codeSelection(filePath: String, startLine: Int, endLine: Int, preview: String)
    case diff(summary: String, content: String)

    public var id: String {
        switch self {
        case .file(let path): "file:\(path)"
        case .ticket(let id, _): "ticket:\(id)"
        case .error(let message, _, _): "error:\(message.prefix(50))"
        case .branch(let name): "branch:\(name)"
        case .codeSelection(let path, let start, let end, _): "selection:\(path):\(start)-\(end)"
        case .diff(let summary, _): "diff:\(summary.prefix(50))"
        }
    }

    public var icon: String {
        switch self {
        case .file: "doc.text"
        case .ticket: "ticket"
        case .error: "exclamationmark.triangle"
        case .branch: "arrow.triangle.branch"
        case .codeSelection: "text.cursor"
        case .diff: "plus.forwardslash.minus"
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
        case .diff(let summary, _):
            return summary
        }
    }

    public var color: Color {
        switch self {
        case .file: AnvilColor.accentBlue
        case .ticket: AnvilColor.accentPurple
        case .error: AnvilColor.accentRed
        case .branch: AnvilColor.accentGreen
        case .codeSelection: AnvilColor.accentTeal
        case .diff: AnvilColor.accentAmber
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
        case .diff(let summary, let content):
            return "Git diff (\(summary)):\n```diff\n\(content)\n```"
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

// MARK: - Auto-Context

/// Lightweight data type for auto-context file chips (avoids importing Application layer types into views).
public struct AutoContextChipData: Identifiable {
    public let id: String
    public let path: String
    public let name: String
    public let reason: String

    public init(id: String, path: String, name: String, reason: String) {
        self.id = id
        self.path = path
        self.name = name
        self.reason = reason
    }
}

/// Collapsed/expandable bar showing auto-inferred context files above the input field.
struct AutoContextBar: View {
    let files: [AutoContextChipData]
    @Binding var isExpanded: Bool
    let onDismiss: (String) -> Void
    let onAccept: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header row — always visible
            Button {
                withAnimation(AnvilAnimation.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.accentPurple)
                        .accessibilityHidden(true)
                    Text("Auto-context")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                    Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Auto-context, \(files.count) files")
            .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")

            // Expanded chip list
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AnvilSpacing.xs) {
                        ForEach(files) { file in
                            AutoContextChip(
                                file: file,
                                onDismiss: { onDismiss(file.path) },
                                onAccept: { onAccept(file.path) }
                            )
                        }
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.bottom, AnvilSpacing.xs)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AnvilColor.accentPurple.opacity(0.04))
    }
}

/// A single auto-context chip with accept (pin) and dismiss (x) actions.
private struct AutoContextChip: View {
    let file: AutoContextChipData
    let onDismiss: () -> Void
    let onAccept: () -> Void

    var body: some View {
        HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(AnvilColor.accentPurple)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(file.name)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)
                Text(file.reason)
                    .font(.system(size: 9))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }

            Button(action: onAccept) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(AnvilColor.accentGreen)
            }
            .buttonStyle(.plain)
            .help("Pin to context")
            .accessibilityLabel("Pin \(file.name)")

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityLabel("Dismiss \(file.name)")
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xxxs)
        .background(AnvilColor.accentPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Auto-context: \(file.name), \(file.reason)")
    }
}
