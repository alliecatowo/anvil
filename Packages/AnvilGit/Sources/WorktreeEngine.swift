import Foundation
import AnvilDomain

/// Higher-level worktree management for agent sessions.
/// Creates worktrees in ~/.anvil/worktrees/ and tracks lifecycle.
public actor WorktreeEngine {

    private let adapter: GitSourceControlAdapter
    private let basePath: String

    public init(adapter: GitSourceControlAdapter, basePath: String? = nil) {
        self.adapter = adapter
        self.basePath = basePath ?? NSHomeDirectory() + "/.anvil/worktrees"
    }

    /// Create a worktree for an agent session, returning the filesystem path.
    public func createSessionWorktree(sessionId: String, branch: String) async throws -> String {
        let path = "\(basePath)/\(sessionId)"

        // Ensure base directory exists
        let fm = FileManager.default
        if !fm.fileExists(atPath: basePath) {
            try fm.createDirectory(atPath: basePath, withIntermediateDirectories: true)
        }

        try await adapter.createWorktree(branch: branch, path: path)
        return path
    }

    /// Remove a session worktree.
    public func removeSessionWorktree(sessionId: String) async throws {
        let path = "\(basePath)/\(sessionId)"
        try await adapter.removeWorktree(path: path)
    }

    /// List all active session worktrees.
    public func activeWorktrees() async throws -> [Worktree] {
        let all = try await adapter.worktrees()
        return all.filter { $0.path.hasPrefix(basePath) }
    }

    /// Garbage-collect stale worktrees that no longer have valid branches.
    public func collectGarbage() async throws -> [String] {
        let worktrees = try await activeWorktrees()
        var removed: [String] = []

        let fm = FileManager.default
        for wt in worktrees {
            // If the worktree directory doesn't exist on disk, prune it
            if !fm.fileExists(atPath: wt.path) {
                try? await adapter.removeWorktree(path: wt.path)
                removed.append(wt.path)
            }
        }

        return removed
    }
}
