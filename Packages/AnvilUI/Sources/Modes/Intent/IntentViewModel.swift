import SwiftUI
import AnvilDomain

// MARK: - View Modes

enum IntentViewMode: String, CaseIterable {
    case list = "List"
    case board = "Board"
}

enum TicketGrouping: String, CaseIterable {
    case status = "Status"
    case priority = "Priority"
    case assignee = "Assignee"
}

enum TicketSortField: String, CaseIterable {
    case priority = "Priority"
    case updated = "Updated"
    case created = "Created"
    case title = "Title"
}

// MARK: - View Model

@MainActor
final class IntentViewModel: ObservableObject {

    // MARK: State

    @Published var tickets: [Ticket] = []
    @Published var selectedTicketId: String?
    @Published var board: Board
    @Published var currentCycle: Cycle
    @Published var relations: [TicketRelation] = []

    // MARK: Filters / Sort

    @Published var searchText = ""
    @Published var viewMode: IntentViewMode = .list
    @Published var grouping: TicketGrouping = .status
    @Published var sortField: TicketSortField = .priority
    @Published var filterPriority: TicketPriority?
    @Published var filterStatus: String?
    @Published var filterAssignee: String?

    // MARK: Editing

    @Published var editingTitle = ""

    // MARK: Computed

    var selectedTicket: Ticket? {
        tickets.first { $0.id == selectedTicketId }
    }

    var filteredTickets: [Ticket] {
        var result = tickets

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query)
                    || $0.description.lowercased().contains(query)
                    || $0.id.lowercased().contains(query)
            }
        }

        if let p = filterPriority {
            result = result.filter { $0.priority == p }
        }
        if let s = filterStatus {
            result = result.filter { $0.status == s }
        }
        if let a = filterAssignee {
            result = result.filter { $0.assignee == a }
        }

        switch sortField {
        case .priority: result.sort { $0.priority < $1.priority }
        case .updated:  result.sort { $0.updatedAt > $1.updatedAt }
        case .created:  result.sort { $0.createdAt > $1.createdAt }
        case .title:    result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        }

        return result
    }

    var groupedTickets: [(String, [Ticket])] {
        let list = filteredTickets
        switch grouping {
        case .status:
            return groupBy(list) { $0.status.capitalized }
        case .priority:
            return groupBy(list) { Self.priorityLabel($0.priority) }
        case .assignee:
            return groupBy(list) { $0.assignee ?? "Unassigned" }
        }
    }

    func ticketsForColumn(_ column: BoardColumn) -> [Ticket] {
        filteredTickets.filter { $0.status == column.status }
    }

    func relationsFor(_ ticketId: String) -> [TicketRelation] {
        relations.filter { $0.sourceId == ticketId || $0.targetId == ticketId }
    }

    // MARK: Actions

    func selectTicket(_ id: String?) {
        selectedTicketId = id
        if let ticket = tickets.first(where: { $0.id == id }) {
            editingTitle = ticket.title
        }
    }

    func updateTitle(_ newTitle: String) {
        guard let id = selectedTicketId,
              let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        tickets[idx].title = newTitle
        tickets[idx].updatedAt = .now
    }

    func clearFilters() {
        filterPriority = nil
        filterStatus = nil
        filterAssignee = nil
        searchText = ""
    }

    // MARK: Helpers

    static func priorityLabel(_ priority: TicketPriority) -> String {
        switch priority {
        case .critical: "P0 - Critical"
        case .high:     "P1 - High"
        case .medium:   "P2 - Medium"
        case .low:      "P3 - Low"
        case .none:     "No Priority"
        }
    }

    static func priorityColor(_ priority: TicketPriority) -> Color {
        switch priority {
        case .critical: AnvilColor.accentRed
        case .high:     AnvilColor.accentAmber
        case .medium:   AnvilColor.accentBlue
        case .low:      AnvilColor.textSecondary
        case .none:     AnvilColor.textTertiary
        }
    }

    static func statusIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "open":        "circle"
        case "in progress": "circle.lefthalf.filled"
        case "in review":   "eye.circle"
        case "done":        "checkmark.circle.fill"
        default:            "circle.dashed"
        }
    }

    static func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "open":        AnvilColor.textSecondary
        case "in progress": AnvilColor.accentBlue
        case "in review":   AnvilColor.accentPurple
        case "done":        AnvilColor.accentGreen
        default:            AnvilColor.textTertiary
        }
    }

    // MARK: Init

    init() {
        let columns = [
            BoardColumn(name: "Open", status: "open", wipLimit: nil),
            BoardColumn(name: "In Progress", status: "in progress", wipLimit: 3),
            BoardColumn(name: "In Review", status: "in review", wipLimit: 2),
            BoardColumn(name: "Done", status: "done", wipLimit: nil),
        ]
        self.board = Board(name: "Sprint Board", columns: columns)

        let now = Date.now
        let calendar = Calendar.current
        let sprintStart = calendar.date(byAdding: .day, value: -5, to: now) ?? now
        let sprintEnd = calendar.date(byAdding: .day, value: 9, to: now) ?? now

        let sampleTickets = Self.makeSampleTickets()
        self.tickets = sampleTickets
        self.currentCycle = Cycle(
            name: "Sprint 14",
            startDate: sprintStart,
            endDate: sprintEnd,
            ticketIds: sampleTickets.map(\.id),
            velocity: 21
        )

        self.relations = [
            TicketRelation(type: .blocks, sourceId: sampleTickets[0].id, targetId: sampleTickets[2].id),
            TicketRelation(type: .related, sourceId: sampleTickets[1].id, targetId: sampleTickets[3].id),
        ]

        selectedTicketId = sampleTickets.first?.id
        editingTitle = sampleTickets.first?.title ?? ""
    }

    // MARK: - Sample Data

    private static func makeSampleTickets() -> [Ticket] {
        let cal = Calendar.current
        let now = Date.now

        return [
            Ticket(
                id: "ANV-101",
                title: "Auth token expiry uses local time instead of UTC",
                description: "The JWT validation in `AuthHandler.validateToken` compares `token.exp` against `Date.now()` but the token was issued with a UTC timestamp. This causes premature session expiration for users in negative UTC offsets.\n\n**Steps to reproduce:**\n1. Set system timezone to PST (UTC-8)\n2. Login and obtain a fresh token\n3. Observe token expires ~8 hours early\n\n**Expected:** Token valid for full TTL regardless of timezone.",
                status: "in progress",
                priority: .critical,
                assignee: "allie.c",
                labels: ["bug", "auth", "p0-sev"],
                dueDate: cal.date(byAdding: .day, value: 2, to: now),
                storyPoints: 3,
                createdAt: cal.date(byAdding: .day, value: -3, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -2, to: now) ?? now
            ),
            Ticket(
                id: "ANV-102",
                title: "Add connection pool timeout to database config",
                description: "Production DB connections occasionally hang without timeout. Add a `connectionTimeout` of 10s to the Postgres pool config and enable SSL in production.\n\nRef: incident INC-892",
                status: "open",
                priority: .high,
                assignee: "daniel.k",
                labels: ["infra", "database"],
                dueDate: cal.date(byAdding: .day, value: 5, to: now),
                storyPoints: 2,
                createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            Ticket(
                id: "ANV-103",
                title: "Implement user preferences API endpoint",
                description: "Create a new REST endpoint `GET/PUT /api/v1/users/:id/preferences` that stores notification settings, theme, and locale. Should follow the existing controller pattern in `src/users/`.",
                status: "in review",
                priority: .medium,
                assignee: "priya.s",
                labels: ["feature", "api"],
                dueDate: cal.date(byAdding: .day, value: 1, to: now),
                storyPoints: 5,
                createdAt: cal.date(byAdding: .day, value: -7, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -6, to: now) ?? now
            ),
            Ticket(
                id: "ANV-104",
                title: "Add sessions table index for user_id lookups",
                description: "Query `SELECT * FROM sessions WHERE user_id = ?` is doing a sequential scan. Add a partial index on `user_id` where `deleted_at IS NULL`.\n\n```sql\nCREATE INDEX CONCURRENTLY idx_sessions_user_id\n  ON sessions (user_id)\n  WHERE deleted_at IS NULL;\n```",
                status: "done",
                priority: .medium,
                assignee: "priya.s",
                labels: ["database", "performance"],
                storyPoints: 1,
                createdAt: cal.date(byAdding: .day, value: -10, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            Ticket(
                id: "ANV-105",
                title: "Migrate feature flags to LaunchDarkly SDK v7",
                description: "The current `feature-flag-service` uses LaunchDarkly SDK v5 which is EOL in April. Migrate to v7, update the streaming connection config, and verify all existing flag evaluations still work.\n\nBlocked by ANV-101 (needs stable auth before flag relay trusts tokens).",
                status: "open",
                priority: .high,
                assignee: "allie.c",
                labels: ["infra", "migration", "feature-flags"],
                dueDate: cal.date(byAdding: .day, value: 10, to: now),
                storyPoints: 8,
                createdAt: cal.date(byAdding: .day, value: -5, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -3, to: now) ?? now
            ),
            Ticket(
                id: "ANV-106",
                title: "Write E2E tests for onboarding flow",
                description: "Cover the happy path and 3 error cases for the new user onboarding wizard. Use Playwright, follow the existing test patterns in `e2e/`.\n\n**Cases:**\n- Happy path: complete all steps\n- Missing required field on step 2\n- Network error on final submit\n- Back-navigation preserves form state",
                status: "open",
                priority: .low,
                assignee: nil,
                labels: ["testing", "onboarding"],
                storyPoints: 5,
                createdAt: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            Ticket(
                id: "ANV-107",
                title: "Refactor notification service to use event bus",
                description: "Currently notifications are sent via direct HTTP calls from 4 different services. Refactor to publish events to the shared event bus and have the notification service subscribe.\n\nThis decouples the producers and lets us add new notification channels (Slack, email) without modifying callers.",
                status: "in progress",
                priority: .medium,
                assignee: "daniel.k",
                labels: ["refactor", "architecture", "notifications"],
                dueDate: cal.date(byAdding: .day, value: 7, to: now),
                storyPoints: 8,
                createdAt: cal.date(byAdding: .day, value: -4, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -1, to: now) ?? now
            ),
        ]
    }

    private func groupBy(_ tickets: [Ticket], key: (Ticket) -> String) -> [(String, [Ticket])] {
        var dict: [String: [Ticket]] = [:]
        var order: [String] = []
        for ticket in tickets {
            let k = key(ticket)
            if dict[k] == nil { order.append(k) }
            dict[k, default: []].append(ticket)
        }
        return order.map { ($0, dict[$0]!) }
    }
}
