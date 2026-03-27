import Foundation
import AnvilDomain

struct DiffParser: Sendable {

    func parse(_ raw: String) -> [FileDiff] {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var diffs: [FileDiff] = []
        // Split on "diff --git" boundaries, keeping the delimiter
        let fileSections = splitOnDiffHeaders(raw)

        for section in fileSections {
            if let fileDiff = parseFileSection(section) {
                diffs.append(fileDiff)
            }
        }

        return diffs
    }

    // MARK: - Private

    private func splitOnDiffHeaders(_ raw: String) -> [String] {
        let pattern = "diff --git "
        var sections: [String] = []
        var remaining = raw[raw.startIndex...]

        while let range = remaining.range(of: pattern) {
            // Everything before this match belongs to the previous section (discard if first)
            let beforeMatch = remaining[remaining.startIndex..<range.lowerBound]
            if !sections.isEmpty {
                sections[sections.count - 1] += String(beforeMatch)
            }

            remaining = remaining[range.lowerBound...]

            // Find the next occurrence
            let afterStart = remaining.index(after: remaining.startIndex)
            if let nextRange = remaining[afterStart...].range(of: pattern) {
                sections.append(String(remaining[remaining.startIndex..<nextRange.lowerBound]))
                remaining = remaining[nextRange.lowerBound...]
            } else {
                sections.append(String(remaining))
                remaining = remaining[remaining.endIndex...]
            }
        }

        return sections
    }

    private func parseFileSection(_ section: String) -> FileDiff? {
        let lines = section.components(separatedBy: "\n")
        guard let firstLine = lines.first, firstLine.hasPrefix("diff --git ") else {
            return nil
        }

        // Parse file paths from "diff --git a/path b/path"
        let paths = parseGitDiffHeader(firstLine)
        let filePath = paths.new
        let oldPath = paths.old != paths.new ? paths.old : nil

        // Detect binary
        if lines.contains(where: { $0.hasPrefix("Binary files") }) {
            return FileDiff(filePath: filePath, oldPath: oldPath, status: .modified, hunks: [], isBinary: true)
        }

        // Detect status from header lines
        let status = detectStatus(lines: lines, oldPath: paths.old, newPath: paths.new)

        // Parse hunks
        let hunks = parseHunks(lines: lines)

        return FileDiff(filePath: filePath, oldPath: oldPath, status: status, hunks: hunks, isBinary: false)
    }

    private func parseGitDiffHeader(_ line: String) -> (old: String, new: String) {
        // "diff --git a/foo.swift b/foo.swift"
        let stripped = line.dropFirst("diff --git ".count)
        let parts = stripped.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else {
            let path = String(stripped).replacingOccurrences(of: "a/", with: "").replacingOccurrences(of: "b/", with: "")
            return (path, path)
        }
        let oldPath = String(parts[0]).hasPrefix("a/") ? String(parts[0].dropFirst(2)) : String(parts[0])
        let newPath = String(parts[1]).hasPrefix("b/") ? String(parts[1].dropFirst(2)) : String(parts[1])
        return (oldPath, newPath)
    }

    private func detectStatus(lines: [String], oldPath: String, newPath: String) -> DiffFileStatus {
        for line in lines {
            if line.hasPrefix("new file mode") { return .added }
            if line.hasPrefix("deleted file mode") { return .deleted }
            if line.hasPrefix("rename from") || line.hasPrefix("similarity index") { return .renamed }
            if line.hasPrefix("copy from") { return .copied }
        }
        return .modified
    }

    private func parseHunks(lines: [String]) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var currentHunkLines: [DiffLine] = []
        var currentHeader = ""
        var oldStart = 0
        var oldCount = 0
        var newStart = 0
        var newCount = 0
        var inHunk = false
        var oldLine = 0
        var newLine = 0

        for line in lines {
            if line.hasPrefix("@@") {
                // Save previous hunk
                if inHunk {
                    hunks.append(DiffHunk(
                        oldStart: oldStart, oldCount: oldCount,
                        newStart: newStart, newCount: newCount,
                        header: currentHeader, lines: currentHunkLines
                    ))
                }

                // Parse hunk header: @@ -old,count +new,count @@ optional context
                let parsed = parseHunkHeader(line)
                oldStart = parsed.oldStart
                oldCount = parsed.oldCount
                newStart = parsed.newStart
                newCount = parsed.newCount
                currentHeader = line
                currentHunkLines = []
                inHunk = true
                oldLine = oldStart
                newLine = newStart
            } else if inHunk {
                if line.hasPrefix("+") {
                    currentHunkLines.append(DiffLine(
                        type: .added,
                        content: String(line.dropFirst()),
                        oldLineNumber: nil,
                        newLineNumber: newLine
                    ))
                    newLine += 1
                } else if line.hasPrefix("-") {
                    currentHunkLines.append(DiffLine(
                        type: .removed,
                        content: String(line.dropFirst()),
                        oldLineNumber: oldLine,
                        newLineNumber: nil
                    ))
                    oldLine += 1
                } else if line.hasPrefix(" ") || line.isEmpty {
                    let content = line.isEmpty ? "" : String(line.dropFirst())
                    currentHunkLines.append(DiffLine(
                        type: .context,
                        content: content,
                        oldLineNumber: oldLine,
                        newLineNumber: newLine
                    ))
                    oldLine += 1
                    newLine += 1
                }
                // Ignore \ No newline at end of file and other non-diff lines
            }
        }

        // Save last hunk
        if inHunk {
            hunks.append(DiffHunk(
                oldStart: oldStart, oldCount: oldCount,
                newStart: newStart, newCount: newCount,
                header: currentHeader, lines: currentHunkLines
            ))
        }

        return hunks
    }

    private func parseHunkHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int) {
        // @@ -1,3 +1,4 @@
        let scanner = Scanner(string: line)
        scanner.charactersToBeSkipped = nil

        _ = scanner.scanString("@@ -")
        let oldStartVal = scanner.scanInt() ?? 0
        var oldCountVal = 1
        if scanner.scanString(",") != nil {
            oldCountVal = scanner.scanInt() ?? 1
        }
        _ = scanner.scanString(" +")
        let newStartVal = scanner.scanInt() ?? 0
        var newCountVal = 1
        if scanner.scanString(",") != nil {
            newCountVal = scanner.scanInt() ?? 1
        }

        return (oldStartVal, oldCountVal, newStartVal, newCountVal)
    }
}
