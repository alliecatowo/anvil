import Foundation
import AnvilDomain

/// @unchecked Sendable: All stored properties (apiKey, baseURL) are immutable after init.
public final class AnthropicProvider: ACPPort, @unchecked Sendable {
    public let providerId = "anthropic"
    public let providerName = "Anthropic"

    private let apiKey: String
    private let baseURL: String

    public init(apiKey: String, baseURL: String = "https://api.anthropic.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    public func complete(messages: [ACPMessage], model: ACPModel, tools: [ACPToolDefinition], stream: Bool) -> AsyncThrowingStream<ACPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(messages: messages, model: model, tools: tools, stream: stream)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ACPError.networkError("Invalid response"))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        if httpResponse.statusCode == 429 {
                            continuation.finish(throwing: ACPError.rateLimited(retryAfter: nil))
                        } else if httpResponse.statusCode == 401 {
                            continuation.finish(throwing: ACPError.invalidAPIKey(provider: "anthropic"))
                        } else {
                            continuation.finish(throwing: ACPError.providerError("HTTP \(httpResponse.statusCode)"))
                        }
                        return
                    }

                    if stream {
                        for try await line in bytes.lines {
                            if let event = parseSSELine(line) {
                                continuation.yield(event)
                            }
                        }
                    } else {
                        var data = Data()
                        for try await byte in bytes {
                            data.append(byte)
                        }
                        if let text = parseNonStreamResponse(data) {
                            continuation.yield(.textDelta(text))
                            continuation.yield(.messageComplete(ACPMessage(role: .assistant, content: text)))
                        }
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
            ACPModel(id: "claude-opus-4-6", name: "Claude Opus 4.6", provider: "anthropic", contextWindow: 1_000_000, inputCostPer1kTokens: 0.015, outputCostPer1kTokens: 0.075, capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse, .longContext]),
            ACPModel(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", provider: "anthropic", contextWindow: 200_000, inputCostPer1kTokens: 0.003, outputCostPer1kTokens: 0.015, capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse]),
            ACPModel(id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5", provider: "anthropic", contextWindow: 200_000, inputCostPer1kTokens: 0.0008, outputCostPer1kTokens: 0.004, capabilities: [.codeGeneration, .toolUse]),
        ]
    }

    public func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        let inputTokens = messages.reduce(0) { $0 + estimateTokens($1.content) }
        let outputTokens = 2000
        let cost = Decimal(inputTokens) * model.inputCostPer1kTokens / 1000 + Decimal(outputTokens) * model.outputCostPer1kTokens / 1000
        return ACPCostEstimate(estimatedInputTokens: inputTokens, estimatedOutputTokens: outputTokens, estimatedCost: cost)
    }

    public func supportsTools(_ tools: [ACPToolDefinition]) -> Bool { true }

    private func buildRequest(messages: [ACPMessage], model: ACPModel, tools: [ACPToolDefinition], stream: Bool) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw ACPError.networkError("Invalid URL: \(baseURL)/v1/messages")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": 8192,
            "stream": stream,
        ]

        var apiMessages: [[String: String]] = []
        var systemPrompt: String?

        for message in messages {
            if message.role == .system {
                systemPrompt = message.content
            } else {
                apiMessages.append(["role": message.role.rawValue, "content": message.content])
            }
        }

        body["messages"] = apiMessages
        if let systemPrompt { body["system"] = systemPrompt }

        if !tools.isEmpty {
            body["tools"] = tools.map { tool in
                ["name": tool.name, "description": tool.description, "input_schema": tool.inputSchema]
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseSSELine(_ line: String) -> ACPStreamEvent? {
        guard line.hasPrefix("data: ") else { return nil }
        let jsonStr = String(line.dropFirst(6))
        guard jsonStr != "[DONE]",
              let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if let type = json["type"] as? String {
            switch type {
            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    return .textDelta(text)
                }
            case "message_delta":
                if let usage = json["usage"] as? [String: Any],
                   let outputTokens = usage["output_tokens"] as? Int {
                    return .usage(ACPUsage(inputTokens: 0, outputTokens: outputTokens))
                }
            case "message_start":
                if let message = json["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any],
                   let inputTokens = usage["input_tokens"] as? Int {
                    return .usage(ACPUsage(inputTokens: inputTokens, outputTokens: 0))
                }
            default:
                break
            }
        }
        return nil
    }

    private func parseNonStreamResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else { return nil }
        return text
    }

    private func estimateTokens(_ text: String) -> Int {
        text.count / 4 // rough approximation
    }
}
