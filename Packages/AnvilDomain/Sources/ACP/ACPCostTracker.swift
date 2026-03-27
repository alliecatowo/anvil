import Foundation

public struct ACPCostEstimate: Sendable, Codable {
    public let estimatedInputTokens: Int
    public let estimatedOutputTokens: Int
    public let estimatedCost: Decimal

    public init(estimatedInputTokens: Int, estimatedOutputTokens: Int, estimatedCost: Decimal) {
        self.estimatedInputTokens = estimatedInputTokens
        self.estimatedOutputTokens = estimatedOutputTokens
        self.estimatedCost = estimatedCost
    }
}

public actor ACPCostTracker {
    public struct CostEntry: Sendable {
        public let provider: String
        public let model: String
        public let inputTokens: Int
        public let outputTokens: Int
        public let cost: Decimal
        public let timestamp: Date

        public init(provider: String, model: String, inputTokens: Int, outputTokens: Int, cost: Decimal, timestamp: Date) {
            self.provider = provider
            self.model = model
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cost = cost
            self.timestamp = timestamp
        }
    }

    private var entries: [CostEntry] = []
    private var budgets: [String: Decimal] = [:] // provider -> daily budget

    public init() {}

    public func record(_ entry: CostEntry) {
        entries.append(entry)
    }

    public func todayCost(provider: String? = nil) -> Decimal {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return entries
            .filter { $0.timestamp >= today }
            .filter { provider == nil || $0.provider == provider }
            .reduce(0) { $0 + $1.cost }
    }

    public func sessionCost(since: Date) -> Decimal {
        entries.filter { $0.timestamp >= since }.reduce(0) { $0 + $1.cost }
    }

    public func setBudget(_ budget: Decimal, for provider: String) {
        budgets[provider] = budget
    }

    public func isWithinBudget(provider: String) -> Bool {
        guard let budget = budgets[provider] else { return true }
        return todayCost(provider: provider) < budget
    }
}
