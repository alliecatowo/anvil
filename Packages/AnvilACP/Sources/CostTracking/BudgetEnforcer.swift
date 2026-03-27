import Foundation
import AnvilDomain

public actor BudgetEnforcer {
    public struct Budget: Sendable {
        public let provider: String?
        public let project: String?
        public let dailyLimit: Decimal

        public init(provider: String? = nil, project: String? = nil, dailyLimit: Decimal) {
            self.provider = provider
            self.project = project
            self.dailyLimit = dailyLimit
        }
    }

    private var budgets: [Budget] = []
    private let costTracker: ACPCostTracker

    public init(costTracker: ACPCostTracker) {
        self.costTracker = costTracker
    }

    public func addBudget(_ budget: Budget) {
        budgets.append(budget)
    }

    public func canProceed(provider: String, estimatedCost: Decimal) async -> Bool {
        let todayCost = await costTracker.todayCost(provider: provider)
        for budget in budgets {
            if budget.provider == nil || budget.provider == provider {
                if todayCost + estimatedCost > budget.dailyLimit {
                    return false
                }
            }
        }
        return true
    }
}
