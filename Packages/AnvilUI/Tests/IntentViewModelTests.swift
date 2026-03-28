import XCTest
@testable import AnvilUI
import AnvilDomain

@MainActor
final class IntentViewModelTests: XCTestCase {

    // MARK: - Init / Demo Data

    func testInitLoadsDemoTickets() {
        let vm = IntentViewModel()
        XCTAssertGreaterThan(vm.tickets.count, 0, "IntentViewModel must load demo tickets on init")
    }

    func testInitLoadsDemoSubtasks() {
        let vm = IntentViewModel()
        XCTAssertFalse(vm.subtasks.isEmpty, "IntentViewModel must load demo subtasks on init")
    }

    func testInitLoadsDemoComments() {
        let vm = IntentViewModel()
        XCTAssertFalse(vm.comments.isEmpty, "IntentViewModel must load demo comments on init")
    }

    func testInitLoadsDemoRelations() {
        let vm = IntentViewModel()
        XCTAssertFalse(vm.relations.isEmpty, "IntentViewModel must load demo relations on init")
    }

    func testInitSetsBoardColumns() {
        let vm = IntentViewModel()
        XCTAssertFalse(vm.board.columns.isEmpty, "Board must have columns after init")
        XCTAssertTrue(vm.board.columns.contains(where: { $0.status == "backlog" }), "Board must have backlog column")
        XCTAssertTrue(vm.board.columns.contains(where: { $0.status == "done" }), "Board must have done column")
    }

    func testInitSetsCycle() {
        let vm = IntentViewModel()
        XCTAssertFalse(vm.currentCycle.name.isEmpty, "Current cycle must have a name after init")
    }

    // MARK: - createTicket

    func testCreateTicketIncreasesCount() {
        let vm = IntentViewModel()
        let before = vm.tickets.count
        vm.createTicket(title: "New bug fix")
        XCTAssertEqual(vm.tickets.count, before + 1, "createTicket must add exactly one ticket")
    }

    func testCreateTicketSetsTitle() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Fix the login flow")
        let created = vm.tickets.last
        XCTAssertEqual(created?.title, "Fix the login flow", "Created ticket must have the given title")
    }

    func testCreateTicketDefaultsToBacklog() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Default status ticket")
        XCTAssertEqual(vm.tickets.last?.status, "backlog", "createTicket must default status to backlog")
    }

    func testCreateTicketWithCustomStatus() {
        let vm = IntentViewModel()
        vm.createTicket(title: "In progress ticket", status: "in progress")
        XCTAssertEqual(vm.tickets.last?.status, "in progress", "createTicket must respect the given status")
    }

    func testCreateTicketIgnoresEmptyTitle() {
        let vm = IntentViewModel()
        let before = vm.tickets.count
        vm.createTicket(title: "   ")
        XCTAssertEqual(vm.tickets.count, before, "createTicket must ignore whitespace-only title")
    }

    func testCreateTicketIgnoresTrulyEmptyTitle() {
        let vm = IntentViewModel()
        let before = vm.tickets.count
        vm.createTicket(title: "")
        XCTAssertEqual(vm.tickets.count, before, "createTicket must ignore empty title")
    }

    // MARK: - createTicketFull

    func testCreateTicketFullSetsAllFields() {
        let vm = IntentViewModel()
        let due = Date().addingTimeInterval(86400)
        vm.createTicketFull(title: "Full ticket", description: "Details here", status: "todo", priority: .high, assignee: "alice", dueDate: due, storyPoints: 5)
        let t = vm.tickets.last!
        XCTAssertEqual(t.title, "Full ticket")
        XCTAssertEqual(t.description, "Details here")
        XCTAssertEqual(t.status, "todo")
        XCTAssertEqual(t.priority, .high)
        XCTAssertEqual(t.assignee, "alice")
        XCTAssertEqual(t.storyPoints, 5)
    }

    func testCreateTicketFullSelectsNewTicket() {
        let vm = IntentViewModel()
        vm.createTicketFull(title: "Select me")
        XCTAssertNotNil(vm.selectedTicketId, "createTicketFull must select the new ticket")
        XCTAssertEqual(vm.selectedTicket?.title, "Select me")
    }

    // MARK: - deleteTicket

    func testDeleteTicketRemovesIt() {
        let vm = IntentViewModel()
        let ticket = vm.tickets.first!
        vm.deleteTicket(ticket.id)
        XCTAssertFalse(vm.tickets.contains(where: { $0.id == ticket.id }), "deleteTicket must remove the ticket")
    }

    func testDeleteTicketClearsSelection() {
        let vm = IntentViewModel()
        let ticket = vm.tickets.first!
        vm.selectedTicketId = ticket.id
        vm.deleteTicket(ticket.id)
        XCTAssertNil(vm.selectedTicketId, "deleteTicket must clear selectedTicketId when deleted ticket was selected")
    }

    func testDeleteTicketClearsSubtasks() {
        let vm = IntentViewModel()
        // ANV-101 has demo subtasks
        vm.deleteTicket("ANV-101")
        XCTAssertNil(vm.subtasks["ANV-101"], "deleteTicket must clear subtasks for deleted ticket")
    }

    func testDeleteTicketClearsComments() {
        let vm = IntentViewModel()
        vm.deleteTicket("ANV-101")
        XCTAssertNil(vm.comments["ANV-101"], "deleteTicket must clear comments for deleted ticket")
    }

    func testDeleteTicketClearsRelations() {
        let vm = IntentViewModel()
        // ANV-101 blocks ANV-105
        let beforeRelationsForANV101 = vm.relations.filter { $0.sourceId == "ANV-101" || $0.targetId == "ANV-101" }.count
        XCTAssertGreaterThan(beforeRelationsForANV101, 0, "Precondition: ANV-101 must have relations")
        vm.deleteTicket("ANV-101")
        let afterRelations = vm.relations.filter { $0.sourceId == "ANV-101" || $0.targetId == "ANV-101" }
        XCTAssertTrue(afterRelations.isEmpty, "deleteTicket must remove all relations for deleted ticket")
    }

    func testDeleteNonSelectedTicketPreservesSelection() {
        let vm = IntentViewModel()
        vm.selectedTicketId = "ANV-101"
        vm.deleteTicket("ANV-102")
        XCTAssertEqual(vm.selectedTicketId, "ANV-101", "Deleting an unselected ticket must not clear selection")
    }

    // MARK: - updateStatus

    func testUpdateStatusChangesTicketStatus() {
        let vm = IntentViewModel()
        let ticket = vm.tickets.first(where: { $0.id == "ANV-101" })!
        XCTAssertNotEqual(ticket.status, "done")
        vm.updateStatus("ANV-101", status: "done")
        XCTAssertEqual(vm.tickets.first(where: { $0.id == "ANV-101" })?.status, "done",
            "updateStatus must change the ticket's status")
    }

    func testUpdateStatusUpdatesTimestamp() {
        let vm = IntentViewModel()
        let before = vm.tickets.first(where: { $0.id == "ANV-101" })!.updatedAt
        vm.updateStatus("ANV-101", status: "done")
        let after = vm.tickets.first(where: { $0.id == "ANV-101" })!.updatedAt
        XCTAssertGreaterThanOrEqual(after, before, "updateStatus must update the updatedAt timestamp")
    }

    func testUpdateStatusIgnoresUnknownId() {
        let vm = IntentViewModel()
        let before = vm.tickets.count
        vm.updateStatus("NO-SUCH-TICKET", status: "done")
        XCTAssertEqual(vm.tickets.count, before, "updateStatus must ignore unknown ticket ID without crashing")
    }

    // MARK: - moveTicket

    func testMoveTicketChangesStatus() {
        let vm = IntentViewModel()
        vm.moveTicket("ANV-102", toStatus: "in progress")
        XCTAssertEqual(vm.tickets.first(where: { $0.id == "ANV-102" })?.status, "in progress",
            "moveTicket must change ticket status")
    }

    // MARK: - selectTicket

    func testSelectTicketSetsId() {
        let vm = IntentViewModel()
        vm.selectTicket("ANV-103")
        XCTAssertEqual(vm.selectedTicketId, "ANV-103", "selectTicket must set selectedTicketId")
    }

    func testSelectTicketPopulatesEditingFields() {
        let vm = IntentViewModel()
        vm.selectTicket("ANV-101")
        XCTAssertFalse(vm.editingTitle.isEmpty, "selectTicket must populate editingTitle from ticket")
    }

    func testSelectNilClearsSelection() {
        let vm = IntentViewModel()
        vm.selectTicket("ANV-101")
        vm.selectTicket(nil)
        XCTAssertNil(vm.selectedTicketId, "selectTicket(nil) must clear selectedTicketId")
    }

    // MARK: - updateTitle / updateDescription

    func testUpdateTitleChangesTicketTitle() {
        let vm = IntentViewModel()
        vm.selectTicket("ANV-101")
        vm.updateTitle("Completely new title")
        XCTAssertEqual(vm.tickets.first(where: { $0.id == "ANV-101" })?.title, "Completely new title",
            "updateTitle must change the ticket's title")
    }

    func testUpdateDescriptionChangesTicketDescription() {
        let vm = IntentViewModel()
        vm.selectTicket("ANV-101")
        vm.updateDescription("New description text")
        XCTAssertEqual(vm.tickets.first(where: { $0.id == "ANV-101" })?.description, "New description text",
            "updateDescription must update ticket description")
    }

    // MARK: - addSubtask

    func testAddSubtaskIncreasesCount() {
        let vm = IntentViewModel()
        let before = vm.subtasks["ANV-102"]?.count ?? 0
        vm.addSubtask(to: "ANV-102", title: "Write tests")
        XCTAssertEqual(vm.subtasks["ANV-102"]?.count ?? 0, before + 1, "addSubtask must add one subtask")
    }

    func testAddSubtaskSetsTitle() {
        let vm = IntentViewModel()
        vm.addSubtask(to: "ANV-102", title: "Deploy to staging")
        XCTAssertEqual(vm.subtasks["ANV-102"]?.last?.title, "Deploy to staging",
            "addSubtask must store the given title")
    }

    func testAddSubtaskDefaultsToIncomplete() {
        let vm = IntentViewModel()
        vm.addSubtask(to: "ANV-102", title: "New subtask")
        XCTAssertFalse(vm.subtasks["ANV-102"]!.last!.isCompleted,
            "New subtask must default to incomplete")
    }

    func testAddSubtaskIgnoresEmptyTitle() {
        let vm = IntentViewModel()
        let before = vm.subtasks["ANV-102"]?.count ?? 0
        vm.addSubtask(to: "ANV-102", title: "  ")
        XCTAssertEqual(vm.subtasks["ANV-102"]?.count ?? 0, before, "addSubtask must ignore whitespace-only title")
    }

    // MARK: - toggleSubtask

    func testToggleSubtaskFlipsCompletion() {
        let vm = IntentViewModel()
        let subtask = vm.subtasks["ANV-101"]!.first!
        let wasCompleted = subtask.isCompleted
        vm.toggleSubtask(ticketId: "ANV-101", subtaskId: subtask.id)
        XCTAssertEqual(vm.subtasks["ANV-101"]!.first!.isCompleted, !wasCompleted,
            "toggleSubtask must flip the isCompleted flag")
    }

    func testToggleSubtaskTwiceRestoresOriginalState() {
        let vm = IntentViewModel()
        let subtask = vm.subtasks["ANV-101"]!.first!
        let original = subtask.isCompleted
        vm.toggleSubtask(ticketId: "ANV-101", subtaskId: subtask.id)
        vm.toggleSubtask(ticketId: "ANV-101", subtaskId: subtask.id)
        XCTAssertEqual(vm.subtasks["ANV-101"]!.first!.isCompleted, original,
            "Toggling twice must restore original completion state")
    }

    // MARK: - deleteSubtask

    func testDeleteSubtaskRemovesIt() {
        let vm = IntentViewModel()
        let subtask = vm.subtasks["ANV-101"]!.first!
        let before = vm.subtasks["ANV-101"]!.count
        vm.deleteSubtask(ticketId: "ANV-101", subtaskId: subtask.id)
        XCTAssertEqual(vm.subtasks["ANV-101"]?.count, before - 1, "deleteSubtask must remove one subtask")
    }

    // MARK: - subtaskProgress

    func testSubtaskProgressReturnsCorrectCounts() {
        let vm = IntentViewModel()
        // ANV-101 has 4 subtasks: 2 completed, 2 not (from demo data)
        let (completed, total) = vm.subtaskProgress("ANV-101")
        XCTAssertEqual(total, 4, "subtaskProgress total must match subtask count")
        XCTAssertEqual(completed, 2, "subtaskProgress completed must count only completed subtasks")
    }

    func testSubtaskProgressForTicketWithNoSubtasks() {
        let vm = IntentViewModel()
        let (completed, total) = vm.subtaskProgress("ANV-115")
        XCTAssertEqual(completed, 0)
        XCTAssertEqual(total, 0)
    }

    // MARK: - addComment

    func testAddCommentIncreasesCount() {
        let vm = IntentViewModel()
        let before = vm.comments["ANV-102"]?.count ?? 0
        vm.addComment(to: "ANV-102", body: "Looking at this now")
        XCTAssertEqual(vm.comments["ANV-102"]?.count ?? 0, before + 1, "addComment must add one comment")
    }

    func testAddCommentSetsBody() {
        let vm = IntentViewModel()
        vm.addComment(to: "ANV-102", body: "This is my comment")
        XCTAssertEqual(vm.comments["ANV-102"]?.last?.body, "This is my comment",
            "addComment must store the given body")
    }

    func testAddCommentSetsAuthor() {
        let vm = IntentViewModel()
        vm.addComment(to: "ANV-102", author: "bob", body: "LGTM")
        XCTAssertEqual(vm.comments["ANV-102"]?.last?.author, "bob",
            "addComment must store the given author")
    }

    func testAddCommentDefaultsAuthorToYou() {
        let vm = IntentViewModel()
        vm.addComment(to: "ANV-102", body: "Default author")
        XCTAssertEqual(vm.comments["ANV-102"]?.last?.author, "You",
            "addComment must default author to 'You'")
    }

    func testAddCommentIgnoresEmptyBody() {
        let vm = IntentViewModel()
        let before = vm.comments["ANV-102"]?.count ?? 0
        vm.addComment(to: "ANV-102", body: "")
        XCTAssertEqual(vm.comments["ANV-102"]?.count ?? 0, before, "addComment must ignore empty body")
    }

    // MARK: - addRelation / removeRelation

    func testAddRelationIncreasesCount() {
        let vm = IntentViewModel()
        let before = vm.relations.count
        vm.addRelation(type: .related, sourceId: "ANV-106", targetId: "ANV-109")
        XCTAssertEqual(vm.relations.count, before + 1, "addRelation must add one relation")
    }

    func testAddRelationIgnoresSelfRelation() {
        let vm = IntentViewModel()
        let before = vm.relations.count
        vm.addRelation(type: .related, sourceId: "ANV-106", targetId: "ANV-106")
        XCTAssertEqual(vm.relations.count, before, "addRelation must not allow self-relations")
    }

    func testAddRelationIgnoresDuplicates() {
        let vm = IntentViewModel()
        vm.addRelation(type: .related, sourceId: "ANV-106", targetId: "ANV-109")
        let after = vm.relations.count
        vm.addRelation(type: .related, sourceId: "ANV-106", targetId: "ANV-109")
        XCTAssertEqual(vm.relations.count, after, "addRelation must not add duplicate relations")
    }

    func testRemoveRelationDecreasesCount() {
        let vm = IntentViewModel()
        let relation = vm.relations.first!
        let before = vm.relations.count
        vm.removeRelation(id: relation.id)
        XCTAssertEqual(vm.relations.count, before - 1, "removeRelation must remove one relation")
    }

    func testRelationsForReturnsCorrectSubset() {
        let vm = IntentViewModel()
        let relations = vm.relationsFor("ANV-101")
        XCTAssertTrue(relations.allSatisfy { $0.sourceId == "ANV-101" || $0.targetId == "ANV-101" },
            "relationsFor must only return relations involving that ticket")
    }

    // MARK: - Filters

    func testFilterByPriorityNarrowsResults() {
        let vm = IntentViewModel()
        vm.filterPriority = .critical
        let filtered = vm.filteredTickets
        XCTAssertTrue(filtered.allSatisfy { $0.priority == .critical },
            "Filter by critical priority must return only critical tickets")
    }

    func testFilterByStatusNarrowsResults() {
        let vm = IntentViewModel()
        vm.filterStatus = "done"
        let filtered = vm.filteredTickets
        XCTAssertTrue(filtered.allSatisfy { $0.status == "done" },
            "Filter by status must return only matching tickets")
    }

    func testSearchTextFiltersTickets() {
        let vm = IntentViewModel()
        vm.searchText = "auth"
        let filtered = vm.filteredTickets
        XCTAssertGreaterThan(filtered.count, 0, "Search 'auth' must return results")
        XCTAssertLessThan(filtered.count, vm.tickets.count, "Search must narrow the results")
        XCTAssertTrue(filtered.allSatisfy {
            $0.title.lowercased().contains("auth") ||
            $0.description.lowercased().contains("auth") ||
            $0.id.lowercased().contains("auth")
        }, "All search results must contain the search term")
    }

    func testClearFiltersResetsAll() {
        let vm = IntentViewModel()
        vm.filterPriority = .critical
        vm.filterStatus = "done"
        vm.searchText = "bug"
        vm.clearFilters()
        XCTAssertNil(vm.filterPriority, "clearFilters must nil out filterPriority")
        XCTAssertNil(vm.filterStatus, "clearFilters must nil out filterStatus")
        XCTAssertTrue(vm.searchText.isEmpty, "clearFilters must clear searchText")
        XCTAssertEqual(vm.filteredTickets.count, vm.tickets.count, "After clearing filters, all tickets must be visible")
    }

    // MARK: - Sort

    func testSortByTitleProducesAlphabeticalOrder() {
        let vm = IntentViewModel()
        vm.sortField = .title
        let titles = vm.filteredTickets.map(\.title)
        XCTAssertEqual(titles, titles.sorted(by: { $0.localizedCompare($1) == .orderedAscending }),
            "Sort by title must produce alphabetical order")
    }

    // MARK: - groupedTickets

    func testGroupedTicketsByStatusHasAtLeastOneGroup() {
        let vm = IntentViewModel()
        vm.grouping = .status
        XCTAssertGreaterThan(vm.groupedTickets.count, 0, "Grouping by status must produce at least one group")
    }

    func testGroupedTicketsByPriorityHasAtLeastOneGroup() {
        let vm = IntentViewModel()
        vm.grouping = .priority
        XCTAssertGreaterThan(vm.groupedTickets.count, 0, "Grouping by priority must produce at least one group")
    }

    // MARK: - Static helpers

    func testPriorityLabelCritical() {
        XCTAssertEqual(IntentViewModel.priorityLabel(.critical), "P0 - Critical")
    }

    func testPriorityLabelMedium() {
        XCTAssertEqual(IntentViewModel.priorityLabel(.medium), "P2 - Medium")
    }

    func testStatusIconForKnownStatuses() {
        XCTAssertFalse(IntentViewModel.statusIcon("backlog").isEmpty)
        XCTAssertFalse(IntentViewModel.statusIcon("done").isEmpty)
        XCTAssertFalse(IntentViewModel.statusIcon("in progress").isEmpty)
    }
}
