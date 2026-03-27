import Foundation
import AnvilDomain

public struct AutoCommitUseCase: Sendable {
    public init() {}

    public func execute(
        message: String,
        paths: [String],
        provider: any SourceControlPort
    ) async throws -> Commit {
        try await provider.stage(paths: paths)
        return try await provider.commit(message: message, amend: false)
    }
}
