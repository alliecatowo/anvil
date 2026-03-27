import Foundation
import AnvilDomain

public final class ClaudeCLIProvider: ACPPort, @unchecked Sendable {
    public let providerId = "claude-cli"
    public let providerName = "Claude CLI"

    private let cliPath: String

    public init(cliPath: String = "") {
        if cliPath.isEmpty {
            self.cliPath = ClaudeCLIProvider.findClaudeBinary() ?? "/usr/local/bin/claude"
        } else {
            self.cliPath = cliPath
        }
    }

    private static func findClaudeBinary() -> String? {
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
        // Fall back to `which claude`
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

    public func complete(messages: [ACPMessage], model: ACPModel, tools: [ACPToolDefinition], stream: Bool) -> AsyncThrowingStream<ACPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let systemPrompt = messages.first(where: { $0.role == .system })?.content
                    let userMessages = messages.filter { $0.role != .system }
                    let prompt = userMessages.map { $0.content }.joined(separator: "\n\n")

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
                        continuation.finish(throwing: ACPError.providerError("Claude CLI error: \(errorStr)"))
                        return
                    }

                    if let output = String(data: outputData, encoding: .utf8) {
                        if let jsonData = output.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let result = json["result"] as? String {
                            continuation.yield(.textDelta(result))
                            continuation.yield(.messageComplete(ACPMessage(role: .assistant, content: result)))
                        } else {
                            let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
                            continuation.yield(.textDelta(text))
                            continuation.yield(.messageComplete(ACPMessage(role: .assistant, content: text)))
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ACPError.providerError("Failed to run Claude CLI: \(error.localizedDescription)"))
                }
            }
        }
    }

    public func availableModels() async throws -> [ACPModel] {
        [
            ACPModel(id: "default", name: "Claude (CLI Default)", provider: "claude-cli", contextWindow: 200_000, inputCostPer1kTokens: 0, outputCostPer1kTokens: 0, capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse]),
            ACPModel(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", provider: "claude-cli", contextWindow: 200_000, inputCostPer1kTokens: 0, outputCostPer1kTokens: 0, capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse]),
            ACPModel(id: "claude-opus-4-6", name: "Claude Opus 4.6", provider: "claude-cli", contextWindow: 1_000_000, inputCostPer1kTokens: 0, outputCostPer1kTokens: 0, capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse, .longContext]),
            ACPModel(id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5", provider: "claude-cli", contextWindow: 200_000, inputCostPer1kTokens: 0, outputCostPer1kTokens: 0, capabilities: [.codeGeneration, .toolUse]),
        ]
    }

    public func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        ACPCostEstimate(estimatedInputTokens: 0, estimatedOutputTokens: 0, estimatedCost: 0)
    }

    public func supportsTools(_ tools: [ACPToolDefinition]) -> Bool { true }

    /// Check if Claude CLI is available on this system.
    public static func isAvailable() -> Bool {
        findClaudeBinary() != nil
    }
}
