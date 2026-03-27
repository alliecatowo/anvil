import Foundation

public struct CalendarEvent: Sendable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let location: String?
    public let attendees: [String]
    public let meetingUrl: String?

    public init(id: String = UUID().uuidString, title: String, start: Date, end: Date, isAllDay: Bool = false, location: String? = nil, attendees: [String] = [], meetingUrl: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.attendees = attendees
        self.meetingUrl = meetingUrl
    }
}
