import Testing
@testable import AnvilApplication
import AnvilDomain
import Foundation

// MARK: - InMemoryTicketService

@Suite("InMemoryTicketService")
struct InMemoryTicketServiceTests {

    // MARK: create + fetch

    @Test func createAndFetch() async throws {
        let service = InMemoryTicketService()
        let ticket = Ticket(title: "Fix login bug")
        let created = try await service.createTicket(ticket)
        let all = try await service.fetchTickets()
        #expect(all.contains { $0.id == created.id })
    }

    @Test func fetchReturnsAllCreated() async throws {
        let service = InMemoryTicketService()
        try await service.createTicket(Ticket(title: "Ticket A"))
        try await service.createTicket(Ticket(title: "Ticket B"))
        try await service.createTicket(Ticket(title: "Ticket C"))
        let all = try await service.fetchTickets()
        #expect(all.count == 3)
    }

    @Test func fetchOrderedByCreatedAtDescending() async throws {
        let service = InMemoryTicketService()
        let older = Ticket(title: "Older", createdAt: Date(timeIntervalSinceNow: -200), updatedAt: Date(timeIntervalSinceNow: -200))
        let newer = Ticket(title: "Newer", createdAt: Date(timeIntervalSinceNow: -10), updatedAt: Date(timeIntervalSinceNow: -10))
        try await service.createTicket(older)
        try await service.createTicket(newer)
        let all = try await service.fetchTickets()
        #expect(all.first?.title == "Newer")
    }

    @Test func fetchEmptyServiceReturnsEmpty() async throws {
        let service = InMemoryTicketService()
        let all = try await service.fetchTickets()
        #expect(all.isEmpty)
    }

    // MARK: update

    @Test func updateChangesTitle() async throws {
        let service = InMemoryTicketService()
        var ticket = try await service.createTicket(Ticket(title: "Original"))
        ticket.title = "Updated"
        let result = try await service.updateTicket(ticket)
        #expect(result.title == "Updated")
    }

    @Test func updateChangesPriority() async throws {
        let service = InMemoryTicketService()
        var ticket = try await service.createTicket(Ticket(title: "T1", priority: .low))
        ticket.priority = .critical
        let result = try await service.updateTicket(ticket)
        #expect(result.priority == .critical)
    }

    @Test func updateChangesStatus() async throws {
        let service = InMemoryTicketService()
        var ticket = try await service.createTicket(Ticket(title: "T2", status: "backlog"))
        ticket.status = "done"
        let result = try await service.updateTicket(ticket)
        #expect(result.status == "done")
    }

    @Test func updateNonExistentThrows() async throws {
        let service = InMemoryTicketService()
        let phantom = Ticket(title: "Ghost")
        await #expect(throws: TicketServiceError.notFound) {
            try await service.updateTicket(phantom)
        }
    }

    @Test func updateIsPersisted() async throws {
        let service = InMemoryTicketService()
        var ticket = try await service.createTicket(Ticket(title: "Persist Me"))
        ticket.assignee = "alice"
        try await service.updateTicket(ticket)
        let all = try await service.fetchTickets()
        #expect(all.first { $0.id == ticket.id }?.assignee == "alice")
    }

    // MARK: delete

    @Test func deleteRemovesTicket() async throws {
        let service = InMemoryTicketService()
        let ticket = try await service.createTicket(Ticket(title: "To Delete"))
        try await service.deleteTicket(id: ticket.id)
        let all = try await service.fetchTickets()
        #expect(!all.contains { $0.id == ticket.id })
    }

    @Test func deleteReducesCount() async throws {
        let service = InMemoryTicketService()
        let t1 = try await service.createTicket(Ticket(title: "Keep"))
        let t2 = try await service.createTicket(Ticket(title: "Delete Me"))
        try await service.deleteTicket(id: t2.id)
        let all = try await service.fetchTickets()
        #expect(all.count == 1)
        #expect(all.first?.id == t1.id)
    }

    @Test func deleteNonExistentThrows() async throws {
        let service = InMemoryTicketService()
        await #expect(throws: TicketServiceError.notFound) {
            try await service.deleteTicket(id: "does-not-exist")
        }
    }

    // MARK: moveTicket

    @Test func moveTicketChangesStatus() async throws {
        let service = InMemoryTicketService()
        let ticket = try await service.createTicket(Ticket(title: "Movable", status: "backlog"))
        let moved = try await service.moveTicket(id: ticket.id, toStatus: "in-progress")
        #expect(moved.status == "in-progress")
        #expect(moved.id == ticket.id)
    }

    @Test func moveTicketUpdatesUpdatedAt() async throws {
        let service = InMemoryTicketService()
        let before = Date(timeIntervalSinceNow: -10)
        let ticket = Ticket(title: "T", createdAt: before, updatedAt: before)
        try await service.createTicket(ticket)
        let moved = try await service.moveTicket(id: ticket.id, toStatus: "done")
        #expect(moved.updatedAt > before)
    }

    @Test func moveTicketNonExistentThrows() async throws {
        let service = InMemoryTicketService()
        await #expect(throws: TicketServiceError.notFound) {
            try await service.moveTicket(id: "missing", toStatus: "done")
        }
    }

    @Test func moveTicketIsPersisted() async throws {
        let service = InMemoryTicketService()
        let ticket = try await service.createTicket(Ticket(title: "Persist Move", status: "backlog"))
        try await service.moveTicket(id: ticket.id, toStatus: "review")
        let all = try await service.fetchTickets()
        #expect(all.first { $0.id == ticket.id }?.status == "review")
    }
}

// MARK: - CreateTicketUseCase

@Suite("CreateTicketUseCase")
struct CreateTicketUseCaseTests {

    @Test func createsTicketWithCorrectTitle() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Auth bug fix")
        #expect(ticket.title == "Auth bug fix")
    }

    @Test func createsTicketWithDefaultStatus() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Default status ticket")
        #expect(ticket.status == "backlog")
    }

    @Test func createsTicketWithDefaultPriority() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Default priority ticket")
        #expect(ticket.priority == .medium)
    }

    @Test func createsTicketWithCustomPriority() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Critical fix", priority: .critical)
        #expect(ticket.priority == .critical)
    }

    @Test func createsTicketWithAssignee() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Assigned", assignee: "alice")
        #expect(ticket.assignee == "alice")
    }

    @Test func createsTicketWithLabels() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Labelled", labels: ["bug", "backend"])
        #expect(ticket.labels == ["bug", "backend"])
    }

    @Test func createsTicketWithStoryPoints() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Pointed", storyPoints: 8)
        #expect(ticket.storyPoints == 8)
    }

    @Test func createsTicketAndPersistsIt() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let created = try await useCase.execute(title: "Persist test")
        let all = try await service.fetchTickets()
        #expect(all.contains { $0.id == created.id })
    }

    @Test func multipleCretaionsProduceUniqueIds() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let t1 = try await useCase.execute(title: "A")
        let t2 = try await useCase.execute(title: "B")
        #expect(t1.id != t2.id)
    }

    @Test func createsTicketWithDescription() async throws {
        let service = InMemoryTicketService()
        let useCase = CreateTicketUseCase(ticketPort: service, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Described", description: "This is the body")
        #expect(ticket.description == "This is the body")
    }
}
