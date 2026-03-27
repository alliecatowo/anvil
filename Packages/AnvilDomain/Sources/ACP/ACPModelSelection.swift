import Foundation

public struct ACPModel: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let provider: String
    public let contextWindow: Int
    public let inputCostPer1kTokens: Decimal
    public let outputCostPer1kTokens: Decimal
    public let capabilities: Set<ACPCapability>

    public init(id: String, name: String, provider: String, contextWindow: Int, inputCostPer1kTokens: Decimal, outputCostPer1kTokens: Decimal, capabilities: Set<ACPCapability> = []) {
        self.id = id
        self.name = name
        self.provider = provider
        self.contextWindow = contextWindow
        self.inputCostPer1kTokens = inputCostPer1kTokens
        self.outputCostPer1kTokens = outputCostPer1kTokens
        self.capabilities = capabilities
    }
}

public enum ACPCapability: String, Sendable, Codable, Hashable {
    case codeGeneration
    case codeReview
    case reasoning
    case vision
    case toolUse
    case longContext
}
