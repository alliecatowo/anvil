import Foundation
import AnvilDomain

/// ACP-aware provider for Claude CLI.
///
/// This provider wraps the Claude CLI binary (`claude`) and adapts it to the ACPPort protocol.
/// Today it uses `claude -p --output-format json` for each completion (one process per request).
/// The architecture is designed so that when Claude CLI gains native ACP/JSON-RPC support,
/// we switch to a long-lived process transport without changing the provider interface.
///
/// Key design decisions:
/// - Each `complete()` call spawns a short-lived process (current Claude CLI limitation)
/// - The ACPPort protocol IS the ACP abstraction -- callers don't care about the transport
/// - Binary discovery is shared with ClaudeCLIProvider for backward compatibility
/// - When `--acp` flag becomes available, this provider will switch to ACPProcessTransport
///   for a persistent, bidirectional JSON-RPC connection
public final class ClaudeProcessProvider: ACPPort, @unchecked Sendable {
    public let providerId = "claude-process"
    public let providerName = "Claude (Process)"

    private let cliPath: String

    public init(cliPath: String? = nil) {
        if let cliPath, !cliPath.isEmpty {
            self.cliPath = cliPath
        } else {
            self.cliPath = Self.findClaudeBinary() ?? "/usr/local/bin/claude"
        }
    }

    // MARK: - ACPPort

    public func complete(
        messages: [ACPMessage],
        model: ACPModel,
        tools: [ACPToolDefinition],
        stream: Bool
    ) -> AsyncThrowingStream<ACPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await self.runCompletion(messages: messages, model: model)
                    continuation.yield(.textDelta(result.text))
                    continuation.yield(.messageComplete(ACPMessage(role: .assistant, content: result.text)))
                    if let usage = result.usage {
                        continuation.yield(.usage(usage))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func availableModels() async throws -> [ACPModel] {
        [
            ACPModel(
                id: "default", name: "Claude (CLI Default)", provider: providerId,
                contextWindow: 200_000, inputCostPer1kTokens: 0, outputCostPer1kTokens: 0,
                capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse]
            ),
            ACPModel(
                id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", provider: providerId,
                contextWindow: 200_000, inputCostPer1kTokens: 0, outputCostPer1kTokens: 0,
                capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse]
            ),
            ACPModel(
                id: "claude-opus-4-6", name: "Claude Opus 4.6", provider: providerId,
                contextWindow: 1_000_000, inputCostPer1kTokens: 0, outputCostPer1kTokens: 0,
                capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse, .longContext]
            ),
            ACPModel(
                id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5", provider: providerId,
                contextWindow: 200_000, inputCostPer1kTokens: 0, outputCostPer1kTokens: 0,
                capabilities: [.codeGeneration, .toolUse]
            ),
        ]
    }

    public func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        // CLI usage is billed through the user's Claude subscription, not per-token
        ACPCostEstimate(estimatedInputTokens: 0, estimatedOutputTokens: 0, estimatedCost: 0)
    }

    public func supportsTools(_ tools: [ACPToolDefinition]) -> Bool { true }

    // MARK: - Process Execution

    private struct CompletionResult {
        let text: String
        let usage: ACPUsage?
    }

    private func runCompletion(messages: [ACPMessage], model: ACPModel) async throws -> CompletionResult {
        let systemPrompt = messages.first(where: { $0.role == .system })?.content
        let userMessages = messages.filter { $0.role != .system }
        let prompt = userMessages.map(\.content).joined(separator: "\n\n")

        var args = ["-p", prompt, "--output-format", "json"]
        if let systemPrompt {
            args += ["--system-prompt", systemPrompt]
        }
        if !model.id.isEmpty && model.id != "default" {
            args += ["--model", model.id]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = args
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ACPError.providerError("Claude CLI exited with status \(process.terminationStatus): \(errorStr)")
        }

        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ACPError.providerError("Could not decode Claude CLI output")
        }

        // Parse JSON output from `claude -p --output-format json`
        if let jsonData = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let text = json["result"] as? String ?? output.trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract usage if available
            var usage: ACPUsage?
            if let usageDict = json["usage"] as? [String: Any],
               let inputTokens = usageDict["input_tokens"] as? Int,
               let outputTokens = usageDict["output_tokens"] as? Int {
                usage = ACPUsage(inputTokens: inputTokens, outputTokens: outputTokens)
            }

            return CompletionResult(text: text, usage: usage)
        }

        // Fallback: treat raw output as the result
        return CompletionResult(
            text: output.trimmingCharacters(in: .whitespacesAndNewlines),
            usage: nil
        )
    }

    // MARK: - Binary Discovery

    /// Check if Claude CLI is available on this system.
    public static func isAvailable() -> Bool {
        findClaudeBinary() != nil
    }

    static func findClaudeBinary() -> String? {
        let paths = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}
