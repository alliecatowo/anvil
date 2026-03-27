import Foundation
import Combine

@MainActor
public final class ProjectNotesViewModel: ObservableObject {
    @Published public var content: String = "" {
        didSet {
            scheduleSave()
        }
    }
    @Published public var projectName: String = "default"

    private var saveTask: Task<Void, Never>?

    public init() {}

    // MARK: - File Path

    private var notesDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".anvil/projects/\(projectName)", isDirectory: true)
    }

    private var notesFileURL: URL {
        notesDirectory.appendingPathComponent("notes.md")
    }

    // MARK: - Load

    public func load() {
        let url = notesFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            content = ""
            return
        }
        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            // Set without triggering auto-save
            let current = content
            if data != current {
                content = data
            }
        } catch {
            content = ""
        }
    }

    // MARK: - Append Entry

    public func appendEntry(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())

        let entry = "\n---\n\n**\(timestamp)**\n\n\(trimmed)\n"

        if content.isEmpty {
            content = "# Project Notes\n\(entry)"
        } else {
            content += entry
        }

        saveNow()
    }

    // MARK: - Save (debounced)

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        let url = notesFileURL
        let dir = notesDirectory

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // Silently fail — the user will see the content is still in the editor
        }
    }
}
