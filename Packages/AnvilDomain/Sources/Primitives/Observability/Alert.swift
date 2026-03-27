import Foundation

public struct Alert: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let query: String
    public let threshold: Double
    public let status: AlertStatus
    public let triggeredAt: Date?
    public let acknowledgedAt: Date?

    public init(id: String = UUID().uuidString, name: String, query: String, threshold: Double, status: AlertStatus = .ok, triggeredAt: Date? = nil, acknowledgedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.query = query
        self.threshold = threshold
        self.status = status
        self.triggeredAt = triggeredAt
        self.acknowledgedAt = acknowledgedAt
    }
}

public enum AlertStatus: String, Sendable, Codable {
    case ok, warning, critical, acknowledged, resolved
}
