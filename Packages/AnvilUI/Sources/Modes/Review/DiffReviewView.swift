import SwiftUI
import AnvilDomain
import AnvilGit

struct DiffReviewView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        VStack(spacing: 0) {
            if let file = viewModel.selectedFile {
                fileHeader(file)
                Divider().overlay(AnvilColor.borderSubtle)

                switch viewModel.diffViewMode {
                case .sideBySide:
                    sideBySideView(file)
                case .unified:
                    unifiedView(file)
                }

                Divider().overlay(AnvilColor.borderSubtle)
                navigationBar
            } else {
                emptyState
            }
        }
        .onChange(of: viewModel.selectedFileID) { _, _ in
            if viewModel.isBlameVisible {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.loadBlameForCurrentFile(using: adapter)
            }
        }
    }

    // MARK: - File Header

    private func fileHeader(_ file: FileDiff) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            Image(systemName: iconForStatus(file.status))
                .font(.system(size: 12))
                .foregroundStyle(colorForStatus(file.status))

            Text(file.filePath)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Spacer()

            // View mode toggle
            Picker("View", selection: $viewModel.diffViewMode) {
                ForEach(DiffViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            // Blame toggle
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.toggleBlame(using: adapter)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 11))
                    Text("Blame")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(viewModel.isBlameVisible ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, 4)
                .background(viewModel.isBlameVisible ? AnvilColor.accentBlue.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Toggle git blame annotations")

            // File-level actions
            AnvilButton("Approve", icon: "checkmark", style: .primary) {
                for hunk in file.hunks {
                    viewModel.approveHunk(hunk.id)
                }
            }

            AnvilButton("Reject", icon: "xmark", style: .destructive) {
                for hunk in file.hunks {
                    viewModel.rejectHunk(hunk.id)
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Side-by-Side

    private func sideBySideView(_ file: FileDiff) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(file.hunks.enumerated()), id: \.element.id) { index, hunk in
                        hunkHeader(hunk, index: index)
                        sideBySideHunk(hunk)
                    }
                }
            }
            .onChange(of: viewModel.focusedHunkIndex) { _, newIndex in
                if newIndex < file.hunks.count {
                    withAnimation(AnvilAnimation.standard) {
                        proxy.scrollTo(file.hunks[newIndex].id, anchor: .top)
                    }
                }
            }
        }
    }

    private func sideBySideHunk(_ hunk: DiffHunk) -> some View {
        let oldLines = hunk.lines.filter { $0.type != .added }
        let newLines = hunk.lines.filter { $0.type != .removed }
        let rowCount = max(oldLines.count, newLines.count)

        return VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { i in
                HStack(spacing: 0) {
                    // Old side
                    if i < oldLines.count {
                        lineCell(
                            lineNumber: oldLines[i].oldLineNumber,
                            content: oldLines[i].content,
                            type: oldLines[i].type,
                            side: .old
                        )
                    } else {
                        emptyLineCell(side: .old)
                    }

                    // Separator
                    Rectangle()
                        .fill(AnvilColor.borderSubtle)
                        .frame(width: 1)

                    // New side
                    if i < newLines.count {
                        lineCell(
                            lineNumber: newLines[i].newLineNumber,
                            content: newLines[i].content,
                            type: newLines[i].type,
                            side: .new
                        )
                    } else {
                        emptyLineCell(side: .new)
                    }
                }
            }
        }
    }

    // MARK: - Unified

    private func unifiedView(_ file: FileDiff) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(file.hunks.enumerated()), id: \.element.id) { index, hunk in
                        hunkHeader(hunk, index: index)
                        ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                            unifiedLine(line)
                        }
                    }
                }
            }
            .onChange(of: viewModel.focusedHunkIndex) { _, newIndex in
                if newIndex < file.hunks.count {
                    withAnimation(AnvilAnimation.standard) {
                        proxy.scrollTo(file.hunks[newIndex].id, anchor: .top)
                    }
                }
            }
        }
    }

    @State private var hoveredLineKey: String?

    private func unifiedLine(_ line: DiffLine) -> some View {
        let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 0
        let lineKey = "\(viewModel.selectedFileID ?? ""):\(lineNum)"
        let hasComments = viewModel.selectedFileID != nil && !viewModel.inlineCommentsForLine(fileId: viewModel.selectedFileID!, lineNumber: lineNum).isEmpty
        let isCommentTarget = viewModel.activeCommentLine?.fileId == viewModel.selectedFileID && viewModel.activeCommentLine?.lineNumber == lineNum

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Blame gutter
                if viewModel.isBlameVisible, let ln = line.oldLineNumber ?? line.newLineNumber,
                   let blame = viewModel.blameData[ln] {
                    blameGutter(blame)
                } else if viewModel.isBlameVisible {
                    Color.clear.frame(width: 160)
                }

                // Comment button gutter
                ZStack {
                    if hoveredLineKey == lineKey || hasComments {
                        Button {
                            if let fileId = viewModel.selectedFileID {
                                viewModel.startInlineComment(fileId: fileId, lineNumber: lineNum, side: .new)
                            }
                        } label: {
                            Image(systemName: hasComments ? "bubble.left.fill" : "plus.bubble")
                                .font(.system(size: 10))
                                .foregroundStyle(hasComments ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 20)

                // Old line number
                Text(line.oldLineNumber.map(String.init) ?? "")
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, AnvilSpacing.xs)

                // New line number
                Text(line.newLineNumber.map(String.init) ?? "")
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, AnvilSpacing.xs)

                // Prefix
                Text(prefixFor(line.type))
                    .font(AnvilFont.code)
                    .foregroundStyle(textColorFor(line.type))
                    .frame(width: 16)

                // Content
                Text(line.content)
                    .font(AnvilFont.code)
                    .foregroundStyle(textColorFor(line.type))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 1)
            .background(backgroundColorFor(line.type))
            .contentShape(Rectangle())
            .onHover { isHovered in
                hoveredLineKey = isHovered ? lineKey : nil
            }

            // Existing inline comments for this line
            if let fileId = viewModel.selectedFileID {
                let comments = viewModel.inlineCommentsForLine(fileId: fileId, lineNumber: lineNum)
                if !comments.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(comments) { comment in
                            inlineCommentBubble(comment)
                        }
                    }
                    .padding(.leading, 120)
                    .padding(.vertical, AnvilSpacing.xxs)
                    .background(AnvilColor.backgroundSecondary.opacity(0.5))
                }
            }

            // Inline comment input
            if isCommentTarget {
                inlineCommentInput
                    .padding(.leading, 120)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.backgroundSecondary)
            }
        }
    }

    private func inlineCommentBubble(_ comment: InlineComment) -> some View {
        HStack(alignment: .top, spacing: AnvilSpacing.xs) {
            Circle()
                .fill(AnvilColor.accentBlue.opacity(0.15))
                .frame(width: 18, height: 18)
                .overlay(
                    Text(String(comment.author.prefix(1)))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AnvilColor.accentBlue)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AnvilSpacing.xs) {
                    Text(comment.author)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textPrimary)
                    Text(comment.createdAt, style: .relative)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                Text(comment.body)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .textSelection(.enabled)
            }
        }
        .padding(AnvilSpacing.sm)
        .background(AnvilColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var inlineCommentInput: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
            TextEditor(text: $viewModel.inlineCommentText)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 48, maxHeight: 100)
                .padding(AnvilSpacing.xs)
                .background(AnvilColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AnvilColor.accentBlue.opacity(0.4), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.cancelInlineComment()
                }
                .buttonStyle(.plain)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

                Button("Comment") {
                    viewModel.submitInlineComment()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    viewModel.inlineCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AnvilColor.textTertiary
                        : AnvilColor.accentBlue
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .disabled(viewModel.inlineCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AnvilSpacing.sm)
    }

    // MARK: - Shared Line Components

    private enum LineSide { case old, new }

    private func lineCell(lineNumber: Int?, content: String, type: DiffLineType, side: LineSide) -> some View {
        HStack(spacing: 0) {
            // Blame gutter (old side only)
            if viewModel.isBlameVisible && side == .old, let ln = lineNumber, let blame = viewModel.blameData[ln] {
                blameGutter(blame)
            }

            Text(lineNumber.map(String.init) ?? "")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, AnvilSpacing.xs)

            Text(prefixFor(type))
                .font(AnvilFont.code)
                .foregroundStyle(textColorFor(type))
                .frame(width: 14)

            Text(content)
                .font(AnvilFont.code)
                .foregroundStyle(textColorFor(type))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity)
        .background(backgroundColorFor(type))
    }

    private func emptyLineCell(side: LineSide) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 20)
            .background(AnvilColor.backgroundPrimary.opacity(0.5))
    }

    // MARK: - Hunk Header

    private func hunkHeader(_ hunk: DiffHunk, index: Int) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Text(hunk.header)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .lineLimit(1)

            Spacer()

            let decision = viewModel.decisionFor(hunk.id)

            if decision != .pending {
                AnvilBadge(
                    text: decision == .approved ? "Approved" : "Rejected",
                    color: decision == .approved ? AnvilColor.accentGreen : AnvilColor.accentRed
                )
            }

            Button {
                viewModel.approveHunk(hunk.id)
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        decision == .approved ? AnvilColor.accentGreen : AnvilColor.textTertiary
                    )
                    .frame(width: 24, height: 24)
                    .background(
                        decision == .approved
                            ? AnvilColor.accentGreen.opacity(0.15)
                            : AnvilColor.backgroundTertiary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Approve hunk")

            Button {
                viewModel.rejectHunk(hunk.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        decision == .rejected ? AnvilColor.accentRed : AnvilColor.textTertiary
                    )
                    .frame(width: 24, height: 24)
                    .background(
                        decision == .rejected
                            ? AnvilColor.accentRed.opacity(0.15)
                            : AnvilColor.backgroundTertiary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Reject hunk")
        }
        .id(hunk.id)
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(
            index == viewModel.focusedHunkIndex
                ? AnvilColor.selectionBackground
                : AnvilColor.backgroundTertiary
        )
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: AnvilSpacing.lg) {
            keyHint("n", "next hunk")
            keyHint("p", "prev hunk")
            keyHint("a", "approve hunk")
            keyHint("r", "reject hunk")

            Spacer()

            // Hunk decision summary
            let summary = viewModel.hunkDecisionSummary
            if summary.total > 0 {
                HStack(spacing: AnvilSpacing.sm) {
                    if summary.approved > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("\(summary.approved)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentGreen)
                    }
                    if summary.rejected > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                            Text("\(summary.rejected)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentRed)
                    }
                    if summary.pending > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "circle")
                                .font(.system(size: 10))
                            Text("\(summary.pending)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
            }

            if let file = viewModel.selectedFile {
                Text("Hunk \(viewModel.focusedHunkIndex + 1) of \(file.hunks.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Merge button for branch diffs
            if viewModel.selectedBranchName != nil {
                mergeButton
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Merge Button

    private var mergeButton: some View {
        HStack(spacing: AnvilSpacing.sm) {
            if viewModel.isMerging {
                ProgressView()
                    .controlSize(.small)
            }

            if let error = viewModel.mergeError {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(error)
                        .font(AnvilFont.label)
                        .lineLimit(1)
                }
                .foregroundStyle(AnvilColor.accentRed)
            }

            if case .alreadyUpToDate = viewModel.mergeResult {
                Text("Already up to date")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            if case .success = viewModel.mergeResult {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Merged")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.accentGreen)
            }

            AnvilButton("Merge Branch", icon: "arrow.triangle.merge", style: .primary) {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.mergeSelectedBranch(using: adapter)
            }
            .disabled(viewModel.isMerging)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)
            Text("Select a file to review")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Blame Gutter

    private func blameGutter(_ blame: BlameLine) -> some View {
        HStack(spacing: AnvilSpacing.xxs) {
            Text(blame.author.components(separatedBy: " ").first ?? blame.author)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AnvilColor.textTertiary)
                .lineLimit(1)
                .frame(width: 80, alignment: .trailing)

            Text(blame.commitHash.prefix(7))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AnvilColor.accentBlue.opacity(0.7))
                .frame(width: 55, alignment: .leading)

            Text(blame.date, style: .offset)
                .font(.system(size: 9))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.6))
                .frame(width: 20, alignment: .trailing)
        }
        .frame(width: 160)
        .padding(.trailing, AnvilSpacing.xxs)
    }

    // MARK: - Helpers

    private func prefixFor(_ type: DiffLineType) -> String {
        switch type {
        case .added: "+"
        case .removed: "-"
        case .context: " "
        }
    }

    private func textColorFor(_ type: DiffLineType) -> Color {
        switch type {
        case .added: AnvilColor.diffAddedText
        case .removed: AnvilColor.diffRemovedText
        case .context: AnvilColor.textPrimary
        }
    }

    private func backgroundColorFor(_ type: DiffLineType) -> Color {
        switch type {
        case .added: Color(AnvilColor.diffAddedBackground)
        case .removed: Color(AnvilColor.diffRemovedBackground)
        case .context: Color.clear
        }
    }

    private func iconForStatus(_ status: DiffFileStatus) -> String {
        switch status {
        case .added: "plus.circle.fill"
        case .modified: "pencil.circle.fill"
        case .deleted: "minus.circle.fill"
        case .renamed: "arrow.right.circle.fill"
        case .copied: "doc.on.doc.fill"
        }
    }

    private func colorForStatus(_ status: DiffFileStatus) -> Color {
        switch status {
        case .added: AnvilColor.accentGreen
        case .modified: AnvilColor.accentAmber
        case .deleted: AnvilColor.accentRed
        case .renamed: AnvilColor.accentBlue
        case .copied: AnvilColor.accentPurple
        }
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: AnvilSpacing.xxxs) {
            Text(key)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(AnvilColor.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(AnvilColor.borderMedium, lineWidth: 1)
                )
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
    }
}
