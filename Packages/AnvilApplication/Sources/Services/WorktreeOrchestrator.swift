import Foundation
import AnvilDomain

public actor WorktreeOrchestrator {
    private let basePath: String
    private var activeWorktrees: [String: String] = [:] // sessionId -> worktreePath

    public init(basePath: String = "~/.anvil/worktrees") {
        self.basePath = basePath
    }

    public func createForSession(sessionId: String, branch: String, projectName: String, provider: any SourceControlPort) async throws -> String {
        let path = "\(basePath)/\(projectName)/\(sessionId)"
        try await provider.createWorktree(branch: branch, path: path)
        activeWorktrees[sessionId] = path
        return path
    }

    public func worktreePath(for sessionId: String) -> String? {
        activeWorktrees[sessionId]
    }

    public func cleanupForSession(sessionId: String, provider: any SourceControlPort) async throws {
        guard let path = activeWorktrees[sessionId] else { return }
        try await provider.removeWorktree(path: path)
        activeWorktrees.removeValue(forKey: sessionId)
    }

    public func cleanupStale(provider: any SourceControlPort) async throws {
        let worktrees = try await provider.worktrees()
        for worktree in worktrees where !worktree.isMain {
            let isActive = activeWorktrees.values.contains(worktree.path)
            if !isActive {
                try await provider.removeWorktree(path: worktree.path)
            }
        }
    }
}
