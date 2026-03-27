import Foundation
import AnvilDomain

public final class OpenAIProvider: ACPPort, @unchecked Sendable {
    public let providerId = "openai"
    public let providerName = "OpenAI"

    private let apiKey: String
    private let baseURL: String

    public init(apiKey: String, baseURL: String = "https://api.openai.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    public func complete(messages: [ACPMessage], model: ACPModel, tools: [ACPToolDefinition], stream: Bool) -> AsyncThrowingStream<ACPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: URL(string: "\(baseURL)/v1/chat/completions")!)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                    let body: [String: Any] = [
                        "model": model.id,
                        "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
                        "stream": stream,
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, _) = try await URLSession.shared.bytes(for: request)

                    if stream {
                        for try await line in bytes.lines {
                            if line.hasPrefix("data: "), line != "data: [DONE]",
                               let data = String(line.dropFirst(6)).data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let delta = choices.first?["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                continuation.yield(.textDelta(content))
                            }
                        }
                    } else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let message = choices.first?["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            continuation.yield(.textDelta(content))
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
            ACPModel(id: "gpt-4o", name: "GPT-4o", provider: "openai", contextWindow: 128_000, inputCostPer1kTokens: 0.005, outputCostPer1kTokens: 0.015, capabilities: [.codeGeneration, .codeReview, .reasoning, .vision, .toolUse]),
            ACPModel(id: "o3", name: "o3", provider: "openai", contextWindow: 200_000, inputCostPer1kTokens: 0.010, outputCostPer1kTokens: 0.040, capabilities: [.codeGeneration, .reasoning, .toolUse]),
        ]
    }

    public func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        let inputTokens = messages.reduce(0) { $0 + $1.content.count / 4 }
        let cost = Decimal(inputTokens) * model.inputCostPer1kTokens / 1000 + 2000 * model.outputCostPer1kTokens / 1000
        return ACPCostEstimate(estimatedInputTokens: inputTokens, estimatedOutputTokens: 2000, estimatedCost: cost)
    }

    public func supportsTools(_ tools: [ACPToolDefinition]) -> Bool { true }
}
