import XCTest
@testable import AnvilDomain

final class TicketXCTests: XCTestCase {

    // MARK: - Default values

    func testDefaultStatusIsOpen() {
        let t = Ticket(title: "Test")
        XCTAssertEqual(t.status, "open")
    }

    func testDefaultPriorityIsMedium() {
        let t = Ticket(title: "Test")
        XCTAssertEqual(t.priority, .medium)
    }

    func testDefaultDescriptionIsEmpty() {
        let t = Ticket(title: "Test")
        XCTAssertTrue(t.description.isEmpty)
    }

    func testDefaultLabelsIsEmpty() {
        let t = Ticket(title: "Test")
        XCTAssertTrue(t.labels.isEmpty)
    }

    func testDefaultAssigneeIsNil() {
        let t = Ticket(title: "Test")
        XCTAssertNil(t.assignee)
    }

    func testDefaultStoryPointsIsNil() {
        let t = Ticket(title: "Test")
        XCTAssertNil(t.storyPoints)
    }

    func testDefaultEpicIdIsNil() {
        let t = Ticket(title: "Test")
        XCTAssertNil(t.epicId)
    }

    func testDefaultDueDateIsNil() {
        let t = Ticket(title: "Test")
        XCTAssertNil(t.dueDate)
    }

    func testIdIsNonEmptyByDefault() {
        let t = Ticket(title: "Test")
        XCTAssertFalse(t.id.isEmpty)
    }

    // MARK: - Custom field storage

    func testCustomIdIsStored() {
        let t = Ticket(id: "custom-id", title: "T")
        XCTAssertEqual(t.id, "custom-id")
    }

    func testTitleIsStored() {
        let t = Ticket(title: "Fix auth bug")
        XCTAssertEqual(t.title, "Fix auth bug")
    }

    func testDescriptionIsStored() {
        let t = Ticket(title: "T", description: "Details here")
        XCTAssertEqual(t.description, "Details here")
    }

    func testStatusIsStored() {
        let t = Ticket(title: "T", status: "in-progress")
        XCTAssertEqual(t.status, "in-progress")
    }

    func testPriorityIsStored() {
        let t = Ticket(title: "T", priority: .critical)
        XCTAssertEqual(t.priority, .critical)
    }

    func testAssigneeIsStored() {
        let t = Ticket(title: "T", assignee: "alice")
        XCTAssertEqual(t.assignee, "alice")
    }

    func testLabelsAreStored() {
        let t = Ticket(title: "T", labels: ["bug", "p1"])
        XCTAssertEqual(t.labels, ["bug", "p1"])
    }

    func testStoryPointsAreStored() {
        let t = Ticket(title: "T", storyPoints: 8)
        XCTAssertEqual(t.storyPoints, 8)
    }

    func testEpicIdIsStored() {
        let t = Ticket(title: "T", epicId: "epic-42")
        XCTAssertEqual(t.epicId, "epic-42")
    }

    func testDueDateIsStored() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let t = Ticket(title: "T", dueDate: date)
        XCTAssertEqual(t.dueDate, date)
    }

    // MARK: - Value semantics (struct copy)

    func testMutatingCopyDoesNotAffectOriginal() {
        let original = Ticket(title: "Original", status: "open")
        var copy = original
        copy.status = "done"
        XCTAssertEqual(original.status, "open")
        XCTAssertEqual(copy.status, "done")
    }

    func testMutatingTitleCopyLeaveOriginalUnchanged() {
        let original = Ticket(title: "Before")
        var copy = original
        copy.title = "After"
        XCTAssertEqual(original.title, "Before")
    }

    func testIdIsImmutable() {
        // id is `let` — this test verifies the copy shares the same id
        let original = Ticket(id: "fixed-id", title: "T")
        let copy = original
        XCTAssertEqual(copy.id, "fixed-id")
    }

    // MARK: - Unique id generation

    func testTwoDefaultTicketsHaveDifferentIds() {
        let t1 = Ticket(title: "A")
        let t2 = Ticket(title: "B")
        XCTAssertNotEqual(t1.id, t2.id)
    }

    // MARK: - Status transitions (value semantics)

    func testStatusCanBeChangedToInProgress() {
        var t = Ticket(title: "T", status: "backlog")
        t.status = "in-progress"
        XCTAssertEqual(t.status, "in-progress")
    }

    func testStatusCanBeChangedToDone() {
        var t = Ticket(title: "T", status: "in-progress")
        t.status = "done"
        XCTAssertEqual(t.status, "done")
    }

    func testAllStatusTransitionsAreValid() {
        let statuses = ["backlog", "open", "in-progress", "review", "done", "cancelled"]
        for status in statuses {
            var t = Ticket(title: "T")
            t.status = status
            XCTAssertEqual(t.status, status)
        }
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = Ticket(
            id: "rt-1",
            title: "Round trip",
            description: "desc",
            status: "open",
            priority: .high,
            assignee: "bob",
            labels: ["alpha"],
            storyPoints: 3,
            epicId: "epic-7"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Ticket.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.priority, original.priority)
        XCTAssertEqual(decoded.assignee, original.assignee)
        XCTAssertEqual(decoded.labels, original.labels)
        XCTAssertEqual(decoded.storyPoints, original.storyPoints)
        XCTAssertEqual(decoded.epicId, original.epicId)
    }

    func testCodableWithNilOptionals() throws {
        let original = Ticket(title: "Nil opts")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Ticket.self, from: data)
        XCTAssertNil(decoded.assignee)
        XCTAssertNil(decoded.epicId)
        XCTAssertNil(decoded.storyPoints)
        XCTAssertNil(decoded.dueDate)
    }

    // MARK: - TicketPriority ordering

    func testCriticalLessThanHigh() {
        XCTAssertLessThan(TicketPriority.critical, .high)
    }

    func testHighLessThanMedium() {
        XCTAssertLessThan(TicketPriority.high, .medium)
    }

    func testMediumLessThanLow() {
        XCTAssertLessThan(TicketPriority.medium, .low)
    }

    func testLowLessThanNone() {
        XCTAssertLessThan(TicketPriority.low, .none)
    }

    func testPriorityIsNotLessThanItself() {
        XCTAssertFalse(TicketPriority.medium < .medium)
    }

    func testPriorityRawValues() {
        XCTAssertEqual(TicketPriority.critical.rawValue, 0)
        XCTAssertEqual(TicketPriority.high.rawValue, 1)
        XCTAssertEqual(TicketPriority.medium.rawValue, 2)
        XCTAssertEqual(TicketPriority.low.rawValue, 3)
        XCTAssertEqual(TicketPriority.none.rawValue, 4)
    }

    func testPriorityCodableRoundTrip() throws {
        for priority in [TicketPriority.critical, .high, .medium, .low, .none] {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(TicketPriority.self, from: data)
            XCTAssertEqual(decoded, priority)
        }
    }

    // MARK: - TicketDraft

    func testTicketDraftStoresAllFields() {
        let draft = TicketDraft(
            title: "Draft",
            description: "body",
            priority: .low,
            labels: ["qa"],
            assignee: "carol",
            epicId: "epic-3"
        )
        XCTAssertEqual(draft.title, "Draft")
        XCTAssertEqual(draft.description, "body")
        XCTAssertEqual(draft.priority, .low)
        XCTAssertEqual(draft.labels, ["qa"])
        XCTAssertEqual(draft.assignee, "carol")
        XCTAssertEqual(draft.epicId, "epic-3")
    }

    func testTicketDraftDefaultsAreEmpty() {
        let draft = TicketDraft(title: "Minimal")
        XCTAssertTrue(draft.description.isEmpty)
        XCTAssertEqual(draft.priority, .medium)
        XCTAssertTrue(draft.labels.isEmpty)
        XCTAssertNil(draft.assignee)
        XCTAssertNil(draft.epicId)
    }

    // MARK: - TicketUpdate

    func testTicketUpdateDefaultsAllNil() {
        let update = TicketUpdate()
        XCTAssertNil(update.title)
        XCTAssertNil(update.status)
        XCTAssertNil(update.priority)
        XCTAssertNil(update.assignee)
        XCTAssertNil(update.labels)
        XCTAssertNil(update.storyPoints)
    }

    func testTicketUpdateWithValues() {
        let update = TicketUpdate(title: "New", status: "done", priority: .critical, storyPoints: 13)
        XCTAssertEqual(update.title, "New")
        XCTAssertEqual(update.status, "done")
        XCTAssertEqual(update.priority, .critical)
        XCTAssertEqual(update.storyPoints, 13)
    }

    // MARK: - TicketFilter

    func testTicketFilterStoresCriteria() {
        let filter = TicketFilter(status: "open", priority: .high, assignee: "alice", labels: ["bug"])
        XCTAssertEqual(filter.status, "open")
        XCTAssertEqual(filter.priority, .high)
        XCTAssertEqual(filter.assignee, "alice")
        XCTAssertEqual(filter.labels, ["bug"])
    }

    func testTicketFilterDefaultsAllNil() {
        let filter = TicketFilter()
        XCTAssertNil(filter.status)
        XCTAssertNil(filter.priority)
        XCTAssertNil(filter.assignee)
        XCTAssertNil(filter.labels)
        XCTAssertNil(filter.epicId)
    }
}
