import Foundation
import AnvilDomain

/// Represents a single auto-generated memory entry from an agent session.
public struct MemoryEntry: Sendable, Codable, Identifiable {
    public let id: String
    public let sessionId: String
    public let timestamp: Date
    public let category: MemoryCategory
    public let summary: String
    public let detail: String?

    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        timestamp: Date = .now,
        category: MemoryCategory,
        summary: String,
        detail: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.category = category
        self.summary = summary
        self.detail = detail
    }
}

public enum MemoryCategory: String, Sendable, Codable, CaseIterable {
    case fileCreated = "file_created"
    case fileModified = "file_modified"
    case bugFixed = "bug_fixed"
    case decision = "decision"
    case dependency = "dependency"
    case architecture = "architecture"
    case other = "other"

    public var icon: String {
        switch self {
        case .fileCreated: "doc.badge.plus"
        case .fileModified: "doc.badge.arrow.up"
        case .bugFixed: "ladybug"
        case .decision: "lightbulb"
        case .dependency: "shippingbox"
        case .architecture: "building.columns"
        case .other: "brain"
        }
    }

    public var displayName: String {
        switch self {
        case .fileCreated: "File Created"
        case .fileModified: "File Modified"
        case .bugFixed: "Bug Fixed"
        case .decision: "Decision"
        case .dependency: "Dependency"
        case .architecture: "Architecture"
        case .other: "Note"
        }
    }
}

/// Scans completed agent sessions for notable events and persists memory entries.
public actor MemoryService {

    private let storagePath: String
    private var entries: [MemoryEntry] = []

    public init(storagePath: String? = nil) {
        self.storagePath = storagePath ?? (NSHomeDirectory() + "/.anvil/memories.json")
    }

    // MARK: - Persistence

    public func loadEntries() throws -> [MemoryEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storagePath),
              let data = fm.contents(atPath: storagePath) else {
            entries = []
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = try decoder.decode([MemoryEntry].self, from: data)
        return entries
    }

    public func saveEntries() throws {
        let fm = FileManager.default
        let directory = (storagePath as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: directory) {
            try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: URL(fileURLWithPath: storagePath))
    }

    public func allEntries() -> [MemoryEntry] {
        entries
    }

    public func deleteEntry(id: String) throws {
        entries.removeAll { $0.id == id }
        try saveEntries()
    }

    // MARK: - Session Scanning

    /// Scan a completed agent session and extract memory entries.
    public func scanSession(_ session: AgentSession) throws -> [MemoryEntry] {
        var newEntries: [MemoryEntry] = []

        for message in session.messages {
            // Scan tool calls for file operations
            for toolCall in message.toolCalls {
                if let entry = extractFromToolCall(toolCall, sessionId: session.id) {
                    newEntries.append(entry)
                }
            }

            // Scan assistant messages for decisions and bug fixes
            if message.role == .assistant {
                newEntries += extractFromContent(message.content, sessionId: session.id)
            }
        }

        // Deduplicate by summary
        let existingSummaries = Set(entries.map(\.summary))
        let unique = newEntries.filter { !existingSummaries.contains($0.summary) }

        entries.append(contentsOf: unique)
        try saveEntries()

        return unique
    }

    // MARK: - Extraction

    private func extractFromToolCall(_ toolCall: ToolCall, sessionId: String) -> MemoryEntry? {
        switch toolCall.name.lowercased() {
        case "write_file", "create_file":
            guard let path = extractPath(from: toolCall.arguments) else { return nil }
            let isNew = toolCall.name.lowercased() == "create_file"
            return MemoryEntry(
                sessionId: sessionId,
                category: isNew ? .fileCreated : .fileModified,
                summary: "\(isNew ? "Created" : "Modified") \(lastPathComponent(path))",
                detail: path
            )
        default:
            return nil
        }
    }

    private func extractFromContent(_ content: String, sessionId: String) -> [MemoryEntry] {
        var results: [MemoryEntry] = []
        let lower = content.lowercased()

        // Detect bug fix patterns
        let bugPatterns = ["fixed the bug", "fixed a bug", "the fix is", "bug was caused by", "resolved the issue", "the issue was"]
        for pattern in bugPatterns {
            if lower.contains(pattern) {
                let summary = extractSentence(containing: pattern, from: content)
                results.append(MemoryEntry(
                    sessionId: sessionId,
                    category: .bugFixed,
                    summary: summary ?? "Bug fixed",
                    detail: nil
                ))
                break
            }
        }

        // Detect architecture decisions
        let decisionPatterns = ["decided to", "the approach is", "we should", "i recommend", "the best approach"]
        for pattern in decisionPatterns {
            if lower.contains(pattern) {
                let summary = extractSentence(containing: pattern, from: content)
                results.append(MemoryEntry(
                    sessionId: sessionId,
                    category: .decision,
                    summary: summary ?? "Architecture decision made",
                    detail: nil
                ))
                break
            }
        }

        return results
    }

    private func extractPath(from arguments: String) -> String? {
        // Try JSON parsing first
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let path = json["path"] as? String {
            return path
        }
        // Fallback: look for a path-like string
        let pattern = #"["\']?(/[^\s"\']+)["\']?"#
        if let range = arguments.range(of: pattern, options: .regularExpression) {
            return String(arguments[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }

    private func extractSentence(containing pattern: String, from text: String) -> String? {
        let lower = text.lowercased()
        guard let range = lower.range(of: pattern) else { return nil }

        // Find sentence boundaries
        let startIdx = text.startIndex
        var sentenceStart = range.lowerBound
        while sentenceStart > startIdx {
            let prev = text.index(before: sentenceStart)
            if text[prev] == "." || text[prev] == "\n" {
                sentenceStart = text.index(after: prev)
                break
            }
            sentenceStart = prev
        }

        var sentenceEnd = range.upperBound
        while sentenceEnd < text.endIndex {
            if text[sentenceEnd] == "." || text[sentenceEnd] == "\n" {
                sentenceEnd = text.index(after: sentenceEnd)
                break
            }
            sentenceEnd = text.index(after: sentenceEnd)
        }

        let sentence = String(text[sentenceStart..<sentenceEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLen = 120
        if sentence.count > maxLen {
            return String(sentence.prefix(maxLen)) + "..."
        }
        return sentence
    }

    private func lastPathComponent(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }
}

// MARK: - Project Rules

/// Reads and writes the project-level rules file (.anvil/rules.md).
public struct ProjectRulesService: Sendable {

    public init() {}

    /// Read the project rules from .anvil/rules.md relative to the project path.
    public func loadRules(projectPath: String) -> String? {
        let rulesPath = (projectPath as NSString).appendingPathComponent(".anvil/rules.md")
        guard FileManager.default.fileExists(atPath: rulesPath),
              let data = FileManager.default.contents(atPath: rulesPath),
              let content = String(data: data, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return content
    }

    /// Save project rules to .anvil/rules.md.
    public func saveRules(_ content: String, projectPath: String) throws {
        let anvilDir = (projectPath as NSString).appendingPathComponent(".anvil")
        let rulesPath = (anvilDir as NSString).appendingPathComponent("rules.md")

        let fm = FileManager.default
        if !fm.fileExists(atPath: anvilDir) {
            try fm.createDirectory(atPath: anvilDir, withIntermediateDirectories: true)
        }

        guard let data = content.data(using: .utf8) else { return }
        try data.write(to: URL(fileURLWithPath: rulesPath))
    }

    /// Returns the path to the rules file (for display).
    public func rulesPath(projectPath: String) -> String {
        (projectPath as NSString).appendingPathComponent(".anvil/rules.md")
    }
}
