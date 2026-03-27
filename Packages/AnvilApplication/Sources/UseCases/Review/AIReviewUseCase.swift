import Foundation
import AnvilDomain

public struct AIReviewUseCase: Sendable {
    public init() {}

    public func execute(
        diff: [FileDiff],
        acpProvider: any ACPPort,
        model: ACPModel
    ) async throws -> [ReviewComment] {
        let diffText = diff.map { file in
            "File: \(file.filePath)\nStatus: \(file.status.rawValue)\n" +
            file.hunks.map { hunk in
                hunk.lines.map { "\($0.type == .added ? "+" : $0.type == .removed ? "-" : " ") \($0.content)" }.joined(separator: "\n")
            }.joined(separator: "\n")
        }.joined(separator: "\n---\n")

        let messages = [
            ACPMessage(role: .system, content: "You are an expert code reviewer. Review the following diff for correctness, security, performance, and style issues. Output structured review comments."),
            ACPMessage(role: .user, content: diffText)
        ]

        var responseText = ""
        let stream = acpProvider.complete(messages: messages, model: model, tools: [], stream: true)

        for try await event in stream {
            if case .textDelta(let delta) = event {
                responseText += delta
            }
        }

        // Parse response into review comments (simplified)
        return [ReviewComment(author: "AI (\(model.name))", body: responseText, isAIGenerated: true)]
    }
}
