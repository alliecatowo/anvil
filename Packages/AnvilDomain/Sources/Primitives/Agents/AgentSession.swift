import Foundation

public struct AgentSession: Sendable, Identifiable, Codable {
    public let id: String
    public let providerId: String
    public var model: String
    public var status: AgentSessionStatus
    public let workItemId: String?
    public let worktreePath: String?
    public var tokenUsage: TokenUsage
    public var cost: Decimal
    public let startedAt: Date
    public var lastActivityAt: Date
    public var messages: [AgentMessage]
    public var customName: String?
    public var costBudget: Decimal?
    public var hardStopOnBudget: Bool
    public var autonomyLevel: AutonomyLevel

    /// Budget usage ratio (0.0 to 1.0+). Returns nil if no budget is set.
    public var budgetUsage: Double? {
        guard let budget = costBudget, budget > 0 else { return nil }
        return NSDecimalNumber(decimal: cost / budget).doubleValue
    }

    /// Display name for the session — uses custom name, work item ID, or first message preview.
    public var displayName: String {
        if let customName, !customName.isEmpty { return customName }
        if let workItemId { return workItemId }
        if let firstUser = messages.first(where: { $0.role == .user }) {
            let preview = firstUser.content.prefix(40)
            return preview.count < firstUser.content.count ? "\(preview)..." : String(preview)
        }
        return "Session"
    }

    public init(id: String = UUID().uuidString, providerId: String, model: String, status: AgentSessionStatus = .idle, workItemId: String? = nil, worktreePath: String? = nil, tokenUsage: TokenUsage = .zero, cost: Decimal = 0, startedAt: Date = .now, lastActivityAt: Date = .now, messages: [AgentMessage] = [], customName: String? = nil, costBudget: Decimal? = nil, hardStopOnBudget: Bool = false, autonomyLevel: AutonomyLevel = .ask) {
        self.id = id
        self.providerId = providerId
        self.model = model
        self.status = status
        self.workItemId = workItemId
        self.worktreePath = worktreePath
        self.tokenUsage = tokenUsage
        self.cost = cost
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.messages = messages
        self.customName = customName
        self.costBudget = costBudget
        self.hardStopOnBudget = hardStopOnBudget
        self.autonomyLevel = autonomyLevel
    }
}

public enum AgentSessionStatus: String, Sendable, Codable {
    case idle, running, paused, completed, failed, cancelled
}

/// Controls how tool calls are handled in a session.
public enum AutonomyLevel: String, Sendable, Codable, CaseIterable {
    case ask      // Every tool call requires approval
    case review   // Show tool calls with quick approve/reject, auto-timeout to approve
    case auto     // Execute all tools without approval

    public var displayName: String {
        switch self {
        case .ask: return "Ask"
        case .review: return "Review"
        case .auto: return "Auto"
        }
    }

    public var description: String {
        switch self {
        case .ask: return "Approve every tool call"
        case .review: return "Quick approve/reject"
        case .auto: return "Execute without approval"
        }
    }
}

public struct TokenUsage: Sendable, Codable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int

    public var totalTokens: Int { inputTokens + outputTokens }

    public static let zero = TokenUsage(inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0)

    public init(inputTokens: Int, outputTokens: Int, cacheReadTokens: Int = 0, cacheWriteTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
    }
}

public struct CostEstimate: Sendable, Codable {
    public let estimatedInputTokens: Int
    public let estimatedOutputTokens: Int
    public let estimatedCost: Decimal
    public let model: String

    public init(estimatedInputTokens: Int, estimatedOutputTokens: Int, estimatedCost: Decimal, model: String) {
        self.estimatedInputTokens = estimatedInputTokens
        self.estimatedOutputTokens = estimatedOutputTokens
        self.estimatedCost = estimatedCost
        self.model = model
    }
}

public struct AgentModel: Sendable, Identifiable, Codable {
    public var id: String { modelId }
    public let modelId: String
    public let name: String
    public let provider: String
    public let contextWindow: Int
    public let inputCostPer1kTokens: Decimal
    public let outputCostPer1kTokens: Decimal
    public let capabilities: Set<String>

    public init(modelId: String, name: String, provider: String, contextWindow: Int, inputCostPer1kTokens: Decimal, outputCostPer1kTokens: Decimal, capabilities: Set<String> = []) {
        self.modelId = modelId
        self.name = name
        self.provider = provider
        self.contextWindow = contextWindow
        self.inputCostPer1kTokens = inputCostPer1kTokens
        self.outputCostPer1kTokens = outputCostPer1kTokens
        self.capabilities = capabilities
    }
}

public struct AgentContext: Sendable {
    public let projectPath: String
    public let workItemId: String?
    public let additionalContext: String?
    public let tools: [String]

    public init(projectPath: String, workItemId: String? = nil, additionalContext: String? = nil, tools: [String] = []) {
        self.projectPath = projectPath
        self.workItemId = workItemId
        self.additionalContext = additionalContext
        self.tools = tools
    }
}
