import SwiftUI

// MARK: - Models

struct SearchMatch: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let lineContent: String
    let matchRange: Range<String.Index>

    var matchText: String {
        String(lineContent[matchRange])
    }
}

struct FileSearchResult: Identifiable {
    let id = UUID()
    let filePath: String
    let fileName: String
    let matches: [SearchMatch]
}

// MARK: - ViewModel

@MainActor
final class ProjectSearchViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet { searchIfNeeded() }
    }
    @Published var replaceText: String = ""
    @Published var matchCase: Bool = false {
        didSet { searchIfNeeded() }
    }
    @Published var useRegex: Bool = false {
        didSet { searchIfNeeded() }
    }
    @Published var wholeWord: Bool = false {
        didSet { searchIfNeeded() }
    }
    @Published var fileFilter: String = "" {
        didSet { searchIfNeeded() }
    }
    @Published var isReplaceExpanded: Bool = false
    @Published var results: [FileSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var collapsedFiles: Set<String> = []

    /// The project root to search. Set by the owning view from AppState.currentProjectPath.
    var projectPath: String?

    var totalMatchCount: Int {
        results.reduce(0) { $0 + $1.matches.count }
    }

    var fileCount: Int {
        results.count
    }

    private var searchTask: Task<Void, Never>?

    private func searchIfNeeded() {
        searchTask?.cancel()
        guard searchText.count >= 2 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    func performSearch() async {
        guard !searchText.isEmpty else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }

        guard let root = projectPath else {
            results = []
            return
        }

        // Use grep for fast project-wide search
        let grepResults = await runGrep(query: searchText, root: root)
        guard !Task.isCancelled else { return }

        var grouped: [String: [SearchMatch]] = [:]

        for match in grepResults {
            if Task.isCancelled { return }

            // Apply file filter
            if !fileFilter.isEmpty {
                let patterns = fileFilter.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let matchesFilter = patterns.contains { pattern in
                    if pattern.hasPrefix("*.") {
                        let ext = String(pattern.dropFirst(2))
                        return match.filePath.hasSuffix(".\(ext)")
                    }
                    return match.filePath.contains(pattern)
                }
                if !matchesFilter { continue }
            }

            // Find exact match ranges within the line for highlighting
            let ranges = findMatchRanges(in: match.lineContent)
            for range in ranges {
                let sm = SearchMatch(
                    lineNumber: match.lineNumber,
                    lineContent: match.lineContent,
                    matchRange: range
                )
                grouped[match.filePath, default: []].append(sm)
            }
        }

        var newResults: [FileSearchResult] = []
        for (path, matches) in grouped.sorted(by: { $0.key < $1.key }) {
            let displayPath = path.hasPrefix(root) ? String(path.dropFirst(root.count + 1)) : path
            let fileName = (path as NSString).lastPathComponent
            newResults.append(FileSearchResult(
                filePath: displayPath,
                fileName: fileName,
                matches: matches
            ))
        }

        results = newResults
    }

    // MARK: - Grep Subprocess

    private struct GrepMatch {
        let filePath: String
        let lineNumber: Int
        let lineContent: String
    }

    private func runGrep(query: String, root: String) async -> [GrepMatch] {
        let matchCase = self.matchCase
        let wholeWord = self.wholeWord
        let useRegex = self.useRegex

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var args: [String] = ["-rn", "--max-count=200"]

                // Exclude common noise directories
                for dir in [".git", ".build", "node_modules", "DerivedData", ".swiftpm", "Pods"] {
                    args.append(contentsOf: ["--exclude-dir=\(dir)"])
                }
                // Exclude binary files
                args.append("-I")

                if !matchCase {
                    args.append("-i")
                }
                if wholeWord {
                    args.append("-w")
                }
                if useRegex {
                    args.append("-E")
                } else {
                    args.append("-F")
                }

                args.append(query)
                args.append(root)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
                process.arguments = args

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: [])
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                guard let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(returning: [])
                    return
                }

                var matches: [GrepMatch] = []
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    guard !line.isEmpty else { continue }
                    // Format: filepath:lineNumber:content
                    guard let firstColon = line.firstIndex(of: ":") else { continue }
                    let filePath = String(line[line.startIndex..<firstColon])
                    let rest = line[line.index(after: firstColon)...]
                    guard let secondColon = rest.firstIndex(of: ":") else { continue }
                    guard let lineNum = Int(rest[rest.startIndex..<secondColon]) else { continue }
                    let content = String(rest[rest.index(after: secondColon)...])
                    matches.append(GrepMatch(filePath: filePath, lineNumber: lineNum, lineContent: content))
                }

                continuation.resume(returning: matches)
            }
        }
    }

    private func findMatchRanges(in line: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []

        if useRegex {
            var options: NSRegularExpression.Options = []
            if !matchCase { options.insert(.caseInsensitive) }
            guard let regex = try? NSRegularExpression(pattern: searchText, options: options) else {
                return []
            }
            let nsRange = NSRange(line.startIndex..., in: line)
            let nsMatches = regex.matches(in: line, range: nsRange)
            for m in nsMatches {
                if let range = Range(m.range, in: line) {
                    ranges.append(range)
                }
            }
        } else {
            let searchIn = matchCase ? line : line.lowercased()
            let searchFor = matchCase ? searchText : searchText.lowercased()

            var startIndex = searchIn.startIndex
            while let range = searchIn.range(of: searchFor, range: startIndex..<searchIn.endIndex) {
                // Whole word check
                if wholeWord {
                    let before = range.lowerBound == searchIn.startIndex
                        || !searchIn[searchIn.index(before: range.lowerBound)].isLetter
                    let after = range.upperBound == searchIn.endIndex
                        || !searchIn[range.upperBound].isLetter
                    if !before || !after {
                        startIndex = range.upperBound
                        continue
                    }
                }
                // Map back to original line indices
                let offset = searchIn.distance(from: searchIn.startIndex, to: range.lowerBound)
                let length = searchIn.distance(from: range.lowerBound, to: range.upperBound)
                let origStart = line.index(line.startIndex, offsetBy: offset)
                let origEnd = line.index(origStart, offsetBy: length)
                ranges.append(origStart..<origEnd)
                startIndex = range.upperBound
            }
        }

        return ranges
    }

    func toggleFileCollapsed(_ filePath: String) {
        if collapsedFiles.contains(filePath) {
            collapsedFiles.remove(filePath)
        } else {
            collapsedFiles.insert(filePath)
        }
    }

    func replaceAllInFile(_ filePath: String) {
        guard let root = projectPath, !replaceText.isEmpty else { return }
        let fullPath = filePath.hasPrefix("/") ? filePath : (root as NSString).appendingPathComponent(filePath)
        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { return }
        let replaced = applyReplacements(in: content)
        try? replaced.write(toFile: fullPath, atomically: true, encoding: .utf8)
        results.removeAll { $0.filePath == filePath }
    }

    func replaceAll() {
        guard let root = projectPath, !replaceText.isEmpty else { return }
        for result in results {
            let fullPath = result.filePath.hasPrefix("/") ? result.filePath : (root as NSString).appendingPathComponent(result.filePath)
            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }
            let replaced = applyReplacements(in: content)
            try? replaced.write(toFile: fullPath, atomically: true, encoding: .utf8)
        }
        results.removeAll()
    }

    private func applyReplacements(in content: String) -> String {
        if useRegex {
            var options: NSRegularExpression.Options = []
            if !matchCase { options.insert(.caseInsensitive) }
            guard let regex = try? NSRegularExpression(pattern: searchText, options: options) else { return content }
            return regex.stringByReplacingMatches(in: content, range: NSRange(content.startIndex..., in: content), withTemplate: replaceText)
        } else {
            var options: String.CompareOptions = []
            if !matchCase { options.insert(.caseInsensitive) }
            return content.replacingOccurrences(of: searchText, with: replaceText, options: options)
        }
    }

    func clear() {
        searchText = ""
        replaceText = ""
        results = []
        collapsedFiles = []
    }

}
