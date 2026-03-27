import Foundation

public struct UsageMetric: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let value: Double
    public let unit: String?
    public let period: String
    public let recordedAt: Date

    public init(id: String = UUID().uuidString, name: String, value: Double, unit: String? = nil, period: String, recordedAt: Date = .now) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.period = period
        self.recordedAt = recordedAt
    }
}
