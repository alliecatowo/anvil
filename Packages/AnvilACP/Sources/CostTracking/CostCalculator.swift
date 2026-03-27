import Foundation
import AnvilDomain

public struct CostCalculator: Sendable {
    public init() {}

    public func calculate(inputTokens: Int, outputTokens: Int, model: ACPModel) -> Decimal {
        let inputCost = Decimal(inputTokens) * model.inputCostPer1kTokens / 1000
        let outputCost = Decimal(outputTokens) * model.outputCostPer1kTokens / 1000
        return inputCost + outputCost
    }
}
