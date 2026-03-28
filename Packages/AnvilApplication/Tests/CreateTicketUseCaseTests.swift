import XCTest
@testable import AnvilApplication
import AnvilDomain
import Foundation

// MARK: - Mock TicketManagementPort

/// Records all calls so tests can assert on use-case behaviour without real storage.
private actor MockTicketPort: TicketManagementPort {
    var createdTickets: [Ticket] = []
    var updatedTickets: [Ticket] = []
    var deletedIds: [String] = []
    var movedIds: [(id: String, status: String)] = []

    // Optionally inject a failure to verify error propagation
    var shouldThrowOnCreate: Bool = false

    func fetchTickets() async throws -> [Ticket] {
        createdTickets
    }

    func createTicket(_ ticket: Ticket) async throws -> Ticket {
        if shouldThrowOnCreate { throw MockError.forced }
        createdTickets.append(ticket)
        return ticket
    }

    func updateTicket(_ ticket: Ticket) async throws -> Ticket {
        guard createdTickets.contains(where: { $0.id == ticket.id }) else {
            throw TicketServiceError.notFound
        }
        updatedTickets.append(ticket)
        return ticket
    }

    func deleteTicket(id: String) async throws {
        guard createdTickets.contains(where: { $0.id == id }) else {
            throw TicketServiceError.notFound
        }
        deletedIds.append(id)
    }

    func moveTicket(id: String, toStatus newStatus: String) async throws -> Ticket {
        guard let ticket = createdTickets.first(where: { $0.id == id }) else {
            throw TicketServiceError.notFound
        }
        movedIds.append((id, newStatus))
        return ticket
    }
}

private enum MockError: Error { case forced }

// MARK: - CreateTicketUseCase XCTests

final class CreateTicketUseCaseTests: XCTestCase {

    // MARK: - Title

    func testExecuteReturnsTicketWithCorrectTitle() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Fix login bug")
        XCTAssertEqual(ticket.title, "Fix login bug")
    }

    // MARK: - Default field values

    func testExecuteDefaultStatusIsBacklog() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T")
        XCTAssertEqual(ticket.status, "backlog")
    }

    func testExecuteDefaultPriorityIsMedium() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T")
        XCTAssertEqual(ticket.priority, .medium)
    }

    func testExecuteDefaultAssigneeIsNil() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T")
        XCTAssertNil(ticket.assignee)
    }

    func testExecuteDefaultDescriptionIsEmpty() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T")
        XCTAssertTrue(ticket.description.isEmpty)
    }

    func testExecuteDefaultLabelsIsEmpty() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T")
        XCTAssertTrue(ticket.labels.isEmpty)
    }

    func testExecuteDefaultStoryPointsIsNil() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T")
        XCTAssertNil(ticket.storyPoints)
    }

    // MARK: - Custom field values

    func testExecuteStoresPriority() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "Critical", priority: .critical)
        XCTAssertEqual(ticket.priority, .critical)
    }

    func testExecuteStoresAssignee() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T", assignee: "alice")
        XCTAssertEqual(ticket.assignee, "alice")
    }

    func testExecuteStoresLabels() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T", labels: ["bug", "backend"])
        XCTAssertEqual(ticket.labels, ["bug", "backend"])
    }

    func testExecuteStoresStoryPoints() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T", storyPoints: 8)
        XCTAssertEqual(ticket.storyPoints, 8)
    }

    func testExecuteStoresDescription() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T", description: "Detailed body")
        XCTAssertEqual(ticket.description, "Detailed body")
    }

    func testExecuteStoresStatus() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "T", status: "in-progress")
        XCTAssertEqual(ticket.status, "in-progress")
    }

    // MARK: - Port interaction

    func testExecuteCallsCreateTicketOnPort() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        try await useCase.execute(title: "Via port")
        let created = await port.createdTickets
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(created.first?.title, "Via port")
    }

    func testExecuteCallsPortOncePerInvocation() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        try await useCase.execute(title: "First")
        try await useCase.execute(title: "Second")
        try await useCase.execute(title: "Third")
        let created = await port.createdTickets
        XCTAssertEqual(created.count, 3)
    }

    func testExecutePassesAllParametersToPort() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let dueDate = Date(timeIntervalSince1970: 1_700_000_000)
        try await useCase.execute(
            title: "Full",
            description: "desc",
            status: "backlog",
            priority: .high,
            assignee: "bob",
            labels: ["infra"],
            dueDate: dueDate,
            storyPoints: 5
        )
        let created = await port.createdTickets
        let t = try XCTUnwrap(created.first)
        XCTAssertEqual(t.title, "Full")
        XCTAssertEqual(t.description, "desc")
        XCTAssertEqual(t.priority, .high)
        XCTAssertEqual(t.assignee, "bob")
        XCTAssertEqual(t.labels, ["infra"])
        XCTAssertEqual(t.storyPoints, 5)
    }

    // MARK: - ID generation

    func testExecuteReturnsNonEmptyId() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let ticket = try await useCase.execute(title: "ID test")
        XCTAssertFalse(ticket.id.isEmpty)
    }

    func testExecuteProducesUniqueIdsForConsecutiveCalls() async throws {
        let port = MockTicketPort()
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        let t1 = try await useCase.execute(title: "A")
        let t2 = try await useCase.execute(title: "B")
        XCTAssertNotEqual(t1.id, t2.id)
    }

    // MARK: - Error propagation

    func testExecutePropagatesPortError() async throws {
        let port = MockTicketPort()
        await port.setThrowOnCreate(true)
        let useCase = CreateTicketUseCase(ticketPort: port, eventBus: EventBus.shared)
        do {
            try await useCase.execute(title: "Will fail")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is MockError)
        }
    }
}

// MARK: - MockTicketPort helper extension

private extension MockTicketPort {
    func setThrowOnCreate(_ value: Bool) {
        shouldThrowOnCreate = value
    }
}
