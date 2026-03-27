import Foundation

public struct CostReport: Sendable, Identifiable, Codable {
    public let id: String
    public let totalCost: Decimal
    public let currency: String
    public let lineItems: [CostLineItem]
    public let periodStart: Date
    public let periodEnd: Date
    public let generatedAt: Date

    public init(id: String = UUID().uuidString, totalCost: Decimal, currency: String = "USD", lineItems: [CostLineItem] = [], periodStart: Date, periodEnd: Date, generatedAt: Date = .now) {
        self.id = id
        self.totalCost = totalCost
        self.currency = currency
        self.lineItems = lineItems
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.generatedAt = generatedAt
    }
}

public struct CostLineItem: Sendable, Identifiable, Codable {
    public let id: String
    public let service: String
    public let description: String
    public let amount: Decimal
    public let quantity: Double

    public init(id: String = UUID().uuidString, service: String, description: String, amount: Decimal, quantity: Double = 1) {
        self.id = id
        self.service = service
        self.description = description
        self.amount = amount
        self.quantity = quantity
    }
}
