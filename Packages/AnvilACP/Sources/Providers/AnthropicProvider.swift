import Foundation
import AnvilDomain

/// Production Anthropic Claude provider.
///
/// Supports streaming via SSE, full tool-use round-trips, context window management,
/// and exponential backoff retry on overload (HTTP 529).
///
/// @unchecked Sendable: All stored properties are immutable after init.
public final class AnthropicProvider: ACPPort, @unchecked Sendable {
    public let providerId = "anthropic"
    public let providerName = "Anthropic"

    private let apiKey: String
    private let baseURL: String
    private let defaultModelId: String
    private let maxRetries: Int
    private let contextTokenLimit: Int

    /// - Parameters:
    ///   - apiKey: Anthropic API key. Falls back to `ANTHROPIC_API_KEY` env var.
    ///   - baseURL: API base URL.
    ///   - defaultModelId: Model to use when none specified.
    ///   - maxRetries: Max retries on HTTP 529 overload.
    ///   - contextTokenLimit: When estimated tokens exceed this, oldest non-system messages are dropped.
    public init(
        apiKey: String? = nil,
        baseURL: String = "https://api.anthropic.com",
        defaultModelId: String = "claude-sonnet-4-6",
        maxRetries: Int = 3,
        contextTokenLimit: Int = 180_000
    ) {
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        self.baseURL = baseURL
        self.defaultModelId = defaultModelId
        self.maxRetries = maxRetries
        self.contextTokenLimit = contextTokenLimit
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
                    guard !apiKey.isEmpty else {
                        continuation.finish(throwing: ACPError.invalidAPIKey(provider: "anthropic"))
                        return
                    }

                    let trimmed = trimMessages(messages)
                    let request = try buildRequest(messages: trimmed, model: model, tools: tools, stream: stream)

                    let (bytes, response) = try await executeWithRetry(request: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ACPError.networkError("Invalid response"))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: httpError(statusCode: httpResponse.statusCode))
                        return
                    }

                    if stream {
                        try await parseStreamingResponse(bytes: bytes, continuation: continuation)
                    } else {
                        try await parseNonStreamingResponse(bytes: bytes, continuation: continuation)
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
            ACPModel(id: "claude-opus-4-6", name: "Claude Opus 4.6", provider: "anthropic",
                     contextWindow: 1_000_000, inputCostPer1kTokens: 0.015, outputCostPer1kTokens: 0.075,
                     capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse, .longContext]),
            ACPModel(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", provider: "anthropic",
                     contextWindow: 200_000, inputCostPer1kTokens: 0.003, outputCostPer1kTokens: 0.015,
                     capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse]),
            ACPModel(id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5", provider: "anthropic",
                     contextWindow: 200_000, inputCostPer1kTokens: 0.0008, outputCostPer1kTokens: 0.004,
                     capabilities: [.codeGeneration, .toolUse]),
        ]
    }

    public func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        let inputTokens = messages.reduce(0) { $0 + estimateTokens($1.content) }
        let outputTokens = 2000
        let cost = Decimal(inputTokens) * model.inputCostPer1kTokens / 1000
            + Decimal(outputTokens) * model.outputCostPer1kTokens / 1000
        return ACPCostEstimate(estimatedInputTokens: inputTokens, estimatedOutputTokens: outputTokens, estimatedCost: cost)
    }

    public func supportsTools(_ tools: [ACPToolDefinition]) -> Bool { true }

    // MARK: - Context Management

    /// Drop oldest non-system messages when estimated token count exceeds the limit.
    private func trimMessages(_ messages: [ACPMessage]) -> [ACPMessage] {
        var result = messages
        var estimated = result.reduce(0) { $0 + estimateTokens($1.content) }

        while estimated > contextTokenLimit, result.count > 1 {
            if let idx = result.firstIndex(where: { $0.role != .system }) {
                let removed = result.remove(at: idx)
                estimated -= estimateTokens(removed.content)
            } else {
                break
            }
        }
        return result
    }

    // MARK: - Retry with Exponential Backoff

    private func executeWithRetry(request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        var lastError: Error?
        for attempt in 0 ..< maxRetries {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 529 {
                lastError = ACPError.providerError("Overloaded (529)")
                let delay = pow(2.0, Double(attempt)) * 0.5
                try await Task.sleep(for: .seconds(delay))
                continue
            }
            return (bytes, response)
        }
        throw lastError ?? ACPError.providerError("Max retries exceeded")
    }

    // MARK: - Request Building

    private func buildRequest(
        messages: [ACPMessage],
        model: ACPModel,
        tools: [ACPToolDefinition],
        stream: Bool
    ) throws -> URLRequest {
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

        var apiMessages: [[String: Any]] = []
        var systemPrompt: String?

        for message in messages {
            switch message.role {
            case .system:
                systemPrompt = message.content
            case .tool:
                // Tool result: structured content block
                apiMessages.append([
                    "role": "user",
                    "content": [
                        [
                            "type": "tool_result",
                            "tool_use_id": message.toolCallId ?? "",
                            "content": message.content,
                        ] as [String: Any]
                    ] as [[String: Any]],
                ])
            case .user:
                apiMessages.append(["role": "user", "content": message.content])
            case .assistant:
                // Check if content looks like it contains tool_use blocks (JSON array)
                if let data = message.content.data(using: .utf8),
                   let blocks = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   blocks.contains(where: { ($0["type"] as? String) == "tool_use" }) {
                    apiMessages.append(["role": "assistant", "content": blocks])
                } else {
                    apiMessages.append(["role": "assistant", "content": message.content])
                }
            }
        }

        body["messages"] = apiMessages
        if let systemPrompt { body["system"] = systemPrompt }

        if !tools.isEmpty {
            body["tools"] = tools.map { tool -> [String: Any] in
                var toolDict: [String: Any] = [
                    "name": tool.name,
                    "description": tool.description,
                ]
                if let schemaData = tool.inputSchema.data(using: .utf8),
                   let schema = try? JSONSerialization.jsonObject(with: schemaData) {
                    toolDict["input_schema"] = schema
                } else {
                    toolDict["input_schema"] = ["type": "object", "properties": [:] as [String: Any]]
                }
                return toolDict
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Streaming Response Parsing

    private func parseStreamingResponse(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<ACPStreamEvent, Error>.Continuation
    ) async throws {
        // Track tool calls in progress: id -> (name, accumulated arguments JSON)
        var activeToolCalls: [Int: (id: String, name: String, args: String)] = [:]

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard jsonStr != "[DONE]",
                  let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            switch type {
            case "message_start":
                if let message = json["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any],
                   let inputTokens = usage["input_tokens"] as? Int {
                    continuation.yield(.usage(ACPUsage(inputTokens: inputTokens, outputTokens: 0)))
                }

            case "content_block_start":
                if let index = json["index"] as? Int,
                   let block = json["content_block"] as? [String: Any],
                   let blockType = block["type"] as? String, blockType == "tool_use" {
                    let id = block["id"] as? String ?? "tool_\(index)"
                    let name = block["name"] as? String ?? ""
                    activeToolCalls[index] = (id: id, name: name, args: "")
                    continuation.yield(.toolCallStart(id: id, name: name))
                }

            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any],
                   let deltaType = delta["type"] as? String {
                    switch deltaType {
                    case "text_delta":
                        if let text = delta["text"] as? String {
                            continuation.yield(.textDelta(text))
                        }
                    case "input_json_delta":
                        if let index = json["index"] as? Int,
                           let partial = delta["partial_json"] as? String {
                            activeToolCalls[index]?.args.append(partial)
                            if let tc = activeToolCalls[index] {
                                continuation.yield(.toolCallDelta(id: tc.id, argumentsDelta: partial))
                            }
                        }
                    default:
                        break
                    }
                }

            case "content_block_stop":
                if let index = json["index"] as? Int,
                   let tc = activeToolCalls.removeValue(forKey: index) {
                    continuation.yield(.toolCallEnd(id: tc.id))
                }

            case "message_delta":
                if let usage = json["usage"] as? [String: Any],
                   let outputTokens = usage["output_tokens"] as? Int {
                    continuation.yield(.usage(ACPUsage(inputTokens: 0, outputTokens: outputTokens)))
                }

            case "message_stop":
                break

            default:
                break
            }
        }
    }

    // MARK: - Non-Streaming Response Parsing

    private func parseNonStreamingResponse(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<ACPStreamEvent, Error>.Continuation
    ) async throws {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else { return }

        // Emit usage
        if let usage = json["usage"] as? [String: Any] {
            let input = usage["input_tokens"] as? Int ?? 0
            let output = usage["output_tokens"] as? Int ?? 0
            continuation.yield(.usage(ACPUsage(inputTokens: input, outputTokens: output)))
        }

        var textParts: [String] = []

        for block in content {
            guard let blockType = block["type"] as? String else { continue }
            switch blockType {
            case "text":
                if let text = block["text"] as? String {
                    continuation.yield(.textDelta(text))
                    textParts.append(text)
                }
            case "tool_use":
                let id = block["id"] as? String ?? ""
                let name = block["name"] as? String ?? ""
                continuation.yield(.toolCallStart(id: id, name: name))
                if let input = block["input"],
                   let inputData = try? JSONSerialization.data(withJSONObject: input),
                   let inputStr = String(data: inputData, encoding: .utf8) {
                    continuation.yield(.toolCallDelta(id: id, argumentsDelta: inputStr))
                }
                continuation.yield(.toolCallEnd(id: id))
            default:
                break
            }
        }

        let fullText = textParts.joined()
        if !fullText.isEmpty {
            continuation.yield(.messageComplete(ACPMessage(role: .assistant, content: fullText)))
        }
    }

    // MARK: - Helpers

    private func httpError(statusCode: Int) -> ACPError {
        switch statusCode {
        case 401:
            return .invalidAPIKey(provider: "anthropic")
        case 429:
            return .rateLimited(retryAfter: nil)
        case 529:
            return .providerError("Overloaded (529)")
        default:
            return .providerError("HTTP \(statusCode)")
        }
    }

    private func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }
}
