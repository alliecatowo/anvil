import Foundation

public protocol ACPPort: Sendable {
    var providerId: String { get }
    var providerName: String { get }

    func complete(messages: [ACPMessage], model: ACPModel, tools: [ACPToolDefinition], stream: Bool) -> AsyncThrowingStream<ACPStreamEvent, Error>
    func availableModels() async throws -> [ACPModel]
    func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate
    func supportsTools(_ tools: [ACPToolDefinition]) -> Bool
}
