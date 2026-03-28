import SwiftUI
import AnvilDomain

public enum DiffViewMode: String, Sendable, CaseIterable {
    case sideBySide = "Side-by-Side"
    case unified = "Unified"
}

public struct AnvilDiffView: View {
    let fileDiffs: [FileDiff]
    let mode: DiffViewMode

    public init(fileDiffs: [FileDiff], mode: DiffViewMode = .unified) {
        self.fileDiffs = fileDiffs
        self.mode = mode
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AnvilSpacing.lg) {
                ForEach(fileDiffs) { fileDiff in
                    fileDiffSection(fileDiff)
                }
            }
            .padding(AnvilSpacing.md)
        }
    }

    // MARK: - File Section

    @ViewBuilder
    private func fileDiffSection(_ fileDiff: FileDiff) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            fileHeader(fileDiff)

            if fileDiff.isBinary {
                binaryPlaceholder
            } else {
                switch mode {
                case .unified:
                    unifiedDiff(fileDiff.hunks)
                case .sideBySide:
                    sideBySideDiff(fileDiff.hunks)
                }
            }
        }
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                .stroke(AnvilColor.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - File Header

    private func fileHeader(_ fileDiff: FileDiff) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: fileIcon(for: fileDiff.status))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(fileColor(for: fileDiff.status))

            Text(fileDiff.filePath)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let oldPath = fileDiff.oldPath, fileDiff.status == .renamed {
                Text("(from \(oldPath))")
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            AnvilBadge(
                text: fileDiff.status.rawValue.capitalized,
                color: fileColor(for: fileDiff.status)
            )
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
    }

    private func fileIcon(for status: DiffFileStatus) -> String {
        switch status {
        case .added: "plus.circle"
        case .modified: "pencil.circle"
        case .deleted: "minus.circle"
        case .renamed: "arrow.right.circle"
        case .copied: "doc.on.doc"
        }
    }

    private func fileColor(for status: DiffFileStatus) -> Color {
        switch status {
        case .added: AnvilColor.accentGreen
        case .modified: AnvilColor.accentAmber
        case .deleted: AnvilColor.accentRed
        case .renamed: AnvilColor.accentBlue
        case .copied: AnvilColor.accentTeal
        }
    }

    private var binaryPlaceholder: some View {
        Text("Binary file changed")
            .font(AnvilFont.code)
            .foregroundStyle(AnvilColor.textTertiary)
            .padding(AnvilSpacing.md)
    }

    // MARK: - Unified Diff

    @ViewBuilder
    private func unifiedDiff(_ hunks: [DiffHunk]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(hunks) { hunk in
                hunkSeparator(hunk.header)

                ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                    unifiedLine(line)
                }
            }
        }
    }

    private func unifiedLine(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { String($0) } ?? "")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, AnvilSpacing.xxs)

            // New line number
            Text(line.newLineNumber.map { String($0) } ?? "")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, AnvilSpacing.sm)

            // Prefix
            Text(linePrefix(for: line.type))
                .font(AnvilFont.code)
                .foregroundStyle(lineColor(for: line.type))
                .frame(width: 14, alignment: .center)

            // Content
            Text(line.content)
                .font(AnvilFont.code)
                .foregroundStyle(lineColor(for: line.type))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AnvilSpacing.xxs)
        .background(lineBackground(for: line.type))
    }

    // MARK: - Side-by-Side Diff

    @ViewBuilder
    private func sideBySideDiff(_ hunks: [DiffHunk]) -> some View {
        let sides = splitHunksForSideBySide(hunks)

        HStack(alignment: .top, spacing: 0) {
            // Left (old)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sides.left.enumerated()), id: \.offset) { _, entry in
                        sideBySideLine(entry, isOld: true)
                    }
                }
            }

            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(width: 1)

            // Right (new)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sides.right.enumerated()), id: \.offset) { _, entry in
                        sideBySideLine(entry, isOld: false)
                    }
                }
            }
        }
    }

    private func sideBySideLine(_ entry: SideBySideEntry, isOld: Bool) -> some View {
        HStack(spacing: 0) {
            let lineNum = isOld ? entry.oldLineNumber : entry.newLineNumber
            Text(lineNum.map { String($0) } ?? "")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, AnvilSpacing.sm)

            Text(entry.content ?? "")
                .font(AnvilFont.code)
                .foregroundStyle(lineColor(for: entry.type))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AnvilSpacing.xxs)
        .background(lineBackground(for: entry.type))
    }

    // MARK: - Hunk Separator

    private func hunkSeparator(_ header: String) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(height: 1)

            Text(header)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .lineLimit(1)

            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(height: 1)
        }
        .padding(.vertical, AnvilSpacing.xxs)
        .padding(.horizontal, AnvilSpacing.sm)
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Helpers

    private func linePrefix(for type: DiffLineType) -> String {
        switch type {
        case .context: " "
        case .added: "+"
        case .removed: "-"
        }
    }

    private func lineColor(for type: DiffLineType) -> Color {
        switch type {
        case .context: AnvilColor.textPrimary
        case .added: AnvilColor.diffAddedText
        case .removed: AnvilColor.diffRemovedText
        }
    }

    private func lineBackground(for type: DiffLineType) -> Color {
        switch type {
        case .context: .clear
        case .added: Color(hex: 0x22C55E, opacity: 0.1)
        case .removed: Color(hex: 0xEF4444, opacity: 0.1)
        }
    }

    // MARK: - Side-by-Side Data Splitting

    private struct SideBySideEntry {
        let type: DiffLineType
        let content: String?
        let oldLineNumber: Int?
        let newLineNumber: Int?
    }

    private struct SideBySidePair {
        var left: [SideBySideEntry]
        var right: [SideBySideEntry]
    }

    private func splitHunksForSideBySide(_ hunks: [DiffHunk]) -> SideBySidePair {
        var left: [SideBySideEntry] = []
        var right: [SideBySideEntry] = []

        for hunk in hunks {
            // Add hunk separator markers
            let separator = SideBySideEntry(type: .context, content: hunk.header, oldLineNumber: nil, newLineNumber: nil)
            left.append(separator)
            right.append(separator)

            var removedBuffer: [DiffLine] = []
            var addedBuffer: [DiffLine] = []

            func flushBuffers() {
                let maxCount = max(removedBuffer.count, addedBuffer.count)
                for i in 0..<maxCount {
                    let leftEntry: SideBySideEntry
                    if i < removedBuffer.count {
                        let line = removedBuffer[i]
                        leftEntry = SideBySideEntry(type: .removed, content: line.content, oldLineNumber: line.oldLineNumber, newLineNumber: nil)
                    } else {
                        leftEntry = SideBySideEntry(type: .context, content: nil, oldLineNumber: nil, newLineNumber: nil)
                    }

                    let rightEntry: SideBySideEntry
                    if i < addedBuffer.count {
                        let line = addedBuffer[i]
                        rightEntry = SideBySideEntry(type: .added, content: line.content, oldLineNumber: nil, newLineNumber: line.newLineNumber)
                    } else {
                        rightEntry = SideBySideEntry(type: .context, content: nil, oldLineNumber: nil, newLineNumber: nil)
                    }

                    left.append(leftEntry)
                    right.append(rightEntry)
                }
                removedBuffer.removeAll()
                addedBuffer.removeAll()
            }

            for line in hunk.lines {
                switch line.type {
                case .context:
                    flushBuffers()
                    let entry = SideBySideEntry(type: .context, content: line.content, oldLineNumber: line.oldLineNumber, newLineNumber: line.newLineNumber)
                    left.append(entry)
                    right.append(entry)
                case .removed:
                    removedBuffer.append(line)
                case .added:
                    addedBuffer.append(line)
                }
            }

            flushBuffers()
        }

        return SideBySidePair(left: left, right: right)
    }
}
