import Foundation

public struct Cycle: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let startDate: Date
    public let endDate: Date
    public let ticketIds: [String]
    public let velocity: Int?

    public init(id: String = UUID().uuidString, name: String, startDate: Date, endDate: Date, ticketIds: [String] = [], velocity: Int? = nil) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.ticketIds = ticketIds
        self.velocity = velocity
    }
}
