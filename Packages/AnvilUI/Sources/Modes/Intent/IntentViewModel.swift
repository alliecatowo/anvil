import SwiftUI
import AnvilDomain
import AnvilApplication

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
    case dueDate = "Due Date"
    case updated = "Updated"
    case created = "Created"
    case title = "Title"
}

// MARK: - View Model

@MainActor
public final class IntentViewModel: ObservableObject {

    // MARK: EventBus

    private var eventBus: EventBus?

    /// Configure the event bus for domain event publishing.
    public func configure(eventBus: EventBus) {
        self.eventBus = eventBus
    }

    // MARK: State

    @Published var tickets: [Ticket] = []
    @Published var selectedTicketId: String?
    @Published var board: Board
    @Published var currentCycle: Cycle
    @Published var relations: [TicketRelation] = []
    @Published var subtasks: [String: [Subtask]] = [:]
    @Published var comments: [String: [TicketComment]] = [:]

    // MARK: Filters / Sort

    @Published var searchText = ""
    @Published var viewMode: IntentViewMode = .list
    @Published var grouping: TicketGrouping = .status
    @Published var sortField: TicketSortField = .priority
    @Published var filterPriority: TicketPriority?
    @Published var filterStatus: String?
    @Published var filterAssignee: String?

    // MARK: Editing

    @Published var isCreatingTicket = false
    @Published var editingTitle = ""
    @Published var editingDescription = ""
    @Published var newCommentText = ""
    @Published var newSubtaskTitle = ""

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
        case .dueDate:  result.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
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

    var allStatuses: [String] {
        board.columns.map(\.status)
    }

    var allAssignees: [String] {
        let names = Set(tickets.compactMap(\.assignee))
        return names.sorted()
    }

    func ticketsForColumn(_ column: BoardColumn) -> [Ticket] {
        filteredTickets.filter { $0.status == column.status }
    }

    func relationsFor(_ ticketId: String) -> [TicketRelation] {
        relations.filter { $0.sourceId == ticketId || $0.targetId == ticketId }
    }

    func subtasksFor(_ ticketId: String) -> [Subtask] {
        subtasks[ticketId] ?? []
    }

    func commentsFor(_ ticketId: String) -> [TicketComment] {
        comments[ticketId] ?? []
    }

    func subtaskProgress(_ ticketId: String) -> (completed: Int, total: Int) {
        let items = subtasksFor(ticketId)
        return (items.filter(\.isCompleted).count, items.count)
    }

    // MARK: - Relation Actions

    func addRelation(type: TicketRelationType, sourceId: String, targetId: String) {
        guard sourceId != targetId else { return }
        let exists = relations.contains {
            ($0.sourceId == sourceId && $0.targetId == targetId && $0.type == type) ||
            ($0.sourceId == targetId && $0.targetId == sourceId && $0.type == type)
        }
        guard !exists else { return }
        let relation = TicketRelation(type: type, sourceId: sourceId, targetId: targetId)
        relations.append(relation)
    }

    func removeRelation(id: String) {
        relations.removeAll { $0.id == id }
    }

    // MARK: - Use Case Integration

    private var ticketPort: (any TicketManagementPort)?
    private var createTicketUseCase: CreateTicketUseCase?

    /// Configure the ticket management port and use case for persistence through the application layer.
    public func configure(ticketPort: any TicketManagementPort, createUseCase: CreateTicketUseCase) {
        self.ticketPort = ticketPort
        self.createTicketUseCase = createUseCase
    }

    // MARK: - Ticket CRUD

    /// Move a ticket to a new status (used by kanban drag-and-drop).
    func moveTicket(_ ticketId: String, toStatus newStatus: String) {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        let oldStatus = tickets[idx].status
        tickets[idx].status = newStatus
        tickets[idx].updatedAt = .now
        Task { [eventBus] in
            await eventBus?.publish(AnyDomainEvent(
                sourcePrimitive: "tickets",
                payload: ["action": "statusChanged", "ticketId": ticketId, "oldStatus": oldStatus, "newStatus": newStatus]
            ))
        }
    }

    /// Quick-create a ticket with just a title and status.
    func createTicket(title: String, status: String = "backlog") {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let useCase = createTicketUseCase {
            Task { @MainActor in
                if let created = try? await useCase.execute(title: trimmed, status: status) {
                    tickets.append(created)
                }
            }
        } else {
            let ticket = Ticket(title: trimmed, status: status)
            tickets.append(ticket)
            Task { [eventBus] in
                await eventBus?.publish(AnyDomainEvent(
                    sourcePrimitive: "tickets",
                    payload: ["action": "created", "ticketId": ticket.id, "title": trimmed]
                ))
            }
        }
    }

    /// Full-create a ticket with all fields.
    func createTicketFull(title: String, description: String = "", status: String = "backlog", priority: TicketPriority = .medium, assignee: String? = nil, dueDate: Date? = nil, storyPoints: Int? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let useCase = createTicketUseCase {
            Task { @MainActor in
                if let created = try? await useCase.execute(
                    title: trimmed,
                    description: description,
                    status: status,
                    priority: priority,
                    assignee: assignee,
                    dueDate: dueDate,
                    storyPoints: storyPoints
                ) {
                    tickets.append(created)
                    selectedTicketId = created.id
                    editingTitle = created.title
                    editingDescription = created.description
                }
            }
        } else {
            let ticket = Ticket(title: trimmed, description: description, status: status, priority: priority, assignee: assignee, dueDate: dueDate, storyPoints: storyPoints)
            tickets.append(ticket)
            selectedTicketId = ticket.id
            editingTitle = ticket.title
            editingDescription = ticket.description
        }
    }

    func deleteTicket(_ ticketId: String) {
        tickets.removeAll { $0.id == ticketId }
        subtasks.removeValue(forKey: ticketId)
        comments.removeValue(forKey: ticketId)
        relations.removeAll { $0.sourceId == ticketId || $0.targetId == ticketId }
        if selectedTicketId == ticketId {
            selectedTicketId = nil
        }
        Task { [eventBus] in
            await eventBus?.publish(AnyDomainEvent(
                sourcePrimitive: "tickets",
                payload: ["action": "deleted", "ticketId": ticketId]
            ))
        }
    }

    func selectTicket(_ id: String?) {
        selectedTicketId = id
        if let ticket = tickets.first(where: { $0.id == id }) {
            editingTitle = ticket.title
            editingDescription = ticket.description
        }
        newCommentText = ""
        newSubtaskTitle = ""
    }

    func updateTitle(_ newTitle: String) {
        guard let id = selectedTicketId,
              let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        tickets[idx].title = newTitle
        tickets[idx].updatedAt = .now
    }

    func updateDescription(_ newDescription: String) {
        guard let id = selectedTicketId,
              let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        tickets[idx].description = newDescription
        tickets[idx].updatedAt = .now
    }

    func updateStatus(_ ticketId: String, status: String) {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        tickets[idx].status = status
        tickets[idx].updatedAt = .now
    }

    func updatePriority(_ ticketId: String, priority: TicketPriority) {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        tickets[idx].priority = priority
        tickets[idx].updatedAt = .now
    }

    func updateAssignee(_ ticketId: String, assignee: String?) {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        tickets[idx].assignee = assignee
        tickets[idx].updatedAt = .now
    }

    func updateDueDate(_ ticketId: String, dueDate: Date?) {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        tickets[idx].dueDate = dueDate
        tickets[idx].updatedAt = .now
    }

    func updateStoryPoints(_ ticketId: String, storyPoints: Int?) {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        tickets[idx].storyPoints = storyPoints
        tickets[idx].updatedAt = .now
    }

    // MARK: - Subtask Actions

    func addSubtask(to ticketId: String, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let subtask = Subtask(ticketId: ticketId, title: trimmed)
        subtasks[ticketId, default: []].append(subtask)
    }

    func toggleSubtask(ticketId: String, subtaskId: String) {
        guard let idx = subtasks[ticketId]?.firstIndex(where: { $0.id == subtaskId }) else { return }
        subtasks[ticketId]?[idx].isCompleted.toggle()
    }

    func deleteSubtask(ticketId: String, subtaskId: String) {
        subtasks[ticketId]?.removeAll { $0.id == subtaskId }
    }

    // MARK: - Comment Actions

    func addComment(to ticketId: String, author: String = "You", body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = TicketComment(ticketId: ticketId, author: author, body: trimmed)
        comments[ticketId, default: []].append(comment)
    }

    func deleteComment(ticketId: String, commentId: String) {
        comments[ticketId]?.removeAll { $0.id == commentId }
    }

    // MARK: - Filters

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
        case "backlog":     "circle.dashed"
        case "todo":        "circle"
        case "in progress": "circle.lefthalf.filled"
        case "in review":   "eye.circle"
        case "done":        "checkmark.circle.fill"
        default:            "circle.dashed"
        }
    }

    static func dueDateColor(_ date: Date) -> Color {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return AnvilColor.accentRed }
        if days <= 2 { return AnvilColor.accentAmber }
        return AnvilColor.textTertiary
    }

    static func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "backlog":     AnvilColor.textTertiary
        case "todo":        AnvilColor.textSecondary
        case "in progress": AnvilColor.accentBlue
        case "in review":   AnvilColor.accentPurple
        case "done":        AnvilColor.accentGreen
        default:            AnvilColor.textTertiary
        }
    }

    // MARK: Init

    public init() {
        let columns = [
            BoardColumn(name: "Backlog", status: "backlog", wipLimit: nil),
            BoardColumn(name: "Todo", status: "todo", wipLimit: nil),
            BoardColumn(name: "In Progress", status: "in progress", wipLimit: 3),
            BoardColumn(name: "In Review", status: "in review", wipLimit: 2),
            BoardColumn(name: "Done", status: "done", wipLimit: nil),
        ]
        self.board = Board(name: "Sprint Board", columns: columns)

        let cal = Calendar.current
        let now = Date.now
        let sprintStart = cal.date(byAdding: .day, value: -5, to: now) ?? now
        let sprintEnd = cal.date(byAdding: .day, value: 9, to: now) ?? now

        let demoTickets = Self.makeDemoTickets()
        self.tickets = demoTickets

        self.currentCycle = Cycle(
            name: "Sprint 14",
            startDate: sprintStart,
            endDate: sprintEnd,
            ticketIds: demoTickets.map(\.id),
            velocity: 21
        )

        self.relations = [
            TicketRelation(type: .blocks, sourceId: "ANV-101", targetId: "ANV-105"),
            TicketRelation(type: .related, sourceId: "ANV-102", targetId: "ANV-104"),
            TicketRelation(type: .parent, sourceId: "ANV-107", targetId: "ANV-112"),
        ]

        // Demo subtasks
        self.subtasks = Self.makeDemoSubtasks()
        self.comments = Self.makeDemoComments()
    }

    // MARK: - Demo Data

    private static func makeDemoTickets() -> [Ticket] {
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
                status: "todo",
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
                status: "backlog",
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
                status: "backlog",
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
            Ticket(
                id: "ANV-108",
                title: "Set up rate limiting for public API endpoints",
                description: "Add a sliding-window rate limiter to all public `/api/v1/` endpoints. Default: 100 req/min per API key, 1000 req/min per organization. Use Redis for distributed counting.",
                status: "todo",
                priority: .high,
                assignee: "allie.c",
                labels: ["security", "api"],
                dueDate: cal.date(byAdding: .day, value: 4, to: now),
                storyPoints: 5,
                createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            Ticket(
                id: "ANV-109",
                title: "Add Prometheus metrics to payment service",
                description: "Instrument the payment service with Prometheus metrics:\n- `payment_requests_total` (counter)\n- `payment_duration_seconds` (histogram)\n- `payment_failures_total` (counter with error_type label)\n\nUse the `prom-client` library.",
                status: "todo",
                priority: .medium,
                assignee: "priya.s",
                labels: ["observability", "payments"],
                storyPoints: 3,
                createdAt: cal.date(byAdding: .day, value: -3, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            Ticket(
                id: "ANV-110",
                title: "Fix CORS preflight caching in production",
                description: "OPTIONS preflight responses are not being cached by browsers because `Access-Control-Max-Age` is missing. Add the header with a 24h TTL to reduce redundant preflight requests.",
                status: "done",
                priority: .low,
                assignee: "daniel.k",
                labels: ["bug", "performance"],
                storyPoints: 1,
                createdAt: cal.date(byAdding: .day, value: -8, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            Ticket(
                id: "ANV-111",
                title: "Design webhook retry backoff strategy",
                description: "Current webhook delivery retries immediately on failure. Design and implement exponential backoff with jitter: 1s, 2s, 4s, 8s, 16s, max 5 retries. Store retry state in the outbox table.",
                status: "backlog",
                priority: .medium,
                assignee: nil,
                labels: ["architecture", "webhooks"],
                storyPoints: 5,
                createdAt: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            Ticket(
                id: "ANV-112",
                title: "Create Slack notification channel adapter",
                description: "Implement the Slack adapter for the new notification event bus (child of ANV-107). Support rich Block Kit messages for deployment alerts and PR review requests.",
                status: "backlog",
                priority: .low,
                assignee: nil,
                labels: ["feature", "notifications", "slack"],
                storyPoints: 3,
                createdAt: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            Ticket(
                id: "ANV-113",
                title: "Upgrade Node.js runtime from 18 to 20 LTS",
                description: "Node 18 reaches EOL in April 2025. Update the base Docker image, CI runners, and local `.nvmrc` to Node 20 LTS. Run the full test suite to catch any breaking changes.",
                status: "backlog",
                priority: .medium,
                assignee: "daniel.k",
                labels: ["infra", "migration"],
                dueDate: cal.date(byAdding: .day, value: 14, to: now),
                storyPoints: 3,
                createdAt: cal.date(byAdding: .day, value: -6, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -4, to: now) ?? now
            ),
            Ticket(
                id: "ANV-114",
                title: "Add CSV export for analytics dashboard",
                description: "Users have requested the ability to export analytics data as CSV files. Add an export button to the dashboard header that generates a CSV with the currently visible date range and metrics.",
                status: "in review",
                priority: .low,
                assignee: "priya.s",
                labels: ["feature", "analytics"],
                storyPoints: 2,
                createdAt: cal.date(byAdding: .day, value: -5, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -4, to: now) ?? now
            ),
            Ticket(
                id: "ANV-115",
                title: "Implement API key rotation without downtime",
                description: "When users rotate their API key, there should be a grace period where both old and new keys work. Implement a 24h overlap window using the `api_keys` table's `expires_at` column.",
                status: "todo",
                priority: .high,
                assignee: nil,
                labels: ["security", "api"],
                storyPoints: 5,
                createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -1, to: now) ?? now
            ),
        ]
    }

    private static func makeDemoSubtasks() -> [String: [Subtask]] {
        [
            "ANV-101": [
                Subtask(ticketId: "ANV-101", title: "Identify all Date.now() calls in auth module", isCompleted: true),
                Subtask(ticketId: "ANV-101", title: "Replace with UTC-based comparison", isCompleted: true),
                Subtask(ticketId: "ANV-101", title: "Add timezone-aware unit tests", isCompleted: false),
                Subtask(ticketId: "ANV-101", title: "Test across PST, EST, UTC, IST timezones", isCompleted: false),
            ],
            "ANV-103": [
                Subtask(ticketId: "ANV-103", title: "Create GET endpoint", isCompleted: true),
                Subtask(ticketId: "ANV-103", title: "Create PUT endpoint", isCompleted: true),
                Subtask(ticketId: "ANV-103", title: "Add input validation", isCompleted: true),
                Subtask(ticketId: "ANV-103", title: "Write integration tests", isCompleted: false),
                Subtask(ticketId: "ANV-103", title: "Update API docs", isCompleted: false),
            ],
            "ANV-107": [
                Subtask(ticketId: "ANV-107", title: "Define event schema for notifications", isCompleted: true),
                Subtask(ticketId: "ANV-107", title: "Create event bus publisher", isCompleted: true),
                Subtask(ticketId: "ANV-107", title: "Create event bus subscriber", isCompleted: false),
                Subtask(ticketId: "ANV-107", title: "Migrate email service to use events", isCompleted: false),
                Subtask(ticketId: "ANV-107", title: "Migrate push notification service", isCompleted: false),
                Subtask(ticketId: "ANV-107", title: "Remove direct HTTP calls", isCompleted: false),
            ],
            "ANV-108": [
                Subtask(ticketId: "ANV-108", title: "Set up Redis sliding window counter", isCompleted: false),
                Subtask(ticketId: "ANV-108", title: "Add rate limit middleware", isCompleted: false),
                Subtask(ticketId: "ANV-108", title: "Add rate limit headers to responses", isCompleted: false),
                Subtask(ticketId: "ANV-108", title: "Write load tests", isCompleted: false),
            ],
        ]
    }

    private static func makeDemoComments() -> [String: [TicketComment]] {
        let cal = Calendar.current
        let now = Date.now

        return [
            "ANV-101": [
                TicketComment(ticketId: "ANV-101", author: "daniel.k", body: "Confirmed this affects all users west of UTC. Logs show token rejections spiking at 4-5 PM PST.", createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now),
                TicketComment(ticketId: "ANV-101", author: "allie.c", body: "Found the root cause - the JWT library defaults to local time when no timezone is specified. Working on a fix now.", createdAt: cal.date(byAdding: .day, value: -1, to: now) ?? now),
                TicketComment(ticketId: "ANV-101", author: "priya.s", body: "Should we also audit the refresh token flow? It might have the same issue.", createdAt: cal.date(byAdding: .hour, value: -6, to: now) ?? now),
            ],
            "ANV-107": [
                TicketComment(ticketId: "ANV-107", author: "daniel.k", body: "Started with the event schema. Using CloudEvents spec for the envelope format.", createdAt: cal.date(byAdding: .day, value: -3, to: now) ?? now),
                TicketComment(ticketId: "ANV-107", author: "allie.c", body: "Makes sense. Let's make sure we have dead letter queue support from the start.", createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now),
            ],
            "ANV-103": [
                TicketComment(ticketId: "ANV-103", author: "priya.s", body: "PR is up for review. Added validation for all preference fields and wrote 12 test cases.", createdAt: cal.date(byAdding: .hour, value: -8, to: now) ?? now),
            ],
        ]
    }

    // MARK: - Sample Data (for previews only)

    #if DEBUG
    static func withSampleData() -> IntentViewModel {
        return IntentViewModel()
    }
    #endif

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
