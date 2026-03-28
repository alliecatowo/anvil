import SwiftUI
import AnvilDomain

// MARK: - Schedule Tab

enum ScheduleTab: String, CaseIterable {
    case agenda = "Agenda"
    case blocks = "Time Blocks"
}

// MARK: - Schedule Entry (unified display model)

enum ScheduleEntryKind {
    case meeting
    case focusBlock
    case breakBlock
    case taskDue
}

struct ScheduleEntry: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let kind: ScheduleEntryKind
    let subtitle: String?
    let linkedTicket: String?
    let attendees: [String]

    var duration: String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    var kindColor: Color {
        switch kind {
        case .meeting: AnvilColor.accentBlue
        case .focusBlock: AnvilColor.accentPurple
        case .breakBlock: AnvilColor.accentGreen
        case .taskDue: AnvilColor.accentAmber
        }
    }

    var kindIcon: String {
        switch kind {
        case .meeting: "video"
        case .focusBlock: "brain.head.profile"
        case .breakBlock: "cup.and.saucer"
        case .taskDue: "checkmark.square"
        }
    }

    var kindLabel: String {
        switch kind {
        case .meeting: "Meeting"
        case .focusBlock: "Focus"
        case .breakBlock: "Break"
        case .taskDue: "Due"
        }
    }
}

// MARK: - View Model

@MainActor
final class ScheduleViewModel: ObservableObject {

    // MARK: Navigation

    @Published var selectedTab: ScheduleTab = .agenda
    @Published var selectedEntryID: String?

    // MARK: Data

    @Published var entries: [ScheduleEntry] = []

    // MARK: Computed

    var selectedEntry: ScheduleEntry? {
        entries.first { $0.id == selectedEntryID }
    }

    var meetingCount: Int {
        entries.filter { $0.kind == .meeting }.count
    }

    var focusMinutes: Int {
        entries.filter { $0.kind == .focusBlock }
            .reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
    }

    // MARK: Init

    init() {
        self.entries = []
        self.selectedEntryID = nil
    }

    /// Load sample data for previews and demos.
    func loadSampleData() {
        self.entries = Self.makeSampleData()
        self.selectedEntryID = entries.first?.id
    }

    // MARK: - Sample Data

    static func makeSampleData() -> [ScheduleEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }

        return [
            ScheduleEntry(
                id: "s-1",
                title: "Morning Focus: Exercise Service Refactor",
                start: time(9, 0),
                end: time(10, 30),
                kind: .focusBlock,
                subtitle: "Deep work on session config broker",
                linkedTicket: "CARB-3406",
                attendees: []
            ),
            ScheduleEntry(
                id: "s-2",
                title: "Sprint Planning",
                start: time(10, 30),
                end: time(11, 30),
                kind: .meeting,
                subtitle: "Exercise team sprint planning - week 12",
                linkedTicket: nil,
                attendees: ["Marcus", "Sarah", "Dev", "Allie"]
            ),
            ScheduleEntry(
                id: "s-3",
                title: "Lunch Break",
                start: time(12, 0),
                end: time(13, 0),
                kind: .breakBlock,
                subtitle: nil,
                linkedTicket: nil,
                attendees: []
            ),
            ScheduleEntry(
                id: "s-4",
                title: "PR Review: Daily ET Session Metrics",
                start: time(13, 0),
                end: time(13, 45),
                kind: .taskDue,
                subtitle: "Review Marcus's PR #482 before EOD",
                linkedTicket: "CARB-3412",
                attendees: []
            ),
            ScheduleEntry(
                id: "s-5",
                title: "1:1 with Sarah",
                start: time(14, 0),
                end: time(14, 30),
                kind: .meeting,
                subtitle: "Weekly sync - architecture discussion",
                linkedTicket: nil,
                attendees: ["Sarah", "Allie"]
            ),
            ScheduleEntry(
                id: "s-6",
                title: "Afternoon Focus: Test Coverage",
                start: time(14, 30),
                end: time(16, 30),
                kind: .focusBlock,
                subtitle: "Integration tests for session config flow",
                linkedTicket: "CARB-3406",
                attendees: []
            ),
        ]
    }
}
