import XCTest
@testable import AnvilInfrastructure
import AnvilDomain
import AnvilApplication
import Foundation

final class SQLiteTicketRepositoryTests: XCTestCase {

    var repo: SQLiteTicketRepository!
    var dbPath: String!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("anvil-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbPath = dir.appendingPathComponent("tickets-test.sqlite").path
        repo = SQLiteTicketRepository(dbPath: dbPath)
        try await repo.open()
    }

    override func tearDown() async throws {
        await repo.close()
        if let path = dbPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        repo = nil
    }

    // MARK: - Open / Schema

    func testOpenCreatesDatabase() throws {
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbPath))
    }

    func testFetchOnFreshDatabaseReturnsEmpty() async throws {
        let tickets = try await repo.fetchTickets()
        XCTAssertTrue(tickets.isEmpty)
    }

    // MARK: - Create

    func testCreateReturnsTicketWithSameId() async throws {
        let ticket = Ticket(id: "t-1", title: "Create me")
        let created = try await repo.createTicket(ticket)
        XCTAssertEqual(created.id, "t-1")
    }

    func testCreatePersistsTicket() async throws {
        let ticket = Ticket(title: "Persist test")
        try await repo.createTicket(ticket)
        let all = try await repo.fetchTickets()
        XCTAssertTrue(all.contains { $0.id == ticket.id })
    }

    func testCreatePreservesAllFields() async throws {
        let ticket = Ticket(
            id: "full-t",
            title: "Full ticket",
            description: "A detailed description",
            status: "in-progress",
            priority: .high,
            assignee: "alice",
            labels: ["backend", "critical"],
            storyPoints: 5,
            epicId: "epic-1"
        )
        try await repo.createTicket(ticket)
        let all = try await repo.fetchTickets()
        let fetched = try XCTUnwrap(all.first { $0.id == "full-t" })
        XCTAssertEqual(fetched.title, "Full ticket")
        XCTAssertEqual(fetched.description, "A detailed description")
        XCTAssertEqual(fetched.status, "in-progress")
        XCTAssertEqual(fetched.priority, .high)
        XCTAssertEqual(fetched.assignee, "alice")
        XCTAssertEqual(fetched.labels, ["backend", "critical"])
        XCTAssertEqual(fetched.storyPoints, 5)
        XCTAssertEqual(fetched.epicId, "epic-1")
    }

    func testCreateMultipleTickets() async throws {
        try await repo.createTicket(Ticket(title: "A"))
        try await repo.createTicket(Ticket(title: "B"))
        try await repo.createTicket(Ticket(title: "C"))
        let all = try await repo.fetchTickets()
        XCTAssertEqual(all.count, 3)
    }

    func testCreateWithNilOptionals() async throws {
        let ticket = Ticket(title: "No optionals")
        // dueDate, assignee, epicId are nil
        try await repo.createTicket(ticket)
        let all = try await repo.fetchTickets()
        let fetched = try XCTUnwrap(all.first { $0.id == ticket.id })
        XCTAssertNil(fetched.assignee)
        XCTAssertNil(fetched.epicId)
        XCTAssertNil(fetched.storyPoints)
    }

    func testCreateWithEmptyLabels() async throws {
        let ticket = Ticket(title: "No labels", labels: [])
        try await repo.createTicket(ticket)
        let all = try await repo.fetchTickets()
        let fetched = try XCTUnwrap(all.first { $0.id == ticket.id })
        XCTAssertTrue(fetched.labels.isEmpty)
    }

    // MARK: - Fetch ordering

    func testFetchOrderedByCreatedAtDescending() async throws {
        let older = Ticket(title: "Older", createdAt: Date(timeIntervalSinceNow: -200), updatedAt: Date(timeIntervalSinceNow: -200))
        let newer = Ticket(title: "Newer", createdAt: Date(timeIntervalSinceNow: -10), updatedAt: Date(timeIntervalSinceNow: -10))
        try await repo.createTicket(older)
        try await repo.createTicket(newer)
        let all = try await repo.fetchTickets()
        XCTAssertEqual(all.first?.title, "Newer")
    }

    // MARK: - Update

    func testUpdateChangesTitle() async throws {
        var ticket = Ticket(id: "u-1", title: "Original")
        try await repo.createTicket(ticket)
        ticket.title = "Updated"
        let result = try await repo.updateTicket(ticket)
        XCTAssertEqual(result.title, "Updated")
    }

    func testUpdateChangesPriority() async throws {
        var ticket = Ticket(id: "u-2", title: "T2", priority: .low)
        try await repo.createTicket(ticket)
        ticket.priority = .critical
        try await repo.updateTicket(ticket)
        let all = try await repo.fetchTickets()
        XCTAssertEqual(all.first { $0.id == "u-2" }?.priority, .critical)
    }

    func testUpdateChangesStatus() async throws {
        var ticket = Ticket(id: "u-3", title: "T3", status: "backlog")
        try await repo.createTicket(ticket)
        ticket.status = "done"
        let result = try await repo.updateTicket(ticket)
        XCTAssertEqual(result.status, "done")
    }

    func testUpdateChangesAssignee() async throws {
        var ticket = Ticket(id: "u-4", title: "T4")
        try await repo.createTicket(ticket)
        ticket.assignee = "bob"
        try await repo.updateTicket(ticket)
        let all = try await repo.fetchTickets()
        XCTAssertEqual(all.first { $0.id == "u-4" }?.assignee, "bob")
    }

    func testUpdateChangesLabels() async throws {
        var ticket = Ticket(id: "u-5", title: "T5", labels: ["old"])
        try await repo.createTicket(ticket)
        ticket.labels = ["new1", "new2"]
        try await repo.updateTicket(ticket)
        let all = try await repo.fetchTickets()
        XCTAssertEqual(all.first { $0.id == "u-5" }?.labels, ["new1", "new2"])
    }

    func testUpdateNonExistentThrowsNotFound() async throws {
        let phantom = Ticket(id: "phantom", title: "Ghost")
        do {
            try await repo.updateTicket(phantom)
            XCTFail("Expected notFound error")
        } catch TicketServiceError.notFound {
            // expected
        }
    }

    func testUpdateReturnsSameId() async throws {
        var ticket = Ticket(id: "u-6", title: "Same ID")
        try await repo.createTicket(ticket)
        ticket.title = "Changed"
        let result = try await repo.updateTicket(ticket)
        XCTAssertEqual(result.id, "u-6")
    }

    // MARK: - Delete

    func testDeleteRemovesTicket() async throws {
        let ticket = Ticket(id: "d-1", title: "Delete me")
        try await repo.createTicket(ticket)
        try await repo.deleteTicket(id: "d-1")
        let all = try await repo.fetchTickets()
        XCTAssertFalse(all.contains { $0.id == "d-1" })
    }

    func testDeleteReducesCount() async throws {
        let t1 = Ticket(id: "keep-1", title: "Keep")
        let t2 = Ticket(id: "del-1", title: "Delete")
        try await repo.createTicket(t1)
        try await repo.createTicket(t2)
        try await repo.deleteTicket(id: "del-1")
        let all = try await repo.fetchTickets()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, "keep-1")
    }

    func testDeleteNonExistentThrowsNotFound() async throws {
        do {
            try await repo.deleteTicket(id: "does-not-exist")
            XCTFail("Expected notFound error")
        } catch TicketServiceError.notFound {
            // expected
        }
    }

    // MARK: - MoveTicket

    func testMoveTicketChangesStatus() async throws {
        let ticket = Ticket(id: "m-1", title: "Move me", status: "backlog")
        try await repo.createTicket(ticket)
        let moved = try await repo.moveTicket(id: "m-1", toStatus: "in-progress")
        XCTAssertEqual(moved.status, "in-progress")
        XCTAssertEqual(moved.id, "m-1")
    }

    func testMoveTicketNonExistentThrowsNotFound() async throws {
        do {
            try await repo.moveTicket(id: "no-ticket", toStatus: "done")
            XCTFail("Expected notFound error")
        } catch TicketServiceError.notFound {
            // expected
        }
    }

    func testMoveTicketPreservesOtherFields() async throws {
        let ticket = Ticket(id: "m-2", title: "Preserve me", priority: .high, assignee: "carol")
        try await repo.createTicket(ticket)
        let moved = try await repo.moveTicket(id: "m-2", toStatus: "review")
        XCTAssertEqual(moved.title, "Preserve me")
        XCTAssertEqual(moved.priority, .high)
        XCTAssertEqual(moved.assignee, "carol")
    }

    func testMoveTicketIsPersisted() async throws {
        let ticket = Ticket(id: "m-3", title: "Persist move", status: "backlog")
        try await repo.createTicket(ticket)
        try await repo.moveTicket(id: "m-3", toStatus: "done")
        let all = try await repo.fetchTickets()
        XCTAssertEqual(all.first { $0.id == "m-3" }?.status, "done")
    }

    // MARK: - Error when not open

    func testOperationsThrowWhenNotOpen() async throws {
        let closedRepo = SQLiteTicketRepository(dbPath: "/tmp/not-opened.sqlite")
        do {
            try await closedRepo.fetchTickets()
            XCTFail("Expected notOpen error")
        } catch SQLiteTicketError.notOpen {
            // expected
        }
    }
}
