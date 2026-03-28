import SwiftUI
import AnvilDomain
import AnvilApplication
import os.log

private let logger = Logger(subsystem: "com.anvil.app", category: "AgentViewModel+Context")

extension AgentViewModel {

    public func addAttachment(_ attachment: ContextAttachment) {
        guard !contextAttachments.contains(where: { $0.id == attachment.id }) else { return }
        contextAttachments.append(attachment)
    }

    public func removeAttachment(id: String) {
        contextAttachments.removeAll { $0.id == id }
    }

    public func clearAttachments() {
        contextAttachments.removeAll()
    }

    func buildContextPrefix() -> String {
        guard !contextAttachments.isEmpty else { return "" }
        var parts = ["[Context]"]
        for attachment in contextAttachments {
            parts.append(attachment.contextString)
        }
        parts.append("[/Context]\n\n")
        return parts.joined(separator: "\n")
    }

    public func suggestionsForCurrentSession() -> [CodeEditSuggestion] {
        guard let sessionId = selectedSessionId else { return [] }
        return editSuggestions[sessionId] ?? []
    }

    public func addEditSuggestion(_ suggestion: CodeEditSuggestion) {
        guard let sessionId = selectedSessionId else { return }
        editSuggestions[sessionId, default: []].append(suggestion)
    }

    public func acceptHunk(suggestionId: String, hunkId: String) {
        guard let sessionId = selectedSessionId else { return }
        guard var suggestions = editSuggestions[sessionId],
              let sugIdx = suggestions.firstIndex(where: { $0.id == suggestionId }),
              let hunkIdx = suggestions[sugIdx].hunks.firstIndex(where: { $0.id == hunkId }) else { return }
        suggestions[sugIdx].hunks[hunkIdx].state = .accepted
        editSuggestions[sessionId] = suggestions
        persistAcceptedHunks(for: suggestions[sugIdx])
    }

    public func rejectHunk(suggestionId: String, hunkId: String) {
        guard let sessionId = selectedSessionId else { return }
        guard var suggestions = editSuggestions[sessionId],
              let sugIdx = suggestions.firstIndex(where: { $0.id == suggestionId }),
              let hunkIdx = suggestions[sugIdx].hunks.firstIndex(where: { $0.id == hunkId }) else { return }
        suggestions[sugIdx].hunks[hunkIdx].state = .rejected
        editSuggestions[sessionId] = suggestions
    }

    public func acceptAllHunks(suggestionId: String) {
        guard let sessionId = selectedSessionId else { return }
        guard var suggestions = editSuggestions[sessionId],
              let sugIdx = suggestions.firstIndex(where: { $0.id == suggestionId }) else { return }
        for i in suggestions[sugIdx].hunks.indices {
            suggestions[sugIdx].hunks[i].state = .accepted
        }
        editSuggestions[sessionId] = suggestions
        persistAcceptedHunks(for: suggestions[sugIdx])
    }

    public func rejectAllHunks(suggestionId: String) {
        guard let sessionId = selectedSessionId else { return }
        guard var suggestions = editSuggestions[sessionId],
              let sugIdx = suggestions.firstIndex(where: { $0.id == suggestionId }) else { return }
        for i in suggestions[sugIdx].hunks.indices {
            suggestions[sugIdx].hunks[i].state = .rejected
        }
        editSuggestions[sessionId] = suggestions
    }

    func persistAcceptedHunks(for suggestion: CodeEditSuggestion) {
        let accepted = suggestion.hunks.filter { $0.state == .accepted }
        guard !accepted.isEmpty else { return }

        let filePath = suggestion.filePath
        guard let data = FileManager.default.contents(atPath: filePath),
              let text = String(data: data, encoding: .utf8) else {
            logger.warning("Cannot read file for hunk persistence: \(filePath)")
            return
        }

        var lines = text.components(separatedBy: "\n")
        let sorted = accepted.sorted { $0.oldStart > $1.oldStart }

        for hunk in sorted {
            let startIndex = hunk.oldStart - 1
            guard startIndex >= 0, startIndex <= lines.count else {
                logger.warning("Hunk oldStart \(hunk.oldStart) out of range for \(filePath) (\(lines.count) lines)")
                continue
            }
            let removeCount = min(hunk.oldCount, lines.count - startIndex)
            lines.replaceSubrange(startIndex..<(startIndex + removeCount), with: hunk.addedLines)
        }

        let updatedContent = lines.joined(separator: "\n")
        let updatedData = updatedContent.data(using: .utf8) ?? Data()
        if FileManager.default.createFile(atPath: filePath, contents: updatedData, attributes: nil) {
            logger.info("Persisted accepted hunks to \(filePath)")
            onFilePersisted?(filePath)
        } else {
            logger.error("Failed to write file after hunk acceptance: \(filePath)")
        }
    }

    public func loadSessionMemory(projectPath: String?) -> String? {
        guard let projectPath else { return nil }
        let memoryPath = (projectPath as NSString).appendingPathComponent(".anvil/memory.md")
        guard FileManager.default.fileExists(atPath: memoryPath),
              let data = FileManager.default.contents(atPath: memoryPath),
              let content = String(data: data, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return content
    }
}
