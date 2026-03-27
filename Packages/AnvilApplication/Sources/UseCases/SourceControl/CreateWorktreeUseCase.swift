import Foundation
import AnvilDomain

public struct CreateWorktreeUseCase: Sendable {
    private let basePath: String

    public init(basePath: String = "~/.anvil/worktrees") {
        self.basePath = basePath
    }

    public func execute(
        branch: String,
        sessionId: String,
        projectName: String,
        provider: any SourceControlPort
    ) async throws {
        let worktreePath = "\(basePath)/\(projectName)/\(sessionId)"
        try await provider.createWorktree(branch: branch, path: worktreePath)
    }
}
