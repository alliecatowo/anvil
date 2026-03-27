import Foundation

public struct Metric: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let value: Double
    public let unit: String?
    public let timestamp: Date
    public let tags: [String: String]

    public init(id: String = UUID().uuidString, name: String, value: Double, unit: String? = nil, timestamp: Date = .now, tags: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.tags = tags
    }
}
