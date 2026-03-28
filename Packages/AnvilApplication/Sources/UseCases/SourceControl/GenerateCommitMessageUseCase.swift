import Foundation
import AnvilDomain

public struct GenerateCommitMessageUseCase: Sendable {
    public init() {}

    /// Generates a commit message from a staged diff using an ACP provider.
    /// Returns the full text response from the model.
    public func execute(
        diff: String,
        provider: any ACPPort,
        model: ACPModel? = nil
    ) async throws -> String {
        let prompt = """
        Write a concise git commit message for the following staged diff.

        Rules:
        - First line is the subject (imperative mood, max 50 chars)
        - Leave a blank line after the subject
        - Then a brief body explaining *why* (not what) if the change isn't trivial
        - Do NOT include any markup, code fences, or prefix like "commit:"
        - Output ONLY the commit message text, nothing else

        Diff:
        ```
        \(String(diff.prefix(8000)))
        ```
        """

        let messages = [
            ACPMessage(role: .system, content: "You are a git commit message generator. Output only the commit message."),
            ACPMessage(role: .user, content: prompt),
        ]

        let resolvedModel: ACPModel
        if let model {
            resolvedModel = model
        } else {
            guard let firstModel = try await provider.availableModels().first else {
                throw GenerateCommitMessageError.noModelsAvailable
            }
            resolvedModel = firstModel
        }

        var result = ""
        let stream = provider.complete(messages: messages, model: resolvedModel, tools: [], stream: true)

        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                result += delta
            default:
                break
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum GenerateCommitMessageError: Error, LocalizedError {
    case noModelsAvailable
    case emptyDiff

    public var errorDescription: String? {
        switch self {
        case .noModelsAvailable: "No AI models available. Configure a provider in Settings."
        case .emptyDiff: "No staged changes to describe."
        }
    }
}
