import SwiftUI
import AnvilDomain

// MARK: - File-Editing Tool Detection

private let fileEditingToolNames: Set<String> = [
    "write_file", "edit_file", "patch", "create_file",
    "str_replace_editor", "str_replace", "apply_patch"
]

// MARK: - Unified Diff Parser

/// Parses a unified diff string into `[FileDiff]` for rendering with `AnvilDiffView`.
enum UnifiedDiffParser {

    static func looksLikeDiff(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Must contain at least one hunk header
        guard trimmed.contains("@@ ") else { return false }
        // Should have diff-like prefix lines or hunk markers
        return trimmed.contains("---") || trimmed.contains("+++")
    }

    static func looksLikeNewFile(_ text: String, toolName: String) -> Bool {
        let isCreationTool = toolName == "create_file" || toolName == "write_file"
        guard isCreationTool else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // New file content: no hunk headers, no diff markers
        return !trimmed.contains("@@ ") && !trimmed.isEmpty
    }

    static func parse(_ text: String) -> [FileDiff] {
        let lines = text.components(separatedBy: "\n")
        var fileDiffs: [FileDiff] = []
        var currentFilePath: String = "file"
        var currentOldPath: String?
        var currentStatus: DiffFileStatus = .modified
        var currentHunks: [DiffHunk] = []
        var currentHunkLines: [DiffLine] = []
        var hunkOldStart = 0
        var hunkOldCount = 0
        var hunkNewStart = 0
        var hunkNewCount = 0
        var hunkHeader = ""
        var inHunk = false
        var oldLineNum = 0
        var newLineNum = 0
        var hasFile = false

        func flushHunk() {
            guard inHunk else { return }
            currentHunks.append(DiffHunk(
                oldStart: hunkOldStart, oldCount: hunkOldCount,
                newStart: hunkNewStart, newCount: hunkNewCount,
                header: hunkHeader, lines: currentHunkLines
            ))
            currentHunkLines = []
            inHunk = false
        }

        func flushFile() {
            flushHunk()
            guard hasFile else { return }
            fileDiffs.append(FileDiff(
                filePath: currentFilePath,
                oldPath: currentOldPath,
                status: currentStatus,
                hunks: currentHunks
            ))
            currentHunks = []
            currentOldPath = nil
            currentStatus = .modified
            hasFile = false
        }

        for line in lines {
            // --- a/path or --- /dev/null
            if line.hasPrefix("--- ") {
                let path = String(line.dropFirst(4))
                if path == "/dev/null" {
                    currentStatus = .added
                } else {
                    currentOldPath = path.hasPrefix("a/") ? String(path.dropFirst(2)) : path
                }
                continue
            }

            // +++ b/path or +++ /dev/null
            if line.hasPrefix("+++ ") {
                flushFile()
                hasFile = true
                let path = String(line.dropFirst(4))
                if path == "/dev/null" {
                    currentStatus = .deleted
                    currentFilePath = currentOldPath ?? "file"
                } else {
                    currentFilePath = path.hasPrefix("b/") ? String(path.dropFirst(2)) : path
                }
                continue
            }

            // Hunk header: @@ -old,count +new,count @@
            if line.hasPrefix("@@ ") {
                flushHunk()
                hunkHeader = line
                // Parse numbers
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    let oldPart = parts[1] // e.g. -1,5
                    let newPart = parts[2] // e.g. +1,7
                    let oldNums = oldPart.dropFirst().components(separatedBy: ",")
                    let newNums = newPart.dropFirst().components(separatedBy: ",")
                    hunkOldStart = Int(oldNums[0]) ?? 0
                    hunkOldCount = oldNums.count > 1 ? (Int(oldNums[1]) ?? 0) : 1
                    hunkNewStart = Int(newNums[0]) ?? 0
                    hunkNewCount = newNums.count > 1 ? (Int(newNums[1]) ?? 0) : 1
                }
                oldLineNum = hunkOldStart
                newLineNum = hunkNewStart
                inHunk = true
                continue
            }

            // Skip diff/index header lines
            if line.hasPrefix("diff ") || line.hasPrefix("index ") || line.hasPrefix("new file") || line.hasPrefix("deleted file") {
                if line.hasPrefix("new file") { currentStatus = .added }
                if line.hasPrefix("deleted file") { currentStatus = .deleted }
                continue
            }

            // Diff content lines
            guard inHunk else { continue }

            if line.hasPrefix("+") {
                currentHunkLines.append(DiffLine(
                    type: .added, content: String(line.dropFirst()),
                    oldLineNumber: nil, newLineNumber: newLineNum
                ))
                newLineNum += 1
            } else if line.hasPrefix("-") {
                currentHunkLines.append(DiffLine(
                    type: .removed, content: String(line.dropFirst()),
                    oldLineNumber: oldLineNum, newLineNumber: nil
                ))
                oldLineNum += 1
            } else if line.hasPrefix(" ") {
                currentHunkLines.append(DiffLine(
                    type: .context, content: String(line.dropFirst()),
                    oldLineNumber: oldLineNum, newLineNumber: newLineNum
                ))
                oldLineNum += 1
                newLineNum += 1
            } else if line.isEmpty && inHunk {
                // Treat blank lines inside hunks as context
                currentHunkLines.append(DiffLine(
                    type: .context, content: "",
                    oldLineNumber: oldLineNum, newLineNumber: newLineNum
                ))
                oldLineNum += 1
                newLineNum += 1
            }
        }

        flushFile()

        // If we parsed nothing but the text has hunk markers, create a single-file diff
        if fileDiffs.isEmpty && !currentHunks.isEmpty {
            fileDiffs.append(FileDiff(
                filePath: currentFilePath,
                status: currentStatus,
                hunks: currentHunks
            ))
        }

        return fileDiffs
    }

    /// Extracts the file path from tool call arguments JSON (best-effort).
    static func extractFilePath(from arguments: String) -> String? {
        // Simple JSON key extraction without importing Foundation's JSONSerialization
        // Looks for "path": "...", "file_path": "...", or "file": "..."
        for key in ["file_path", "path", "file"] {
            let pattern = "\"\(key)\"\\s*:\\s*\"([^\"]+)\""
            if let range = arguments.range(of: pattern, options: .regularExpression),
               let valueRange = arguments[range].range(of: ":\\s*\"", options: .regularExpression) {
                let afterColon = arguments[valueRange.upperBound...]
                if let endQuote = afterColon.firstIndex(of: "\"") {
                    return String(afterColon[..<endQuote])
                }
            }
        }
        return nil
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ToolCall
    var onApprove: ((Bool) -> Void)?
    var onReject: ((Bool) -> Void)?
    @State private var isExpanded = false

    private var isFileEditingTool: Bool {
        fileEditingToolNames.contains(toolCall.name)
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: toolCallIcon)
                            .font(.system(size: 11))
                        Text(toolCall.name)
                            .font(AnvilFont.code)

                        statusIndicator

                        // Show file path badge for file-editing tools
                        if isFileEditingTool,
                           let path = UnifiedDiffParser.extractFilePath(from: toolCall.arguments) {
                            Text(path)
                                .font(AnvilFont.code)
                                .foregroundStyle(AnvilColor.accentTeal)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(AnvilColor.textSecondary)
                }
                .buttonStyle(.plain)

                if isExpanded, let result = toolCall.result {
                    resultContent(result)
                }

                // Approve/Reject for pending tool calls
                if toolCall.status == .pending {
                    HStack(spacing: AnvilSpacing.sm) {
                        AnvilButton("Approve", icon: "checkmark", style: .primary) {
                            onApprove?(false)
                        }
                        AnvilButton("Reject", icon: "xmark", style: .destructive) {
                            onReject?(false)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Result Content Rendering

    @ViewBuilder
    private func resultContent(_ result: ToolResult) -> some View {
        if isFileEditingTool {
            fileEditResultContent(result)
        } else {
            plainResultContent(result)
        }
    }

    @ViewBuilder
    private func fileEditResultContent(_ result: ToolResult) -> some View {
        let content = result.content

        if result.type == .diff || UnifiedDiffParser.looksLikeDiff(content) {
            // Parse and render as inline diff
            let fileDiffs = UnifiedDiffParser.parse(content)
            if !fileDiffs.isEmpty {
                VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                    AnvilDiffView(fileDiffs: fileDiffs, mode: .unified)
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))

                    // Accept/Reject buttons for completed diffs
                    if toolCall.status == .completed {
                        diffActionButtons
                    }
                }
            } else {
                plainResultContent(result)
            }
        } else if UnifiedDiffParser.looksLikeNewFile(content, toolName: toolCall.name) {
            // New file creation: show badge + green-tinted code block
            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                newFileBadge

                ScrollView {
                    Text(content)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.diffAddedText)
                        .padding(AnvilSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .background(AnvilColor.diffAddedBackground)
                .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                        .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                )

                // Accept/Reject buttons for completed new files
                if toolCall.status == .completed {
                    diffActionButtons
                }
            }
        } else {
            plainResultContent(result)
        }
    }

    private var newFileBadge: some View {
        HStack(spacing: AnvilSpacing.xs) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentGreen)
            Text("New file")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.accentGreen)
            if let path = UnifiedDiffParser.extractFilePath(from: toolCall.arguments) {
                Text(path)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var diffActionButtons: some View {
        HStack(spacing: AnvilSpacing.sm) {
            AnvilButton("Accept", icon: "checkmark.circle", style: .primary) {
                onApprove?(false)
            }
            AnvilButton("Reject", icon: "xmark.circle", style: .destructive) {
                onReject?(false)
            }
        }
        .padding(.top, AnvilSpacing.xxs)
    }

    private func plainResultContent(_ result: ToolResult) -> some View {
        Text(result.content)
            .font(AnvilFont.code)
            .foregroundStyle(AnvilColor.textSecondary)
            .padding(AnvilSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AnvilColor.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .lineLimit(20)
    }

    var toolCallIcon: String {
        switch toolCall.name {
        case "read_file": "doc.text"
        case "write_file", "edit_file", "create_file", "patch", "apply_patch": "pencil"
        case "str_replace_editor", "str_replace": "pencil.line"
        case "terminal": "terminal"
        case "search", "grep": "magnifyingglass"
        default: "wrench"
        }
    }

    @ViewBuilder
    var statusIndicator: some View {
        switch toolCall.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AnvilColor.accentGreen)
                .font(.system(size: 10))
        case .running:
            AnvilLoadingIndicator(size: 10)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AnvilColor.accentRed)
                .font(.system(size: 10))
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(AnvilColor.accentAmber)
                .font(.system(size: 10))
        default:
            EmptyView()
        }
    }
}

// MARK: - Tool Approval Banner

struct ToolApprovalBanner: View {
    let toolName: String
    let arguments: String
    let guardrailViolation: String?
    let onApprove: (Bool) -> Void  // Bool = remember
    let onReject: (Bool) -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                HStack {
                    Image(systemName: guardrailViolation != nil ? "shield.slash" : "wrench.and.screwdriver")
                        .foregroundStyle(guardrailViolation != nil ? AnvilColor.accentRed : AnvilColor.accentAmber)
                    Text("Tool call requires approval")
                        .font(AnvilFont.sidebarHeader)
                        .foregroundStyle(AnvilColor.textPrimary)
                    Spacer()
                }

                HStack(spacing: AnvilSpacing.sm) {
                    Text(toolName)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentPurple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AnvilColor.accentPurple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(arguments.prefix(120))
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .lineLimit(2)
                }

                if let violation = guardrailViolation {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AnvilColor.accentRed)
                            .font(.system(size: 11))
                        Text(violation)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentRed)
                    }
                }

                HStack(spacing: AnvilSpacing.sm) {
                    Button("Approve") { onApprove(false) }
                        .buttonStyle(.bordered)
                        .tint(.green)

                    Button("Always Allow") { onApprove(true) }
                        .buttonStyle(.borderless)
                        .foregroundStyle(AnvilColor.accentGreen)

                    Button("Reject") { onReject(false) }
                        .buttonStyle(.bordered)
                        .tint(.red)

                    Button("Always Deny") { onReject(true) }
                        .buttonStyle(.borderless)
                        .foregroundStyle(AnvilColor.accentRed)
                }
            }
        }
    }
}
