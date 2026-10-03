import Foundation
import AnvilDomain

/// Scores and ranks project files for relevance to the current agent conversation.
/// Returns the top-N files as auto-context candidates that can be injected into
/// agent message assembly.
@MainActor
public final class AutoContextService: ObservableObject {

    /// A scored file candidate for auto-context injection.
    public struct ScoredFile: Identifiable, Sendable {
        public let id: String
        public let path: String
        public let name: String
        public let score: Double
        public let reason: Reason

        public enum Reason: String, Sendable {
            case mentionedInMessage = "Mentioned"
            case recentlyEdited = "Recently edited"
            case sameDirectory = "Same directory"
            case keywordMatch = "Keyword match"
        }
    }

    /// The most recently computed auto-context suggestions.
    @Published public private(set) var suggestions: [ScoredFile] = []

    /// Whether auto-context inference is enabled.
    @Published public var isEnabled: Bool = true

    /// Maximum number of files to suggest.
    public let maxSuggestions = 5

    /// Paths of files the user has explicitly dismissed from auto-context in this session.
    private var dismissedPaths: Set<String> = []

    public init() {}

    // MARK: - Scoring

    /// Score project files for relevance and update `suggestions`.
    ///
    /// - Parameters:
    ///   - messageText: The current user message being composed.
    ///   - recentMessages: Messages from the current session for mention detection.
    ///   - recentlyEditedPaths: Paths of files recently edited in the editor.
    ///   - focusedFilePath: Path of the currently focused file in the editor.
    ///   - projectFiles: All project file paths to score against.
    public func score(
        messageText: String,
        recentMessages: [AgentMessage],
        recentlyEditedPaths: [String],
        focusedFilePath: String?,
        projectFiles: [String]
    ) {
        guard isEnabled else {
            suggestions = []
            return
        }

        var scored: [String: (score: Double, reason: ScoredFile.Reason)] = [:]

        // 1. Files mentioned in the current message (highest weight)
        let messageWords = extractWords(from: messageText)
        for path in projectFiles {
            let fileName = fileNameWithoutExtension(path)
            let fileNameFull = URL(fileURLWithPath: path).lastPathComponent
            if messageText.contains(fileNameFull) || messageText.contains(path) {
                addScore(&scored, path: path, score: 50, reason: .mentionedInMessage)
            } else if messageWords.contains(fileName.lowercased()) {
                addScore(&scored, path: path, score: 40, reason: .mentionedInMessage)
            }
        }

        // 2. Files mentioned in recent messages
        let recentText = recentMessages.suffix(6).map(\.content).joined(separator: " ")
        let recentWords = extractWords(from: recentText)
        for path in projectFiles {
            let fileName = fileNameWithoutExtension(path).lowercased()
            let fileNameFull = URL(fileURLWithPath: path).lastPathComponent
            if recentText.contains(fileNameFull) {
                addScore(&scored, path: path, score: 30, reason: .mentionedInMessage)
            } else if recentWords.contains(fileName) {
                addScore(&scored, path: path, score: 20, reason: .mentionedInMessage)
            }
        }

        // 3. Recently edited files
        // Only files that belong to the project are suggested.
        let projectFileSet = Set(projectFiles)
        for (index, path) in recentlyEditedPaths.prefix(10).enumerated() where projectFileSet.contains(path) {
            let recencyBonus = Double(10 - index) * 3.0
            addScore(&scored, path: path, score: 25 + recencyBonus, reason: .recentlyEdited)
        }

        // 4. Files in same directory as focused file
        if let focusedPath = focusedFilePath {
            let focusedDir = (focusedPath as NSString).deletingLastPathComponent
            for path in projectFiles where path != focusedPath {
                let dir = (path as NSString).deletingLastPathComponent
                if dir == focusedDir {
                    addScore(&scored, path: path, score: 15, reason: .sameDirectory)
                }
            }
        }

        // 5. Keyword match: words in the message matching parts of file names
        if messageWords.count > 0 {
            for path in projectFiles {
                let parts = fileNameParts(path)
                let matchCount = parts.filter { messageWords.contains($0) }.count
                if matchCount > 0 {
                    addScore(&scored, path: path, score: Double(matchCount) * 10, reason: .keywordMatch)
                }
            }
        }

        // Filter dismissed, sort by score, take top N
        let results = scored
            .filter { !dismissedPaths.contains($0.key) }
            .sorted { $0.value.score > $1.value.score }
            .prefix(maxSuggestions)
            .map { entry in
                ScoredFile(
                    id: entry.key,
                    path: entry.key,
                    name: URL(fileURLWithPath: entry.key).lastPathComponent,
                    score: entry.value.score,
                    reason: entry.value.reason
                )
            }

        suggestions = results
    }

    /// Dismiss a file from auto-context suggestions for this session.
    public func dismiss(_ path: String) {
        dismissedPaths.insert(path)
        suggestions.removeAll { $0.path == path }
    }

    /// Reset dismissed paths (e.g., on session change).
    public func resetDismissals() {
        dismissedPaths.removeAll()
    }

    /// Clear all suggestions.
    public func clear() {
        suggestions = []
    }

    // MARK: - Private Helpers

    private func addScore(
        _ scored: inout [String: (score: Double, reason: ScoredFile.Reason)],
        path: String,
        score: Double,
        reason: ScoredFile.Reason
    ) {
        if let existing = scored[path] {
            // Keep the higher-scoring reason as the primary reason
            if score > existing.score {
                scored[path] = (existing.score + score, reason)
            } else {
                scored[path] = (existing.score + score, existing.reason)
            }
        } else {
            scored[path] = (score, reason)
        }
    }

    private func extractWords(from text: String) -> Set<String> {
        let cleaned = text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9_]", with: " ", options: .regularExpression)
        return Set(cleaned.components(separatedBy: .whitespaces).filter { $0.count >= 3 })
    }

    private func fileNameWithoutExtension(_ path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    /// Split a file name into searchable parts (camelCase, snake_case, kebab-case).
    private func fileNameParts(_ path: String) -> Set<String> {
        let name = fileNameWithoutExtension(path)
        var parts: [String] = []

        // Split on separators
        let segments = name.components(separatedBy: CharacterSet(charactersIn: "_-. "))
        parts.append(contentsOf: segments)

        // Split camelCase
        for segment in segments {
            parts.append(contentsOf: splitCamelCase(segment))
        }

        return Set(parts.map { $0.lowercased() }.filter { $0.count >= 3 })
    }

    private func splitCamelCase(_ str: String) -> [String] {
        var parts: [String] = []
        var current = ""
        for char in str {
            if char.isUppercase && !current.isEmpty {
                parts.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }
}
