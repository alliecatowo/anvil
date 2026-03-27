import Foundation
import AnvilDomain

/// Intelligent auto-commit: detects meaningful change boundaries
/// and generates commit messages from diffs.
///
/// In a full implementation, message generation would use ACP (Anvil
/// Claude Protocol) to produce high-quality commit messages. For now,
/// this provides a deterministic heuristic-based approach.
public actor AutoCommitter {

    private let adapter: GitSourceControlAdapter

    public init(adapter: GitSourceControlAdapter) {
        self.adapter = adapter
    }

    /// Detect whether current changes represent a meaningful commit boundary.
    /// Returns true when there are staged changes ready to commit.
    public func hasMeaningfulChanges() async throws -> Bool {
        let staged = try await adapter.stagedDiff()
        return !staged.isEmpty
    }

    /// Generate a commit message from the currently staged diff.
    /// Uses heuristic analysis of the changed files and hunks.
    public func generateMessage() async throws -> String {
        let staged = try await adapter.stagedDiff()
        guard !staged.isEmpty else {
            return "chore: empty commit"
        }

        let fileCount = staged.count
        let addedFiles = staged.filter { $0.status == .added }
        let deletedFiles = staged.filter { $0.status == .deleted }
        let modifiedFiles = staged.filter { $0.status == .modified }
        let renamedFiles = staged.filter { $0.status == .renamed }

        // Single file change — be specific
        if fileCount == 1, let file = staged.first {
            let name = (file.filePath as NSString).lastPathComponent
            switch file.status {
            case .added:
                return "feat: add \(name)"
            case .deleted:
                return "chore: remove \(name)"
            case .renamed:
                let oldName = (file.oldPath ?? file.filePath) as NSString
                return "refactor: rename \(oldName.lastPathComponent) to \(name)"
            case .modified:
                let totalAdded = file.hunks.flatMap(\.lines).filter { $0.type == .added }.count
                let totalRemoved = file.hunks.flatMap(\.lines).filter { $0.type == .removed }.count
                if totalRemoved == 0 {
                    return "feat: extend \(name)"
                } else if totalAdded == 0 {
                    return "refactor: simplify \(name)"
                } else {
                    return "update: modify \(name)"
                }
            case .copied:
                return "feat: add \(name)"
            }
        }

        // Multi-file changes — summarize
        var parts: [String] = []
        if !addedFiles.isEmpty {
            parts.append("\(addedFiles.count) added")
        }
        if !modifiedFiles.isEmpty {
            parts.append("\(modifiedFiles.count) modified")
        }
        if !deletedFiles.isEmpty {
            parts.append("\(deletedFiles.count) deleted")
        }
        if !renamedFiles.isEmpty {
            parts.append("\(renamedFiles.count) renamed")
        }

        let summary = parts.joined(separator: ", ")
        return "update: \(fileCount) files (\(summary))"
    }

    /// Auto-commit staged changes with a generated message.
    @discardableResult
    public func autoCommit() async throws -> Commit {
        let message = try await generateMessage()
        return try await adapter.commit(message: message, amend: false)
    }
}
