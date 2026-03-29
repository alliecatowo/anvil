import Foundation
import AnvilDomain

/// Application-layer service for schedule management.
/// Wraps SchedulePort, publishes typed events via EventBus, and exposes
/// a flat list of ScheduleEntries that ViewModels observe directly.
@MainActor
public final class ScheduleService: ObservableObject {

    // MARK: Published state

    @Published public var entries: [ScheduleEntry] = []

    // MARK: Dependencies

    private let schedulePort: any SchedulePort
    private let eventBus: EventBus

    public init(schedulePort: any SchedulePort, eventBus: EventBus) {
        self.schedulePort = schedulePort
        self.eventBus = eventBus
    }

    // MARK: - Load

    public func loadEvents(date: Date = .now) {
        Task {
            do {
                let fetched = try await schedulePort.events(date: date)
                entries = fetched.map { ScheduleEntry(from: $0) }
            } catch {
                // Keep existing entries on failure
            }
        }
    }

    public func loadSampleData() {
        entries = ScheduleEntry.sampleData()
    }

    // MARK: - CRUD

    public func createEvent(title: String, start: Date, end: Date) async throws -> ScheduleEntry {
        let created = try await schedulePort.createEvent(title: title, start: start, end: end)
        let entry = ScheduleEntry(from: created)
        entries.append(entry)
        await eventBus.publish(ScheduleEventCreated(calendarEventId: created.id, title: title))
        return entry
    }

    public func updateEvent(eventId: String, title: String?, start: Date?, end: Date?) async throws -> ScheduleEntry {
        let updated = try await schedulePort.updateEvent(eventId: eventId, title: title, start: start, end: end)
        let entry = ScheduleEntry(from: updated)
        if let idx = entries.firstIndex(where: { $0.id == eventId }) {
            entries[idx] = entry
        }
        await eventBus.publish(ScheduleEventUpdated(eventId: eventId, calendarEventId: updated.id))
        return entry
    }

    public func deleteEvent(eventId: String) async throws {
        try await schedulePort.deleteEvent(eventId: eventId)
        entries.removeAll { $0.id == eventId }
        await eventBus.publish(ScheduleEventDeleted(eventId: eventId, calendarEventId: eventId))
    }
}

// MARK: - ScheduleEntry (display model)

public enum ScheduleEntryKind: Sendable {
    case meeting
    case focusBlock
    case breakBlock
    case taskDue
}

public struct ScheduleEntry: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let kind: ScheduleEntryKind
    public let subtitle: String?
    public let linkedTicket: String?
    public let attendees: [String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        start: Date,
        end: Date,
        kind: ScheduleEntryKind,
        subtitle: String? = nil,
        linkedTicket: String? = nil,
        attendees: [String] = []
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.kind = kind
        self.subtitle = subtitle
        self.linkedTicket = linkedTicket
        self.attendees = attendees
    }

    public init(from event: CalendarEvent) {
        self.init(
            id: event.id,
            title: event.title,
            start: event.start,
            end: event.end,
            kind: event.attendees.isEmpty ? .focusBlock : .meeting,
            subtitle: event.location,
            linkedTicket: nil,
            attendees: event.attendees
        )
    }

    public var duration: String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    public var kindLabel: String {
        switch kind {
        case .meeting: "Meeting"
        case .focusBlock: "Focus"
        case .breakBlock: "Break"
        case .taskDue: "Due"
        }
    }

    public var kindIcon: String {
        switch kind {
        case .meeting: "video"
        case .focusBlock: "brain.head.profile"
        case .breakBlock: "cup.and.saucer"
        case .taskDue: "checkmark.square"
        }
    }

    public static func sampleData() -> [ScheduleEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }
        return [
            ScheduleEntry(id: "s-1", title: "Morning Focus: Exercise Service Refactor", start: time(9, 0), end: time(10, 30), kind: .focusBlock, subtitle: "Deep work on session config broker", linkedTicket: "CARB-3406", attendees: []),
            ScheduleEntry(id: "s-2", title: "Sprint Planning", start: time(10, 30), end: time(11, 30), kind: .meeting, subtitle: "Exercise team sprint planning - week 12", linkedTicket: nil, attendees: ["Marcus", "Sarah", "Dev", "Allie"]),
            ScheduleEntry(id: "s-3", title: "Lunch Break", start: time(12, 0), end: time(13, 0), kind: .breakBlock, subtitle: nil, linkedTicket: nil, attendees: []),
            ScheduleEntry(id: "s-4", title: "PR Review: Daily ET Session Metrics", start: time(13, 0), end: time(13, 45), kind: .taskDue, subtitle: "Review Marcus's PR #482 before EOD", linkedTicket: "CARB-3412", attendees: []),
            ScheduleEntry(id: "s-5", title: "1:1 with Sarah", start: time(14, 0), end: time(14, 30), kind: .meeting, subtitle: "Weekly sync - architecture discussion", linkedTicket: nil, attendees: ["Sarah", "Allie"]),
            ScheduleEntry(id: "s-6", title: "Afternoon Focus: Test Coverage", start: time(14, 30), end: time(16, 30), kind: .focusBlock, subtitle: "Integration tests for session config flow", linkedTicket: "CARB-3406", attendees: []),
        ]
    }
}

// MARK: - Domain Events

public struct ScheduleEventCreated: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "schedule"
    public let calendarEventId: String
    public let title: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, calendarEventId: String, title: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.calendarEventId = calendarEventId
        self.title = title
    }
}

public struct ScheduleEventUpdated: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "schedule"
    public let calendarEventId: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, calendarEventId: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.calendarEventId = calendarEventId
    }
}

public struct ScheduleEventDeleted: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "schedule"
    public let calendarEventId: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, calendarEventId: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.calendarEventId = calendarEventId
    }
}
