import Foundation

public struct Availability: Sendable, Identifiable, Codable {
    public let id: String
    public let start: Date
    public let end: Date
    public let status: AvailabilityStatus

    public init(id: String = UUID().uuidString, start: Date, end: Date, status: AvailabilityStatus = .free) {
        self.id = id
        self.start = start
        self.end = end
        self.status = status
    }
}

public enum AvailabilityStatus: String, Sendable, Codable {
    case free, busy, tentative, outOfOffice
}
