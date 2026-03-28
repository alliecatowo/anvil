import Testing
import XCTest
import Foundation
import AnvilDomain
@testable import AnvilUI

// MARK: - Existing XCTest suite (preserved for CI compatibility)

final class AnvilUITests: XCTestCase {
    @MainActor
    func testAppStateSpaceSwitching() {
        let state = AppState()
        state.switchSpace(.review)
        XCTAssertEqual(state.currentSpace, .review)
    }

    func testAllSpacesHaveIcons() {
        for space in AnvilSpace.allCases {
            XCTAssertFalse(space.icon.isEmpty)
        }
    }
}

// MARK: - AppState + Space Switching

@Suite("AppState — Space Switching")
struct AppStateSpaceTests {

    @Test("switchSpace updates currentSpace")
    @MainActor
    func switchingSpacesUpdatesCurrentSpace() {
        let state = AppState()
        state.switchSpace(.review)
        #expect(state.currentSpace == .review)
        #expect(state.lastSpace == .review)
    }

    @Test("switchSpace cycles through all values")
    @MainActor
    func switchSpaceCyclesThroughAllValues() {
        let state = AppState()
        for space in AnvilSpace.allCases {
            state.switchSpace(space)
            #expect(state.currentSpace == space)
        }
    }

    @Test("all spaces have distinct icons")
    func allSpacesHaveDistinctIcons() {
        let icons = AnvilSpace.allCases.map(\.icon)
        #expect(Set(icons).count == AnvilSpace.allCases.count)
    }

    @Test("all space icons are non-empty")
    func allSpaceIconsAreNonEmpty() {
        for space in AnvilSpace.allCases {
            #expect(!space.icon.isEmpty, "Expected non-empty icon for space \(space.rawValue)")
        }
    }

    @Test("space shortcuts are numbered 1 through 5")
    func spaceShortcutsAreNumbered1Through5() {
        let shortcuts = AnvilSpace.allCases.compactMap(\.shortcutNumber)
        #expect(shortcuts.sorted() == [1, 2, 3, 4, 5])
    }

    @Test("every space has a shortcut number")
    func everySpaceHasAShortcutNumber() {
        for space in AnvilSpace.allCases {
            #expect(space.shortcutNumber != nil, "Expected shortcut for \(space.rawValue)")
        }
    }

    @Test("default space is build")
    @MainActor
    func defaultSpaceIsBuild() {
        let state = AppState()
        #expect(state.currentSpace == .build)
    }
}

// MARK: - AppState — Toggle helpers

@Suite("AppState — Toggle Helpers")
struct AppStateToggleTests {

    @Test("toggleSidebar flips isSidebarCollapsed when sidebar is visible")
    @MainActor
    func toggleSidebarCollapsesWhenVisible() {
        let state = AppState()
        state.isSidebarVisible = true
        state.isSidebarCollapsed = false
        state.toggleSidebar()
        #expect(state.isSidebarCollapsed == true)
    }

    @Test("toggleSidebar expands sidebar when already collapsed")
    @MainActor
    func toggleSidebarExpandsWhenCollapsed() {
        let state = AppState()
        state.isSidebarVisible = true
        state.isSidebarCollapsed = true
        state.toggleSidebar()
        #expect(state.isSidebarCollapsed == false)
    }

    @Test("toggleInspector flips isInspectorVisible")
    @MainActor
    func toggleInspectorFlipsVisibility() {
        let state = AppState()
        #expect(state.isInspectorVisible == false)
        state.toggleInspector()
        #expect(state.isInspectorVisible == true)
        state.toggleInspector()
        #expect(state.isInspectorVisible == false)
    }

    @Test("toggleCommandPalette flips isCommandPaletteVisible")
    @MainActor
    func toggleCommandPaletteFlipsVisibility() {
        let state = AppState()
        #expect(state.isCommandPaletteVisible == false)
        state.toggleCommandPalette()
        #expect(state.isCommandPaletteVisible == true)
        state.toggleCommandPalette()
        #expect(state.isCommandPaletteVisible == false)
    }

    @Test("toggleProjectSearch flips isProjectSearchVisible")
    @MainActor
    func toggleProjectSearchFlipsVisibility() {
        let state = AppState()
        #expect(state.isProjectSearchVisible == false)
        state.toggleProjectSearch()
        #expect(state.isProjectSearchVisible == true)
    }

    @Test("toggleSourceControl flips isSourceControlVisible")
    @MainActor
    func toggleSourceControlFlipsVisibility() {
        let state = AppState()
        #expect(state.isSourceControlVisible == false)
        state.toggleSourceControl()
        #expect(state.isSourceControlVisible == true)
    }
}

// MARK: - AgentViewModel

@Suite("AgentViewModel — Session Lifecycle")
struct AgentViewModelSessionTests {

    @Test("startNewSession creates a session and prepends it")
    @MainActor
    func startNewSessionCreatesSession() {
        let vm = AgentViewModel()
        #expect(vm.sessions.isEmpty)
        vm.startNewSession(prompt: "Fix the auth bug", model: "claude-sonnet-4-6")
        #expect(vm.sessions.count == 1)
        #expect(vm.sessions[0].model == "claude-sonnet-4-6")
    }

    @Test("startNewSession inserts at front of list")
    @MainActor
    func startNewSessionInsertsAtFront() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "First task", model: "claude-sonnet-4-6")
        let firstId = vm.sessions[0].id
        vm.startNewSession(prompt: "Second task", model: "claude-opus-4-5")
        #expect(vm.sessions.count == 2)
        #expect(vm.sessions[0].model == "claude-opus-4-5")
        #expect(vm.sessions[1].id == firstId)
    }

    @Test("startNewSession sets selectedSessionId to new session")
    @MainActor
    func startNewSessionSelectsNewSession() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "Test prompt", model: "claude-sonnet-4-6")
        let newId = vm.sessions[0].id
        #expect(vm.selectedSessionId == newId)
    }

    @Test("startNewSession updates selectedModelId")
    @MainActor
    func startNewSessionUpdatesSelectedModel() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "Test", model: "claude-opus-4-5")
        #expect(vm.selectedModelId == "claude-opus-4-5")
    }

    @Test("deleteSession removes session from array")
    @MainActor
    func deleteSessionRemovesFromArray() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "Task A", model: "claude-sonnet-4-6")
        vm.startNewSession(prompt: "Task B", model: "claude-sonnet-4-6")
        let idToDelete = vm.sessions[1].id
        vm.deleteSession(idToDelete)
        #expect(vm.sessions.count == 1)
        #expect(!vm.sessions.contains(where: { $0.id == idToDelete }))
    }

    @Test("deleteSession clears selectedSessionId when selected session is deleted")
    @MainActor
    func deleteSessionClearsSelectionWhenDeleted() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "Only session", model: "claude-sonnet-4-6")
        let id = vm.sessions[0].id
        #expect(vm.selectedSessionId == id)
        vm.deleteSession(id)
        #expect(vm.sessions.isEmpty)
        #expect(vm.selectedSessionId == nil)
    }

    @Test("deleteSession falls back to first remaining session")
    @MainActor
    func deleteSessionFallsBackToFirstRemaining() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "First", model: "claude-sonnet-4-6")
        vm.startNewSession(prompt: "Second", model: "claude-sonnet-4-6")
        let secondId = vm.sessions[0].id  // most recent is at front
        let firstId = vm.sessions[1].id
        vm.selectedSessionId = secondId
        vm.deleteSession(secondId)
        #expect(vm.selectedSessionId == firstId)
    }

    @Test("selectedSessionId updates on session selection")
    @MainActor
    func selectedSessionIdUpdatesOnSelection() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "Alpha", model: "claude-sonnet-4-6")
        vm.startNewSession(prompt: "Beta", model: "claude-sonnet-4-6")
        let alphaId = vm.sessions[1].id
        vm.selectedSessionId = alphaId
        #expect(vm.selectedSessionId == alphaId)
        #expect(vm.selectedSession?.id == alphaId)
    }

    @Test("selectedSession is nil when selectedSessionId is nil")
    @MainActor
    func selectedSessionIsNilWhenNoSelection() {
        let vm = AgentViewModel()
        vm.selectedSessionId = nil
        #expect(vm.selectedSession == nil)
    }

    @Test("selectedSession is nil when selectedSessionId does not match any session")
    @MainActor
    func selectedSessionIsNilForUnknownId() {
        let vm = AgentViewModel()
        vm.selectedSessionId = "nonexistent-id"
        #expect(vm.selectedSession == nil)
    }

    @Test("renameSession updates custom name")
    @MainActor
    func renameSessionUpdatesCustomName() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "Fix bug", model: "claude-sonnet-4-6")
        let id = vm.sessions[0].id
        vm.renameSession(id, name: "Auth Bug Fix")
        #expect(vm.sessions[0].customName == "Auth Bug Fix")
    }

    @Test("renameSession does nothing for unknown id")
    @MainActor
    func renameSessionIgnoresUnknownId() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "Work", model: "claude-sonnet-4-6")
        let countBefore = vm.sessions.count
        vm.renameSession("ghost-id", name: "Ghost")
        #expect(vm.sessions.count == countBefore)
    }
}

// MARK: - IntentViewModel

@Suite("IntentViewModel — Ticket CRUD")
struct IntentViewModelTicketTests {

    @Test("createTicket adds ticket with specified status")
    @MainActor
    func createTicketAddsTicketToCorrectStatus() {
        let vm = IntentViewModel()
        let countBefore = vm.tickets.count
        vm.createTicket(title: "New feature request", status: "todo")
        #expect(vm.tickets.count == countBefore + 1)
        let added = vm.tickets.last!
        #expect(added.title == "New feature request")
        #expect(added.status == "todo")
    }

    @Test("createTicket defaults to backlog when no status given")
    @MainActor
    func createTicketDefaultsToBacklog() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Unplanned item")
        let added = vm.tickets.last!
        #expect(added.status == "backlog")
    }

    @Test("createTicket ignores blank titles")
    @MainActor
    func createTicketIgnoresBlankTitle() {
        let vm = IntentViewModel()
        let countBefore = vm.tickets.count
        vm.createTicket(title: "   ")
        #expect(vm.tickets.count == countBefore)
    }

    @Test("createTicket trims whitespace from title")
    @MainActor
    func createTicketTrimsTitleWhitespace() {
        let vm = IntentViewModel()
        vm.createTicket(title: "  Trimmed Title  ")
        let added = vm.tickets.last!
        #expect(added.title == "Trimmed Title")
    }

    @Test("moveTicket changes ticket status")
    @MainActor
    func moveTicketChangesStatus() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Movable ticket", status: "backlog")
        let id = vm.tickets.last!.id
        vm.moveTicket(id, toStatus: "in progress")
        let updated = vm.tickets.first(where: { $0.id == id })!
        #expect(updated.status == "in progress")
    }

    @Test("moveTicket does nothing for unknown ticket id")
    @MainActor
    func moveTicketIgnoresUnknownId() {
        let vm = IntentViewModel()
        let countBefore = vm.tickets.count
        vm.moveTicket("ghost-id", toStatus: "done")
        #expect(vm.tickets.count == countBefore)
    }

    @Test("deleteTicket removes ticket from array")
    @MainActor
    func deleteTicketRemovesFromArray() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Ticket to delete", status: "todo")
        let id = vm.tickets.last!.id
        let countBefore = vm.tickets.count
        vm.deleteTicket(id)
        #expect(vm.tickets.count == countBefore - 1)
        #expect(!vm.tickets.contains(where: { $0.id == id }))
    }

    @Test("deleteTicket clears selectedTicketId when deleting selected ticket")
    @MainActor
    func deleteTicketClearsSelection() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Selected ticket", status: "todo")
        let id = vm.tickets.last!.id
        vm.selectTicket(id)
        #expect(vm.selectedTicketId == id)
        vm.deleteTicket(id)
        #expect(vm.selectedTicketId == nil)
    }

    @Test("deleteTicket also removes associated subtasks and comments")
    @MainActor
    func deleteTicketCleansUpSubtasksAndComments() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Parent ticket", status: "todo")
        let id = vm.tickets.last!.id
        vm.addSubtask(to: id, title: "Subtask one")
        vm.addComment(to: id, body: "A comment here")
        vm.deleteTicket(id)
        #expect(vm.subtasks[id] == nil)
        #expect(vm.comments[id] == nil)
    }
}

@Suite("IntentViewModel — Subtask Progress")
struct IntentViewModelSubtaskTests {

    @Test("subtaskProgress returns correct ratio")
    @MainActor
    func subtaskProgressReturnsCorrectRatio() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Sprint ticket", status: "in progress")
        let id = vm.tickets.last!.id
        vm.addSubtask(to: id, title: "Step 1")
        vm.addSubtask(to: id, title: "Step 2")
        vm.addSubtask(to: id, title: "Step 3")
        // Complete the first two subtasks
        let firstSubtaskId = vm.subtasksFor(id)[0].id
        let secondSubtaskId = vm.subtasksFor(id)[1].id
        vm.toggleSubtask(ticketId: id, subtaskId: firstSubtaskId)
        vm.toggleSubtask(ticketId: id, subtaskId: secondSubtaskId)
        let progress = vm.subtaskProgress(id)
        #expect(progress.completed == 2)
        #expect(progress.total == 3)
    }

    @Test("subtaskProgress returns zero for ticket with no subtasks")
    @MainActor
    func subtaskProgressZeroWhenNoSubtasks() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Empty ticket")
        let id = vm.tickets.last!.id
        let progress = vm.subtaskProgress(id)
        #expect(progress.completed == 0)
        #expect(progress.total == 0)
    }

    @Test("subtaskProgress returns zero for unknown ticket id")
    @MainActor
    func subtaskProgressZeroForUnknownTicket() {
        let vm = IntentViewModel()
        let progress = vm.subtaskProgress("nonexistent")
        #expect(progress.completed == 0)
        #expect(progress.total == 0)
    }

    @Test("addSubtask appends subtask to correct ticket")
    @MainActor
    func addSubtaskAppendsToCorrectTicket() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Ticket A")
        vm.createTicket(title: "Ticket B")
        let idA = vm.tickets[vm.tickets.count - 2].id
        let idB = vm.tickets.last!.id
        vm.addSubtask(to: idA, title: "A-subtask")
        vm.addSubtask(to: idB, title: "B-subtask")
        #expect(vm.subtasksFor(idA).count == 1)
        #expect(vm.subtasksFor(idB).count == 1)
        #expect(vm.subtasksFor(idA)[0].title == "A-subtask")
    }

    @Test("toggleSubtask flips completion state")
    @MainActor
    func toggleSubtaskFlipsCompletion() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Toggle test")
        let id = vm.tickets.last!.id
        vm.addSubtask(to: id, title: "Do thing")
        let subtaskId = vm.subtasksFor(id)[0].id
        #expect(vm.subtasksFor(id)[0].isCompleted == false)
        vm.toggleSubtask(ticketId: id, subtaskId: subtaskId)
        #expect(vm.subtasksFor(id)[0].isCompleted == true)
        vm.toggleSubtask(ticketId: id, subtaskId: subtaskId)
        #expect(vm.subtasksFor(id)[0].isCompleted == false)
    }
}

@Suite("IntentViewModel — Filtering and Search")
struct IntentViewModelFilterTests {

    @Test("filteredTickets returns all tickets when no filters active")
    @MainActor
    func filteredTicketsReturnsAllByDefault() {
        let vm = IntentViewModel()
        #expect(vm.filteredTickets.count == vm.tickets.count)
    }

    @Test("filterStatus narrows results to matching status")
    @MainActor
    func filterStatusNarrowsResults() {
        let vm = IntentViewModel()
        vm.filterStatus = "done"
        let results = vm.filteredTickets
        #expect(results.allSatisfy { $0.status == "done" })
    }

    @Test("searchText filters by title")
    @MainActor
    func searchTextFiltersByTitle() {
        let vm = IntentViewModel()
        vm.createTicket(title: "Unique searchable title XYZ", status: "backlog")
        vm.searchText = "Unique searchable title XYZ"
        #expect(vm.filteredTickets.count >= 1)
        #expect(vm.filteredTickets.allSatisfy { $0.title.localizedCaseInsensitiveContains("unique searchable title xyz") })
    }

    @Test("clearFilters resets all active filters")
    @MainActor
    func clearFiltersResetsFilters() {
        let vm = IntentViewModel()
        vm.filterStatus = "todo"
        vm.filterPriority = .high
        vm.searchText = "some search"
        vm.clearFilters()
        #expect(vm.filterStatus == nil)
        #expect(vm.filterPriority == nil)
        #expect(vm.searchText.isEmpty)
    }
}

@Suite("IntentViewModel — Board Columns")
struct IntentViewModelBoardTests {

    @Test("board initializes with five columns")
    @MainActor
    func boardInitializesWithFiveColumns() {
        let vm = IntentViewModel()
        #expect(vm.board.columns.count == 5)
    }

    @Test("allStatuses matches board column statuses")
    @MainActor
    func allStatusesMatchesBoardColumns() {
        let vm = IntentViewModel()
        let columnStatuses = vm.board.columns.map(\.status)
        #expect(vm.allStatuses == columnStatuses)
    }

    @Test("ticketsForColumn returns only tickets with matching status")
    @MainActor
    func ticketsForColumnFiltersCorrectly() {
        let vm = IntentViewModel()
        let firstColumn = vm.board.columns[0]
        let tickets = vm.ticketsForColumn(firstColumn)
        #expect(tickets.allSatisfy { $0.status == firstColumn.status })
    }
}

// MARK: - ReviewViewModel

@Suite("ReviewViewModel — Configuration and Reviews")
struct ReviewViewModelTests {

    @Test("configure sets the review port without crashing")
    @MainActor
    func configureSetPort() {
        let vm = ReviewViewModel()
        let mockPort = MockReviewManagementPort()
        // configure should not throw or crash
        vm.configure(reviewPort: mockPort)
        // State is unchanged until loadReviews is called
        #expect(vm.reviews.isEmpty)
    }

    @Test("makeSampleReviews returns non-empty array")
    func makeSampleReviewsReturnsReviews() {
        let reviews = ReviewViewModel.makeSampleReviews()
        #expect(!reviews.isEmpty)
    }

    @Test("makeSampleReviews produces reviews with unique IDs")
    func makeSampleReviewsHaveUniqueIDs() {
        let reviews = ReviewViewModel.makeSampleReviews()
        let ids = reviews.map(\.id)
        #expect(Set(ids).count == reviews.count)
    }

    @Test("selectReview updates selectedReviewID and selectedFileID")
    @MainActor
    func selectReviewUpdatesSelection() {
        let vm = ReviewViewModel()
        vm.reviews = ReviewViewModel.makeSampleReviews()
        let target = vm.reviews[0]
        vm.selectReview(target.id)
        #expect(vm.selectedReviewID == target.id)
        if let firstFile = target.diff.first {
            #expect(vm.selectedFileID == firstFile.id)
        }
    }

    @Test("selectedReview returns correct review for selectedReviewID")
    @MainActor
    func selectedReviewReturnsCorrectReview() {
        let vm = ReviewViewModel()
        vm.reviews = ReviewViewModel.makeSampleReviews()
        let target = vm.reviews[1]
        vm.selectedReviewID = target.id
        #expect(vm.selectedReview?.id == target.id)
    }

    @Test("selectedReview is nil when no selection")
    @MainActor
    func selectedReviewIsNilWhenNoSelection() {
        let vm = ReviewViewModel()
        vm.selectedReviewID = nil
        #expect(vm.selectedReview == nil)
    }

    @Test("pendingReviews filters to pending status only")
    @MainActor
    func pendingReviewsFiltersByStatus() {
        let vm = ReviewViewModel()
        vm.reviews = ReviewViewModel.makeSampleReviews()
        let pending = vm.pendingReviews
        #expect(pending.allSatisfy { $0.status == .pending })
    }

    @Test("completedReviews excludes pending reviews")
    @MainActor
    func completedReviewsExcludesPending() {
        let vm = ReviewViewModel()
        vm.reviews = ReviewViewModel.makeSampleReviews()
        let completed = vm.completedReviews
        #expect(completed.allSatisfy { $0.status != .pending })
    }

    @Test("approveHunk records approved decision")
    @MainActor
    func approveHunkRecordsDecision() {
        let vm = ReviewViewModel()
        vm.approveHunk("hunk-auth-1")
        #expect(vm.decisionFor("hunk-auth-1") == .approved)
    }

    @Test("rejectHunk records rejected decision")
    @MainActor
    func rejectHunkRecordsDecision() {
        let vm = ReviewViewModel()
        vm.rejectHunk("hunk-config-1")
        #expect(vm.decisionFor("hunk-config-1") == .rejected)
    }

    @Test("decisionFor returns pending for unknown hunk")
    @MainActor
    func decisionForReturnsDefaultPending() {
        let vm = ReviewViewModel()
        #expect(vm.decisionFor("never-seen-hunk") == .pending)
    }

    @Test("nextHunk increments focusedHunkIndex")
    @MainActor
    func nextHunkIncrementsIndex() {
        let vm = ReviewViewModel()
        vm.reviews = ReviewViewModel.makeSampleReviews()
        vm.selectReview(vm.reviews[0].id)
        let initial = vm.focusedHunkIndex
        vm.nextHunk()
        #expect(vm.focusedHunkIndex == initial + 1)
    }

    @Test("previousHunk decrements focusedHunkIndex but not below zero")
    @MainActor
    func previousHunkDoesNotGoBelowZero() {
        let vm = ReviewViewModel()
        vm.focusedHunkIndex = 0
        vm.previousHunk()
        #expect(vm.focusedHunkIndex == 0)
    }

    @Test("toggleSelection adds ID to selectedReviewIDs")
    @MainActor
    func toggleSelectionAddsID() {
        let vm = ReviewViewModel()
        vm.toggleSelection("review-1")
        #expect(vm.selectedReviewIDs.contains("review-1"))
    }

    @Test("toggleSelection removes ID when already selected")
    @MainActor
    func toggleSelectionRemovesWhenAlreadySelected() {
        let vm = ReviewViewModel()
        vm.toggleSelection("review-1")
        vm.toggleSelection("review-1")
        #expect(!vm.selectedReviewIDs.contains("review-1"))
    }

    @Test("submitInlineComment appends comment and clears state")
    @MainActor
    func submitInlineCommentAppendsAndClears() {
        let vm = ReviewViewModel()
        vm.startInlineComment(fileId: "file-1", lineNumber: 42, side: .new)
        vm.inlineCommentText = "Looks good here"
        vm.submitInlineComment()
        let comments = vm.inlineCommentsForLine(fileId: "file-1", lineNumber: 42)
        #expect(comments.count == 1)
        #expect(comments[0].body == "Looks good here")
        #expect(vm.activeCommentLine == nil)
        #expect(vm.inlineCommentText.isEmpty)
    }

    @Test("submitInlineComment does nothing when text is blank")
    @MainActor
    func submitInlineCommentIgnoresBlankText() {
        let vm = ReviewViewModel()
        vm.startInlineComment(fileId: "file-1", lineNumber: 10, side: .old)
        vm.inlineCommentText = "   "
        vm.submitInlineComment()
        let comments = vm.inlineCommentsForLine(fileId: "file-1", lineNumber: 10)
        #expect(comments.isEmpty)
    }

    @Test("cancelInlineComment clears activeCommentLine and text")
    @MainActor
    func cancelInlineCommentClearsState() {
        let vm = ReviewViewModel()
        vm.startInlineComment(fileId: "file-2", lineNumber: 7, side: .new)
        vm.inlineCommentText = "Draft comment"
        vm.cancelInlineComment()
        #expect(vm.activeCommentLine == nil)
        #expect(vm.inlineCommentText.isEmpty)
    }

    @Test("clearBranchDiff resets branch diff state")
    @MainActor
    func clearBranchDiffResetsState() {
        let vm = ReviewViewModel()
        vm.selectedBranchName = "feature/test"
        vm.clearBranchDiff()
        #expect(vm.selectedBranchName == nil)
        #expect(vm.branchDiffFiles.isEmpty)
        #expect(vm.selectedReviewID == nil)
        #expect(vm.selectedFileID == nil)
    }
}

// MARK: - AnvilSpace Enum

@Suite("AnvilSpace — Enum Properties")
struct AnvilSpaceEnumTests {

    @Test("plan space maps to correct icon")
    func planSpaceHasTargetIcon() {
        #expect(AnvilSpace.plan.icon == "target")
    }

    @Test("build space maps to correct icon")
    func buildSpaceHasHammerIcon() {
        #expect(AnvilSpace.build.icon == "hammer")
    }

    @Test("review space maps to correct icon")
    func reviewSpaceHasCheckmarkCircleIcon() {
        #expect(AnvilSpace.review.icon == "checkmark.circle")
    }

    @Test("operate space maps to correct icon")
    func operateSpaceHasGaugeIcon() {
        #expect(AnvilSpace.operate.icon == "gauge")
    }

    @Test("library space maps to correct icon")
    func librarySpaceHasBooksIcon() {
        #expect(AnvilSpace.library.icon == "books.vertical")
    }

    @Test("plan shortcut is 1")
    func planShortcutIsOne() {
        #expect(AnvilSpace.plan.shortcutNumber == 1)
    }

    @Test("build shortcut is 2")
    func buildShortcutIsTwo() {
        #expect(AnvilSpace.build.shortcutNumber == 2)
    }

    @Test("review shortcut is 3")
    func reviewShortcutIsThree() {
        #expect(AnvilSpace.review.shortcutNumber == 3)
    }

    @Test("operate shortcut is 4")
    func operateShortcutIsFour() {
        #expect(AnvilSpace.operate.shortcutNumber == 4)
    }

    @Test("library shortcut is 5")
    func libraryShortcutIsFive() {
        #expect(AnvilSpace.library.shortcutNumber == 5)
    }

    @Test("AnvilSpace conforms to CaseIterable and has 5 cases")
    func anvilSpaceHasFiveCases() {
        #expect(AnvilSpace.allCases.count == 5)
    }

    @Test("AnvilSpace ids are rawValues")
    func spaceIdsAreRawValues() {
        for space in AnvilSpace.allCases {
            #expect(space.id == space.rawValue)
        }
    }
}

// MARK: - AppState — Section Switching

@Suite("AppState — Build Section Switching")
struct AppStateBuildSectionTests {

    @Test("buildActiveSection defaults to sessions")
    @MainActor
    func buildActiveSectionDefaultsToSessions() {
        let state = AppState()
        #expect(state.buildActiveSection == .sessions)
    }

    @Test("buildActiveSection can be set to tests")
    @MainActor
    func buildSectionSwitchesToTests() {
        let state = AppState()
        state.buildActiveSection = .tests
        #expect(state.buildActiveSection == .tests)
    }

    @Test("buildActiveSection can be set to files")
    @MainActor
    func buildSectionSwitchesToFiles() {
        let state = AppState()
        state.buildActiveSection = .files
        #expect(state.buildActiveSection == .files)
    }

    @Test("buildActiveSection can be set to data")
    @MainActor
    func buildSectionSwitchesToData() {
        let state = AppState()
        state.buildActiveSection = .data
        #expect(state.buildActiveSection == .data)
    }

    @Test("buildActiveSection roundtrips through all values")
    @MainActor
    func buildSectionCyclesThroughAllValues() {
        let state = AppState()
        for section in AppState.BuildSection.allCases {
            state.buildActiveSection = section
            #expect(state.buildActiveSection == section)
        }
    }

    @Test("all BuildSection cases have non-empty rawValues")
    func allBuildSectionsHaveRawValues() {
        for section in AppState.BuildSection.allCases {
            #expect(!section.rawValue.isEmpty, "Expected non-empty rawValue for BuildSection.\(section)")
        }
    }

    @Test("BuildSection has exactly four cases")
    func buildSectionHasFourCases() {
        #expect(AppState.BuildSection.allCases.count == 4)
    }
}

@Suite("AppState — Operate Section Switching")
struct AppStateOperateSectionTests {

    @Test("operateActiveSection defaults to deploy")
    @MainActor
    func operateActiveSectionDefaultsToDeploy() {
        let state = AppState()
        #expect(state.operateActiveSection == .deploy)
    }

    @Test("operateActiveSection can be set to terminal")
    @MainActor
    func operateSectionSwitchesToTerminal() {
        let state = AppState()
        state.operateActiveSection = .terminal
        #expect(state.operateActiveSection == .terminal)
    }

    @Test("operateActiveSection can be set to monitor")
    @MainActor
    func operateSectionSwitchesToMonitor() {
        let state = AppState()
        state.operateActiveSection = .monitor
        #expect(state.operateActiveSection == .monitor)
    }

    @Test("operateActiveSection roundtrips through all values")
    @MainActor
    func operateSectionCyclesThroughAllValues() {
        let state = AppState()
        for section in AppState.OperateSection.allCases {
            state.operateActiveSection = section
            #expect(state.operateActiveSection == section)
        }
    }

    @Test("all OperateSection cases have non-empty rawValues")
    func allOperateSectionsHaveRawValues() {
        for section in AppState.OperateSection.allCases {
            #expect(!section.rawValue.isEmpty, "Expected non-empty rawValue for OperateSection.\(section)")
        }
    }

    @Test("OperateSection has exactly three cases")
    func operateSectionHasThreeCases() {
        #expect(AppState.OperateSection.allCases.count == 3)
    }
}

@Suite("AppState — Library Section Switching")
struct AppStateLibrarySectionTests {

    @Test("libraryActiveSection defaults to docs")
    @MainActor
    func libraryActiveSectionDefaultsToDocs() {
        let state = AppState()
        #expect(state.libraryActiveSection == .docs)
    }

    @Test("libraryActiveSection can be set to extensions")
    @MainActor
    func librarySectionSwitchesToExtensions() {
        let state = AppState()
        state.libraryActiveSection = .extensions
        #expect(state.libraryActiveSection == .extensions)
    }

    @Test("libraryActiveSection can be set to schedule")
    @MainActor
    func librarySectionSwitchesToSchedule() {
        let state = AppState()
        state.libraryActiveSection = .schedule
        #expect(state.libraryActiveSection == .schedule)
    }

    @Test("libraryActiveSection can be set to notifications inbox")
    @MainActor
    func librarySectionSwitchesToNotifications() {
        let state = AppState()
        state.libraryActiveSection = .notifications
        #expect(state.libraryActiveSection == .notifications)
    }

    @Test("libraryActiveSection can be set to messages")
    @MainActor
    func librarySectionSwitchesToMessages() {
        let state = AppState()
        state.libraryActiveSection = .messages
        #expect(state.libraryActiveSection == .messages)
    }

    @Test("libraryActiveSection roundtrips through all values")
    @MainActor
    func librarySectionCyclesThroughAllValues() {
        let state = AppState()
        for section in AppState.LibrarySection.allCases {
            state.libraryActiveSection = section
            #expect(state.libraryActiveSection == section)
        }
    }

    @Test("all LibrarySection cases have non-empty rawValues")
    func allLibrarySectionsHaveRawValues() {
        for section in AppState.LibrarySection.allCases {
            #expect(!section.rawValue.isEmpty, "Expected non-empty rawValue for LibrarySection.\(section)")
        }
    }

    @Test("LibrarySection has exactly five cases")
    func librarySectionHasFiveCases() {
        #expect(AppState.LibrarySection.allCases.count == 5)
    }

    @Test("notifications case has rawValue Inbox")
    func notificationsRawValueIsInbox() {
        #expect(AppState.LibrarySection.notifications.rawValue == "Inbox")
    }
}

// MARK: - MessagingViewModel

@Suite("MessagingViewModel — Initial State")
struct MessagingViewModelInitialStateTests {

    @Test("channels are populated on init")
    @MainActor
    func channelsPopulatedOnInit() {
        let vm = MessagingViewModel()
        #expect(!vm.channels.isEmpty)
    }

    @Test("directMessages are populated on init")
    @MainActor
    func directMessagesPopulatedOnInit() {
        let vm = MessagingViewModel()
        #expect(!vm.directMessages.isEmpty)
    }

    @Test("selectedChannelId is set to first channel on init")
    @MainActor
    func selectedChannelIdIsFirstChannelOnInit() {
        let vm = MessagingViewModel()
        #expect(vm.selectedChannelId == vm.channels.first?.id)
    }

    @Test("inputText is empty on init")
    @MainActor
    func inputTextIsEmptyOnInit() {
        let vm = MessagingViewModel()
        #expect(vm.inputText.isEmpty)
    }

    @Test("selectedChannel resolves to the channel matching selectedChannelId")
    @MainActor
    func selectedChannelResolvesCorrectly() {
        let vm = MessagingViewModel()
        let firstId = vm.channels.first!.id
        vm.selectedChannelId = firstId
        #expect(vm.selectedChannel?.id == firstId)
    }

    @Test("selectedChannel is nil when selectedChannelId is nil")
    @MainActor
    func selectedChannelIsNilWhenNoSelection() {
        let vm = MessagingViewModel()
        vm.selectedChannelId = nil
        #expect(vm.selectedChannel == nil)
    }
}

@Suite("MessagingViewModel — Channel Selection and Messaging")
struct MessagingViewModelActionTests {

    @Test("selectChannel updates selectedChannelId")
    @MainActor
    func selectChannelUpdatesSelectedChannelId() {
        let vm = MessagingViewModel()
        let target = vm.channels[1]
        vm.selectChannel(target.id)
        #expect(vm.selectedChannelId == target.id)
    }

    @Test("selectChannel clears unread count on channel")
    @MainActor
    func selectChannelClearsUnreadCount() {
        let vm = MessagingViewModel()
        // general channel starts with unreadCount == 3
        let general = vm.channels.first(where: { $0.name == "general" })!
        #expect(general.unreadCount > 0)
        vm.selectChannel(general.id)
        let updated = vm.channels.first(where: { $0.id == general.id })!
        #expect(updated.unreadCount == 0)
    }

    @Test("selectChannel clears unread count on direct message")
    @MainActor
    func selectChannelClearsDMUnreadCount() {
        let vm = MessagingViewModel()
        let sarah = vm.directMessages.first(where: { $0.name == "Sarah Kim" })!
        #expect(sarah.unreadCount > 0)
        vm.selectChannel(sarah.id)
        let updated = vm.directMessages.first(where: { $0.id == sarah.id })!
        #expect(updated.unreadCount == 0)
    }

    @Test("messages returns demo messages for selected channel")
    @MainActor
    func messagesReturnsDemoMessagesForSelectedChannel() {
        let vm = MessagingViewModel()
        // general is selected by default and has demo messages loaded
        #expect(!vm.messages.isEmpty)
    }

    @Test("messages returns empty array when no channel is selected")
    @MainActor
    func messagesEmptyWhenNoChannelSelected() {
        let vm = MessagingViewModel()
        vm.selectedChannelId = nil
        #expect(vm.messages.isEmpty)
    }

    @Test("sendMessage appends message to current channel and clears inputText")
    @MainActor
    func sendMessageAppendsAndClearsInput() {
        let vm = MessagingViewModel()
        let countBefore = vm.messages.count
        vm.inputText = "Hello from tests"
        vm.sendMessage()
        #expect(vm.messages.count == countBefore + 1)
        #expect(vm.messages.last?.content == "Hello from tests")
        #expect(vm.inputText.isEmpty)
    }

    @Test("sendMessage marks new message as current user")
    @MainActor
    func sendMessageMarksIsCurrentUser() {
        let vm = MessagingViewModel()
        vm.inputText = "Test message"
        vm.sendMessage()
        #expect(vm.messages.last?.isCurrentUser == true)
    }

    @Test("sendMessage ignores blank input")
    @MainActor
    func sendMessageIgnoresBlankInput() {
        let vm = MessagingViewModel()
        let countBefore = vm.messages.count
        vm.inputText = "   "
        vm.sendMessage()
        #expect(vm.messages.count == countBefore)
    }

    @Test("sendMessage does nothing when no channel is selected")
    @MainActor
    func sendMessageDoesNothingWithoutChannel() {
        let vm = MessagingViewModel()
        vm.selectedChannelId = nil
        vm.inputText = "Orphan message"
        vm.sendMessage()
        // messages is always empty when selectedChannelId is nil
        #expect(vm.messages.isEmpty)
    }

    @Test("channels contain expected names")
    @MainActor
    func channelsContainExpectedNames() {
        let vm = MessagingViewModel()
        let names = vm.channels.map(\.name)
        #expect(names.contains("general"))
        #expect(names.contains("engineering"))
        #expect(names.contains("random"))
    }

    @Test("all direct messages are flagged isDirect true")
    @MainActor
    func directMessagesAreFlaggedIsDirect() {
        let vm = MessagingViewModel()
        #expect(vm.directMessages.allSatisfy(\.isDirect))
    }

    @Test("all channels are flagged isDirect false")
    @MainActor
    func channelsAreFlaggedIsDirectFalse() {
        let vm = MessagingViewModel()
        #expect(vm.channels.allSatisfy { !$0.isDirect })
    }
}

// MARK: - ScheduleViewModel

@Suite("ScheduleViewModel — Initial State")
struct ScheduleViewModelInitialStateTests {

    @Test("entries is empty before loadSampleData")
    @MainActor
    func entriesEmptyBeforeLoad() {
        let vm = ScheduleViewModel()
        #expect(vm.entries.isEmpty)
    }

    @Test("selectedEntryID is nil before loadSampleData")
    @MainActor
    func selectedEntryIDNilBeforeLoad() {
        let vm = ScheduleViewModel()
        #expect(vm.selectedEntryID == nil)
    }

    @Test("selectedTab defaults to agenda")
    @MainActor
    func selectedTabDefaultsToAgenda() {
        let vm = ScheduleViewModel()
        #expect(vm.selectedTab == .agenda)
    }

    @Test("meetingCount is zero before load")
    @MainActor
    func meetingCountZeroBeforeLoad() {
        let vm = ScheduleViewModel()
        #expect(vm.meetingCount == 0)
    }

    @Test("focusMinutes is zero before load")
    @MainActor
    func focusMinutesZeroBeforeLoad() {
        let vm = ScheduleViewModel()
        #expect(vm.focusMinutes == 0)
    }
}

@Suite("ScheduleViewModel — Sample Data and Computed Properties")
struct ScheduleViewModelDataTests {

    @Test("loadSampleData populates entries")
    @MainActor
    func loadSampleDataPopulatesEntries() {
        let vm = ScheduleViewModel()
        vm.loadSampleData()
        #expect(!vm.entries.isEmpty)
    }

    @Test("loadSampleData sets selectedEntryID to first entry")
    @MainActor
    func loadSampleDataSetsSelectedEntry() {
        let vm = ScheduleViewModel()
        vm.loadSampleData()
        #expect(vm.selectedEntryID == vm.entries.first?.id)
    }

    @Test("selectedEntry resolves to correct entry")
    @MainActor
    func selectedEntryResolvesCorrectly() {
        let vm = ScheduleViewModel()
        vm.loadSampleData()
        let target = vm.entries[1]
        vm.selectedEntryID = target.id
        #expect(vm.selectedEntry?.id == target.id)
    }

    @Test("selectedEntry is nil when selectedEntryID is nil")
    @MainActor
    func selectedEntryNilWhenNoSelection() {
        let vm = ScheduleViewModel()
        vm.loadSampleData()
        vm.selectedEntryID = nil
        #expect(vm.selectedEntry == nil)
    }

    @Test("meetingCount counts only meeting-kind entries")
    @MainActor
    func meetingCountOnlyCountsMeetings() {
        let vm = ScheduleViewModel()
        vm.loadSampleData()
        let expected = vm.entries.filter { $0.kind == .meeting }.count
        #expect(vm.meetingCount == expected)
    }

    @Test("focusMinutes sums duration of focusBlock entries")
    @MainActor
    func focusMinutesSumsFocusBlocks() {
        let vm = ScheduleViewModel()
        vm.loadSampleData()
        let expected = vm.entries
            .filter { $0.kind == .focusBlock }
            .reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
        #expect(vm.focusMinutes == expected)
        #expect(vm.focusMinutes > 0)
    }

    @Test("selectedTab can be switched to time blocks")
    @MainActor
    func selectedTabSwitchesToTimeBlocks() {
        let vm = ScheduleViewModel()
        vm.selectedTab = .blocks
        #expect(vm.selectedTab == .blocks)
    }

    @Test("makeSampleData entries have unique IDs")
    func makeSampleDataEntriesHaveUniqueIDs() {
        let entries = ScheduleViewModel.makeSampleData()
        let ids = entries.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("ScheduleEntry duration formats sub-hour correctly")
    func scheduleEntryDurationFormatSubHour() {
        let entry = ScheduleEntry(
            id: "dur-test",
            title: "Short block",
            start: Date(timeIntervalSinceReferenceDate: 0),
            end: Date(timeIntervalSinceReferenceDate: 45 * 60),
            kind: .focusBlock,
            subtitle: nil,
            linkedTicket: nil,
            attendees: []
        )
        #expect(entry.duration == "45m")
    }

    @Test("ScheduleEntry duration formats whole hours correctly")
    func scheduleEntryDurationFormatWholeHour() {
        let entry = ScheduleEntry(
            id: "dur-test-2",
            title: "One hour block",
            start: Date(timeIntervalSinceReferenceDate: 0),
            end: Date(timeIntervalSinceReferenceDate: 60 * 60),
            kind: .meeting,
            subtitle: nil,
            linkedTicket: nil,
            attendees: []
        )
        #expect(entry.duration == "1h")
    }

    @Test("ScheduleEntry duration formats hours and minutes correctly")
    func scheduleEntryDurationFormatHoursAndMinutes() {
        let entry = ScheduleEntry(
            id: "dur-test-3",
            title: "Hour and a half",
            start: Date(timeIntervalSinceReferenceDate: 0),
            end: Date(timeIntervalSinceReferenceDate: 90 * 60),
            kind: .focusBlock,
            subtitle: nil,
            linkedTicket: nil,
            attendees: []
        )
        #expect(entry.duration == "1h 30m")
    }

    @Test("ScheduleEntryKind kindLabel values are non-empty")
    func kindLabelNonEmpty() {
        let entry = ScheduleEntry(
            id: "label-test",
            title: "Any",
            start: Date(),
            end: Date(),
            kind: .breakBlock,
            subtitle: nil,
            linkedTicket: nil,
            attendees: []
        )
        #expect(!entry.kindLabel.isEmpty)
    }
}

// MARK: - NotificationsViewModel

@Suite("NotificationsViewModel — Initial State")
struct NotificationsViewModelInitialStateTests {

    @Test("inboxItems is empty before loadSampleData")
    @MainActor
    func inboxItemsEmptyBeforeLoad() {
        let vm = NotificationsViewModel()
        #expect(vm.inboxItems.isEmpty)
    }

    @Test("activityEvents is empty before loadSampleData")
    @MainActor
    func activityEventsEmptyBeforeLoad() {
        let vm = NotificationsViewModel()
        #expect(vm.activityEvents.isEmpty)
    }

    @Test("selectedTab defaults to inbox")
    @MainActor
    func selectedTabDefaultsToInbox() {
        let vm = NotificationsViewModel()
        #expect(vm.selectedTab == .inbox)
    }

    @Test("sourceFilter defaults to all")
    @MainActor
    func sourceFilterDefaultsToAll() {
        let vm = NotificationsViewModel()
        #expect(vm.sourceFilter == .all)
    }

    @Test("selectedItemID is nil on init")
    @MainActor
    func selectedItemIDNilOnInit() {
        let vm = NotificationsViewModel()
        #expect(vm.selectedItemID == nil)
    }

    @Test("unreadCount is zero when inbox is empty")
    @MainActor
    func unreadCountZeroWhenEmpty() {
        let vm = NotificationsViewModel()
        #expect(vm.unreadCount == 0)
    }
}

@Suite("NotificationsViewModel — Actions")
struct NotificationsViewModelActionTests {

    @Test("loadSampleData populates inboxItems and activityEvents")
    @MainActor
    func loadSampleDataPopulatesBothCollections() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        #expect(!vm.inboxItems.isEmpty)
        #expect(!vm.activityEvents.isEmpty)
    }

    @Test("markAsRead sets isRead to true for given id")
    @MainActor
    func markAsReadSetsIsRead() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        let unread = vm.inboxItems.first(where: { !$0.notification.isRead })!
        vm.markAsRead(unread.id)
        let updated = vm.inboxItems.first(where: { $0.id == unread.id })!
        #expect(updated.notification.isRead == true)
    }

    @Test("markAsRead does nothing for unknown id")
    @MainActor
    func markAsReadIgnoresUnknownId() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        let countBefore = vm.inboxItems.count
        vm.markAsRead("ghost-id")
        #expect(vm.inboxItems.count == countBefore)
    }

    @Test("dismissNotification removes item from inboxItems")
    @MainActor
    func dismissNotificationRemovesItem() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        let target = vm.inboxItems.first!
        let countBefore = vm.inboxItems.count
        vm.dismissNotification(target.id)
        #expect(vm.inboxItems.count == countBefore - 1)
        #expect(!vm.inboxItems.contains(where: { $0.id == target.id }))
    }

    @Test("markAllAsRead sets all items to read")
    @MainActor
    func markAllAsReadSetsAllRead() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        vm.markAllAsRead()
        #expect(vm.inboxItems.allSatisfy(\.notification.isRead))
    }

    @Test("unreadCount decreases after markAsRead")
    @MainActor
    func unreadCountDecreasesAfterMarkAsRead() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        let countBefore = vm.unreadCount
        let unread = vm.inboxItems.first(where: { !$0.notification.isRead })!
        vm.markAsRead(unread.id)
        #expect(vm.unreadCount == countBefore - 1)
    }

    @Test("unreadCount is zero after markAllAsRead")
    @MainActor
    func unreadCountZeroAfterMarkAllAsRead() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        vm.markAllAsRead()
        #expect(vm.unreadCount == 0)
    }

    @Test("sourceFilter pr hides non-PR inbox items")
    @MainActor
    func sourceFilterPRHidesNonPRItems() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        vm.sourceFilter = .prs
        #expect(vm.filteredInboxItems.allSatisfy { $0.source == .pr })
    }

    @Test("sourceFilter all shows all items passing preferences")
    @MainActor
    func sourceFilterAllShowsAllItems() {
        let vm = NotificationsViewModel()
        vm.loadSampleData()
        vm.sourceFilter = .all
        // filteredInboxItems should equal inboxItems filtered by preferences — at least non-empty
        #expect(!vm.filteredInboxItems.isEmpty)
    }

    @Test("selectedTab can be switched to activity")
    @MainActor
    func selectedTabSwitchesToActivity() {
        let vm = NotificationsViewModel()
        vm.selectedTab = .activity
        #expect(vm.selectedTab == .activity)
    }

    @Test("selectedTab can be switched to preferences")
    @MainActor
    func selectedTabSwitchesToPreferences() {
        let vm = NotificationsViewModel()
        vm.selectedTab = .preferences
        #expect(vm.selectedTab == .preferences)
    }
}

// MARK: - ProjectSearchViewModel

@Suite("ProjectSearchViewModel — Initial State")
struct ProjectSearchViewModelInitialStateTests {

    @Test("searchText is empty on init")
    @MainActor
    func searchTextEmptyOnInit() {
        let vm = ProjectSearchViewModel()
        #expect(vm.searchText.isEmpty)
    }

    @Test("replaceText is empty on init")
    @MainActor
    func replaceTextEmptyOnInit() {
        let vm = ProjectSearchViewModel()
        #expect(vm.replaceText.isEmpty)
    }

    @Test("results is empty on init")
    @MainActor
    func resultsEmptyOnInit() {
        let vm = ProjectSearchViewModel()
        #expect(vm.results.isEmpty)
    }

    @Test("matchCase defaults to false")
    @MainActor
    func matchCaseDefaultsFalse() {
        let vm = ProjectSearchViewModel()
        #expect(vm.matchCase == false)
    }

    @Test("useRegex defaults to false")
    @MainActor
    func useRegexDefaultsFalse() {
        let vm = ProjectSearchViewModel()
        #expect(vm.useRegex == false)
    }

    @Test("wholeWord defaults to false")
    @MainActor
    func wholeWordDefaultsFalse() {
        let vm = ProjectSearchViewModel()
        #expect(vm.wholeWord == false)
    }

    @Test("isReplaceExpanded defaults to false")
    @MainActor
    func isReplaceExpandedDefaultsFalse() {
        let vm = ProjectSearchViewModel()
        #expect(vm.isReplaceExpanded == false)
    }

    @Test("collapsedFiles is empty on init")
    @MainActor
    func collapsedFilesEmptyOnInit() {
        let vm = ProjectSearchViewModel()
        #expect(vm.collapsedFiles.isEmpty)
    }

    @Test("totalMatchCount is zero on init")
    @MainActor
    func totalMatchCountZeroOnInit() {
        let vm = ProjectSearchViewModel()
        #expect(vm.totalMatchCount == 0)
    }

    @Test("fileCount is zero on init")
    @MainActor
    func fileCountZeroOnInit() {
        let vm = ProjectSearchViewModel()
        #expect(vm.fileCount == 0)
    }
}

@Suite("ProjectSearchViewModel — Toggle and Clear Behavior")
struct ProjectSearchViewModelBehaviorTests {

    @Test("toggleFileCollapsed adds path to collapsedFiles")
    @MainActor
    func toggleFileCollapsedAddsPath() {
        let vm = ProjectSearchViewModel()
        vm.toggleFileCollapsed("src/Foo.swift")
        #expect(vm.collapsedFiles.contains("src/Foo.swift"))
    }

    @Test("toggleFileCollapsed removes path when already collapsed")
    @MainActor
    func toggleFileCollapsedRemovesWhenPresent() {
        let vm = ProjectSearchViewModel()
        vm.toggleFileCollapsed("src/Foo.swift")
        vm.toggleFileCollapsed("src/Foo.swift")
        #expect(!vm.collapsedFiles.contains("src/Foo.swift"))
    }

    @Test("multiple paths can be collapsed simultaneously")
    @MainActor
    func multiplePathsCanBeCollapsed() {
        let vm = ProjectSearchViewModel()
        vm.toggleFileCollapsed("A.swift")
        vm.toggleFileCollapsed("B.swift")
        #expect(vm.collapsedFiles.count == 2)
    }

    @Test("clear resets searchText, replaceText, results, and collapsedFiles")
    @MainActor
    func clearResetsAllState() {
        let vm = ProjectSearchViewModel()
        vm.replaceText = "replacement"
        vm.toggleFileCollapsed("some/path.swift")
        vm.clear()
        #expect(vm.searchText.isEmpty)
        #expect(vm.replaceText.isEmpty)
        #expect(vm.results.isEmpty)
        #expect(vm.collapsedFiles.isEmpty)
    }

    @Test("short searchText (< 2 chars) clears results immediately")
    @MainActor
    func shortSearchTextClearsResults() {
        let vm = ProjectSearchViewModel()
        // Inject a fake result to verify it gets cleared
        vm.results = [FileSearchResult(filePath: "a/b.swift", fileName: "b.swift", matches: [])]
        vm.searchText = "x"  // one character — below threshold
        #expect(vm.results.isEmpty)
    }

    @Test("isSearching defaults to false")
    @MainActor
    func isSearchingDefaultsFalse() {
        let vm = ProjectSearchViewModel()
        #expect(vm.isSearching == false)
    }

    @Test("projectPath defaults to nil")
    @MainActor
    func projectPathDefaultsNil() {
        let vm = ProjectSearchViewModel()
        #expect(vm.projectPath == nil)
    }

    @Test("fileFilter is empty on init")
    @MainActor
    func fileFilterEmptyOnInit() {
        let vm = ProjectSearchViewModel()
        #expect(vm.fileFilter.isEmpty)
    }

    @Test("totalMatchCount sums matches across all results")
    @MainActor
    func totalMatchCountSumsAllMatches() {
        let vm = ProjectSearchViewModel()
        let line = "let x = 1"
        let range = line.startIndex..<line.index(line.startIndex, offsetBy: 3)
        let match = SearchMatch(lineNumber: 1, lineContent: line, matchRange: range)
        vm.results = [
            FileSearchResult(filePath: "A.swift", fileName: "A.swift", matches: [match, match]),
            FileSearchResult(filePath: "B.swift", fileName: "B.swift", matches: [match]),
        ]
        #expect(vm.totalMatchCount == 3)
        #expect(vm.fileCount == 2)
    }
}

// MARK: - Mock Helpers

/// Minimal mock that satisfies ReviewManagementPort for configure() tests.
private final class MockReviewManagementPort: ReviewManagementPort, @unchecked Sendable {
    func fetchReviews() async throws -> [Review] { [] }
    func createReview(_ review: Review) async throws -> Review { review }
    func updateReview(_ review: Review) async throws -> Review { review }
    func deleteReview(id: String) async throws {}
    func approveReview(id: String, comment: String?) async throws -> Review {
        guard let r = _reviews.first(where: { $0.id == id }) else {
            throw MockError.notFound
        }
        return r
    }
    func requestChanges(id: String, comment: String) async throws -> Review {
        guard let r = _reviews.first(where: { $0.id == id }) else {
            throw MockError.notFound
        }
        return r
    }

    private var _reviews: [Review] = []

    enum MockError: Error { case notFound }
}
