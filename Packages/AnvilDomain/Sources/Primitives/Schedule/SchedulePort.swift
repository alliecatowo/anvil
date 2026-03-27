import Foundation

public protocol SchedulePort: AnvilProviderDefinition {
    func events(date: Date) async throws -> [CalendarEvent]
    func event(eventId: String) async throws -> CalendarEvent
    func createEvent(title: String, start: Date, end: Date) async throws -> CalendarEvent
    func updateEvent(eventId: String, title: String?, start: Date?, end: Date?) async throws -> CalendarEvent
    func deleteEvent(eventId: String) async throws
    func availability(date: Date) async throws -> [Availability]
    func timeBlocks(date: Date) async throws -> [TimeBlock]
    func createTimeBlock(title: String, start: Date, end: Date, category: TimeBlockCategory) async throws -> TimeBlock
}
