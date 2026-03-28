import AnvilDomain
import Foundation

/// In-memory schedule store -- default implementation until a real calendar backend is wired.
public actor InMemoryScheduleService: SchedulePort {
    private var events: [String: CalendarEvent] = [:]
    private var timeBlocks: [String: TimeBlock] = [:]

    public let providerId = "in-memory-schedule"
    public let providerName = "In-Memory Schedule"

    public init() {
        let now = Date()
        let standup = CalendarEvent(
            title: "Daily Standup",
            start: now,
            end: now.addingTimeInterval(900),
            attendees: ["alice", "bob"]
        )
        events[standup.id] = standup

        let deepWork = TimeBlock(title: "Deep Work", start: now, end: now.addingTimeInterval(7200), category: .deepWork)
        timeBlocks[deepWork.id] = deepWork
    }

    public func validateConnection() async throws -> Bool { true }

    public func events(date: Date) async throws -> [CalendarEvent] {
        let calendar = Calendar.current
        return events.values.filter { calendar.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }

    public func event(eventId: String) async throws -> CalendarEvent {
        guard let ev = events[eventId] else { throw ScheduleServiceError.notFound }
        return ev
    }

    public func createEvent(title: String, start: Date, end: Date) async throws -> CalendarEvent {
        let ev = CalendarEvent(title: title, start: start, end: end)
        events[ev.id] = ev
        return ev
    }

    public func updateEvent(eventId: String, title: String?, start: Date?, end: Date?) async throws -> CalendarEvent {
        guard let existing = events[eventId] else { throw ScheduleServiceError.notFound }
        let updated = CalendarEvent(
            id: existing.id,
            title: title ?? existing.title,
            start: start ?? existing.start,
            end: end ?? existing.end,
            isAllDay: existing.isAllDay,
            location: existing.location,
            attendees: existing.attendees,
            meetingUrl: existing.meetingUrl
        )
        events[eventId] = updated
        return updated
    }

    public func deleteEvent(eventId: String) async throws {
        guard events.removeValue(forKey: eventId) != nil else {
            throw ScheduleServiceError.notFound
        }
    }

    public func availability(date: Date) async throws -> [Availability] {
        [Availability(start: date, end: date.addingTimeInterval(28800), status: .free)]
    }

    public func timeBlocks(date: Date) async throws -> [TimeBlock] {
        let calendar = Calendar.current
        return timeBlocks.values.filter { calendar.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }

    public func createTimeBlock(title: String, start: Date, end: Date, category: TimeBlockCategory) async throws -> TimeBlock {
        let block = TimeBlock(title: title, start: start, end: end, category: category)
        timeBlocks[block.id] = block
        return block
    }
}

public enum ScheduleServiceError: Error, Sendable {
    case notFound
}
