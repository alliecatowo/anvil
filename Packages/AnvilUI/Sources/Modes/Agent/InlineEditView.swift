import SwiftUI
import AnvilDomain

/// Displays a code edit suggestion with per-hunk accept/reject controls.
/// Embedded inside agent conversation messages when edits are proposed.
struct InlineEditView: View {
    let suggestion: CodeEditSuggestion
    let onAcceptHunk: (String) -> Void
    let onRejectHunk: (String) -> Void
    let onAcceptAll: () -> Void
    let onRejectAll: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                // File header
                fileHeader

                // Hunks
                ForEach(suggestion.hunks) { hunk in
                    EditHunkView(
                        hunk: hunk,
                        onAccept: { onAcceptHunk(hunk.id) },
                        onReject: { onRejectHunk(hunk.id) }
                    )

                    if hunk.id != suggestion.hunks.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - File Header

    private var fileHeader: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "pencil.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AnvilColor.accentAmber)
                .accessibilityHidden(true)

            Text(suggestion.filePath)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            if !suggestion.description.isEmpty {
                Text(suggestion.description)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Summary badge
            HStack(spacing: AnvilSpacing.xxs) {
                Text("\(suggestion.hunks.count) hunk\(suggestion.hunks.count == 1 ? "" : "s")")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Bulk actions
            if suggestion.hasPending {
                Button("Accept All") { onAcceptAll() }
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.accentGreen)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accept all hunks")
                    .accessibilityAddTraits(.isButton)

                Button("Reject All") { onRejectAll() }
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.accentRed)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reject all hunks")
                    .accessibilityAddTraits(.isButton)
            } else {
                let accepted = suggestion.acceptedCount
                let rejected = suggestion.rejectedCount
                HStack(spacing: AnvilSpacing.xs) {
                    if accepted > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text("\(accepted)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentGreen)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(accepted) accepted")
                    }
                    if rejected > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text("\(rejected)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentRed)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(rejected) rejected")
                    }
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
    }
}

// MARK: - Edit Hunk View

struct EditHunkView: View {
    let hunk: EditHunk
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header with line info
            if !hunk.header.isEmpty {
                HStack {
                    Text(hunk.header)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xxs)
                .background(AnvilColor.backgroundPrimary.opacity(0.5))
            }

            // Context before
            ForEach(Array(hunk.contextBefore.enumerated()), id: \.offset) { i, line in
                codeLine(
                    lineNumber: hunk.oldStart - hunk.contextBefore.count + i,
                    content: line,
                    type: .context
                )
            }

            // Removed lines
            ForEach(Array(hunk.removedLines.enumerated()), id: \.offset) { i, line in
                codeLine(
                    lineNumber: hunk.oldStart + i,
                    content: line,
                    type: .removed
                )
            }

            // Added lines
            ForEach(Array(hunk.addedLines.enumerated()), id: \.offset) { i, line in
                codeLine(
                    lineNumber: hunk.newStart + i,
                    content: line,
                    type: .added
                )
            }

            // Context after
            ForEach(Array(hunk.contextAfter.enumerated()), id: \.offset) { i, line in
                let startLine = hunk.oldStart + hunk.oldCount + i
                codeLine(lineNumber: startLine, content: line, type: .context)
            }

            // Accept / Reject buttons
            hunkActions
        }
    }

    // MARK: - Code Line

    private func codeLine(lineNumber: Int, content: String, type: DiffLineType) -> some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, AnvilSpacing.xxs)

            Text(prefix(for: type))
                .font(AnvilFont.code)
                .foregroundStyle(color(for: type))
                .frame(width: 14, alignment: .center)

            Text(content.isEmpty ? " " : content)
                .font(AnvilFont.code)
                .foregroundStyle(color(for: type))
                .lineLimit(1)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AnvilSpacing.xxs)
        .background(background(for: type))
    }

    private func prefix(for type: DiffLineType) -> String {
        switch type {
        case .context: " "
        case .added: "+"
        case .removed: "-"
        }
    }

    private func color(for type: DiffLineType) -> Color {
        switch type {
        case .context: AnvilColor.textPrimary
        case .added: AnvilColor.diffAddedText
        case .removed: AnvilColor.diffRemovedText
        }
    }

    private func background(for type: DiffLineType) -> Color {
        switch type {
        case .context: .clear
        case .added: AnvilColor.diffAddedBackground
        case .removed: AnvilColor.diffRemovedBackground
        }
    }

    // MARK: - Hunk Actions

    private var hunkActions: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Spacer()

            switch hunk.state {
            case .pending:
                Button {
                    onAccept()
                } label: {
                    Label("Accept", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .controlSize(.small)
                .accessibilityLabel("Accept hunk")
                .accessibilityAddTraits(.isButton)

                Button {
                    onReject()
                } label: {
                    Label("Reject", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
                .accessibilityLabel("Reject hunk")
                .accessibilityAddTraits(.isButton)

            case .accepted:
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .accessibilityHidden(true)
                    Text("Accepted")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.accentGreen)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Hunk accepted")

            case .rejected:
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .accessibilityHidden(true)
                    Text("Rejected")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.accentRed)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Hunk rejected")
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
    }
}
