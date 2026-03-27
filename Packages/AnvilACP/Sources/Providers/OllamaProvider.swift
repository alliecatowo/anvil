import Foundation
import AnvilDomain

public final class OllamaProvider: ACPPort, @unchecked Sendable {
    public let providerId = "ollama"
    public let providerName = "Ollama (Local)"

    private let baseURL: String

    public init(baseURL: String = "http://localhost:11434") {
        self.baseURL = baseURL
    }

    public func complete(messages: [ACPMessage], model: ACPModel, tools: [ACPToolDefinition], stream: Bool) -> AsyncThrowingStream<ACPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: URL(string: "\(baseURL)/api/chat")!)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": model.id,
                        "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
                        "stream": stream,
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, _) = try await URLSession.shared.bytes(for: request)

                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? [String: Any],
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
        // Dynamically fetch from Ollama API
        let request = URLRequest(url: URL(string: "\(baseURL)/api/tags")!)
        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }

        return models.compactMap { model in
            guard let name = model["name"] as? String else { return nil as ACPModel? }
            return ACPModel(
                id: name,
                name: name,
                provider: "ollama",
                contextWindow: 32_000,
                inputCostPer1kTokens: 0,
                outputCostPer1kTokens: 0,
                capabilities: [.codeGeneration]
            )
        }
    }

    public func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        ACPCostEstimate(estimatedInputTokens: 0, estimatedOutputTokens: 0, estimatedCost: 0)
    }

    public func supportsTools(_ tools: [ACPToolDefinition]) -> Bool { false }
}
