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
    @MainActor
    func makeSampleReviewsReturnsReviews() {
        let reviews = ReviewViewModel.makeSampleReviews()
        #expect(!reviews.isEmpty)
    }

    @Test("makeSampleReviews produces reviews with unique IDs")
    @MainActor
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

// MARK: - AppState — Source Switching

@Suite("AppState — Build Source Switching")
struct AppStateBuildSourceTests {

    @Test("buildActiveSource defaults to sessions")
    @MainActor
    func buildActiveSourceDefaultsToSessions() {
        let state = AppState()
        #expect(state.buildActiveSource == .sessions)
    }

    @Test("buildActiveSource can be set to tests")
    @MainActor
    func buildSourceSwitchesToTests() {
        let state = AppState()
        state.buildActiveSource = .tests
        #expect(state.buildActiveSource == .tests)
    }

    @Test("buildActiveSource can be set to files")
    @MainActor
    func buildSourceSwitchesToFiles() {
        let state = AppState()
        state.buildActiveSource = .files
        #expect(state.buildActiveSource == .files)
    }

    @Test("buildActiveSource can be set to data")
    @MainActor
    func buildSourceSwitchesToData() {
        let state = AppState()
        state.buildActiveSource = .data
        #expect(state.buildActiveSource == .data)
    }

    @Test("buildActiveSource roundtrips through all values")
    @MainActor
    func buildSourceCyclesThroughAllValues() {
        let state = AppState()
        for section in AppState.BuildSource.allCases {
            state.buildActiveSource = section
            #expect(state.buildActiveSource == section)
        }
    }

    @Test("all BuildSource cases have non-empty rawValues")
    func allBuildSourcesHaveRawValues() {
        for section in AppState.BuildSource.allCases {
            #expect(!section.rawValue.isEmpty, "Expected non-empty rawValue for BuildSource.\(section)")
        }
    }

    @Test("BuildSource has exactly four cases")
    func buildSourceHasFourCases() {
        #expect(AppState.BuildSource.allCases.count == 4)
    }
}

@Suite("AppState — Operate Source Switching")
struct AppStateOperateSourceTests {

    @Test("operateActiveSource defaults to deploy")
    @MainActor
    func operateActiveSourceDefaultsToDeploy() {
        let state = AppState()
        #expect(state.operateActiveSource == .deploy)
    }

    @Test("operateActiveSource can be set to monitor")
    @MainActor
    func operateSourceSwitchesToMonitor() {
        let state = AppState()
        state.operateActiveSource = .monitor
        #expect(state.operateActiveSource == .monitor)
    }

    @Test("operateActiveSource roundtrips through all values")
    @MainActor
    func operateSourceCyclesThroughAllValues() {
        let state = AppState()
        for section in AppState.OperateSource.allCases {
            state.operateActiveSource = section
            #expect(state.operateActiveSource == section)
        }
    }

    @Test("all OperateSource cases have non-empty rawValues")
    func allOperateSourcesHaveRawValues() {
        for section in AppState.OperateSource.allCases {
            #expect(!section.rawValue.isEmpty, "Expected non-empty rawValue for OperateSource.\(section)")
        }
    }

    @Test("OperateSource has exactly three cases")
    func operateSourceHasThreeCases() {
        #expect(AppState.OperateSource.allCases.count == 3)
    }
}

@Suite("AppState — Library Source Switching")
struct AppStateLibrarySourceTests {

    @Test("libraryActiveSource defaults to docs")
    @MainActor
    func libraryActiveSourceDefaultsToDocs() {
        let state = AppState()
        #expect(state.libraryActiveSource == .docs)
    }

    @Test("libraryActiveSource can be set to extensions")
    @MainActor
    func librarySourceSwitchesToExtensions() {
        let state = AppState()
        state.libraryActiveSource = .extensions
        #expect(state.libraryActiveSource == .extensions)
    }

    @Test("libraryActiveSource can be set to schedule")
    @MainActor
    func librarySourceSwitchesToSchedule() {
        let state = AppState()
        state.libraryActiveSource = .schedule
        #expect(state.libraryActiveSource == .schedule)
    }

    @Test("libraryActiveSource can be set to notifications inbox")
    @MainActor
    func librarySourceSwitchesToNotifications() {
        let state = AppState()
        state.libraryActiveSource = .notifications
        #expect(state.libraryActiveSource == .notifications)
    }

    @Test("libraryActiveSource can be set to messages")
    @MainActor
    func librarySourceSwitchesToMessages() {
        let state = AppState()
        state.libraryActiveSource = .messages
        #expect(state.libraryActiveSource == .messages)
    }

    @Test("libraryActiveSource roundtrips through all values")
    @MainActor
    func librarySourceCyclesThroughAllValues() {
        let state = AppState()
        for section in AppState.LibrarySource.allCases {
            state.libraryActiveSource = section
            #expect(state.libraryActiveSource == section)
        }
    }

    @Test("all LibrarySource cases have non-empty rawValues")
    func allLibrarySourcesHaveRawValues() {
        for section in AppState.LibrarySource.allCases {
            #expect(!section.rawValue.isEmpty, "Expected non-empty rawValue for LibrarySource.\(section)")
        }
    }

    @Test("LibrarySource has exactly five cases")
    func librarySourceHasFiveCases() {
        #expect(AppState.LibrarySource.allCases.count == 5)
    }

    @Test("notifications case has rawValue Inbox")
    func notificationsRawValueIsInbox() {
        #expect(AppState.LibrarySource.notifications.rawValue == "Inbox")
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
        #expect(vm.directMessages.allSatisfy { $0.isDirect })
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
    @MainActor
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
        #expect(vm.inboxItems.allSatisfy { $0.notification.isRead })
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

// MARK: - TerminalViewModel

@Suite("TerminalViewModel")
struct TerminalViewModelTests {

    @Test("init starts empty; the first session is created lazily by addTab")
    @MainActor
    func initCreatesNoSessionUntilOpened() {
        let vm = TerminalViewModel()
        #expect(vm.sessions.isEmpty)
        #expect(vm.selectedSession == nil)
    }

    @Test("the first addTab selects the new session")
    @MainActor
    func firstTabIsSelected() {
        let vm = TerminalViewModel()
        let first = vm.addTab()
        #expect(vm.sessions.count == 1)
        #expect(vm.selectedSessionId == first.id)
        #expect(vm.selectedSession != nil)
    }

    @Test("addTab creates a second session and returns it")
    @MainActor
    func addTabCreatesSecondSession() {
        let vm = TerminalViewModel()
        vm.addTab()
        let newSession = vm.addTab()
        #expect(vm.sessions.count == 2)
        #expect(vm.sessions.contains { $0.id == newSession.id })
    }

    @Test("selectTab changes the active session")
    @MainActor
    func selectTabChangesActive() {
        let vm = TerminalViewModel()
        let second = vm.addTab()
        vm.selectTab(second.id)
        #expect(vm.selectedSessionId == second.id)
        #expect(vm.selectedSession?.id == second.id)
    }

    @Test("closeTab removes the session")
    @MainActor
    func closeTabRemovesSession() {
        let vm = TerminalViewModel()
        vm.addTab()
        let second = vm.addTab()
        #expect(vm.sessions.count == 2)
        vm.closeTab(second.id)
        #expect(vm.sessions.count == 1)
        #expect(vm.sessions.allSatisfy { $0.id != second.id })
    }

    @Test("session(with:) returns nil for unknown id")
    @MainActor
    func sessionWithNilIdReturnsNil() {
        let vm = TerminalViewModel()
        #expect(vm.session(with: nil) == nil)
        #expect(vm.session(with: UUID()) == nil)
    }

    @Test("resize updates terminalColumns and terminalRows")
    @MainActor
    func resizeUpdatesProperties() {
        let vm = TerminalViewModel()
        vm.resize(columns: 120, rows: 40)
        #expect(vm.terminalColumns == 120)
        #expect(vm.terminalRows == 40)
    }

    @Test("default column and row values are 80x24")
    @MainActor
    func defaultDimensions() {
        let vm = TerminalViewModel()
        #expect(vm.terminalColumns == 80)
        #expect(vm.terminalRows == 24)
    }
}

// MARK: - TestingViewModel

@Suite("TestingViewModel")
struct TestingViewModelTests {

    @Test("init starts with empty suites")
    @MainActor
    func initEmptySuites() {
        let vm = TestingViewModel()
        #expect(vm.suites.isEmpty)
    }

    @Test("init isRunning is false")
    @MainActor
    func initIsRunningFalse() {
        let vm = TestingViewModel()
        #expect(vm.isRunning == false)
    }

    @Test("loadDemoData populates suites")
    @MainActor
    func loadDemoDataPopulatesSuites() {
        let vm = TestingViewModel()
        vm.loadDemoData()
        #expect(!vm.suites.isEmpty)
    }

    @Test("loadDemoData sets lastRunDate")
    @MainActor
    func loadDemoDataSetsLastRunDate() {
        let vm = TestingViewModel()
        vm.loadDemoData()
        #expect(vm.lastRunDate != nil)
    }

    @Test("totalTests sums across all suites")
    @MainActor
    func totalTestsSumsAllSuites() {
        let vm = TestingViewModel()
        vm.loadDemoData()
        let expected = vm.suites.reduce(0) { $0 + $1.totalCount }
        #expect(vm.totalTests == expected)
    }

    @Test("passedTests and failedTests aggregate correctly")
    @MainActor
    func passedAndFailedAggregate() {
        let vm = TestingViewModel()
        vm.loadDemoData()
        #expect(vm.passedTests == vm.suites.reduce(0) { $0 + $1.passedCount })
        #expect(vm.failedTests == vm.suites.reduce(0) { $0 + $1.failedCount })
    }

    @Test("selectedTest is nil when selectedTestId is nil")
    @MainActor
    func selectedTestNilByDefault() {
        let vm = TestingViewModel()
        #expect(vm.selectedTestId == nil)
        #expect(vm.selectedTest == nil)
    }

    @Test("selectedTest resolves after setting selectedTestId")
    @MainActor
    func selectedTestResolvesById() {
        let vm = TestingViewModel()
        vm.loadDemoData()
        let firstCase = vm.suites[0].tests[0]
        vm.selectedTestId = firstCase.id
        #expect(vm.selectedTest?.id == firstCase.id)
    }

    @Test("toggleSuiteExpansion flips isExpanded")
    @MainActor
    func toggleSuiteExpansionFlips() {
        let vm = TestingViewModel()
        vm.loadDemoData()
        let suiteId = vm.suites[0].id
        let before = vm.suites[0].isExpanded
        vm.toggleSuiteExpansion(suiteId)
        #expect(vm.suites[0].isExpanded == !before)
        vm.toggleSuiteExpansion(suiteId)
        #expect(vm.suites[0].isExpanded == before)
    }

    @Test("filterText filters filteredSuites by test name")
    @MainActor
    func filterTextNarrowsResults() {
        let vm = TestingViewModel()
        vm.loadDemoData()
        let firstName = vm.suites[0].tests[0].name
        vm.filterText = firstName
        let allTestNames = vm.filteredSuites.flatMap { $0.tests.map(\.name) }
        #expect(allTestNames.contains(firstName))
        // All returned test names should match the filter
        #expect(allTestNames.allSatisfy {
            $0.localizedCaseInsensitiveContains(firstName)
                || vm.filteredSuites.contains { s in s.name.localizedCaseInsensitiveContains(firstName) }
        })
    }

    @Test("showFilter .failed returns only failed tests")
    @MainActor
    func showFilterFailedReturnsOnlyFailed() {
        let vm = TestingViewModel()
        vm.loadDemoData()
        vm.showFilter = .failed
        let statuses = vm.filteredSuites.flatMap { $0.tests.map(\.status) }
        #expect(statuses.allSatisfy { $0 == .failed })
    }

    @Test("stopTests resets isRunning to false")
    @MainActor
    func stopTestsResetsIsRunning() {
        let vm = TestingViewModel()
        // isRunning starts false; stopTests should leave it false without crashing
        vm.stopTests()
        #expect(vm.isRunning == false)
    }

    @Test("TestSuite overallStatus is pending when no tests")
    func testSuiteOverallStatusPendingWhenEmpty() {
        let suite = TestSuite(name: "Empty")
        #expect(suite.overallStatus == .pending)
    }

    @Test("TestSuite overallStatus is passed when all tests pass")
    func testSuiteOverallStatusAllPassed() {
        let suite = TestSuite(name: "S", tests: [
            TestCase(name: "a", status: .passed),
            TestCase(name: "b", status: .passed),
        ])
        #expect(suite.overallStatus == .passed)
    }

    @Test("TestSuite overallStatus is failed when any test fails")
    func testSuiteOverallStatusAnyFailed() {
        let suite = TestSuite(name: "S", tests: [
            TestCase(name: "a", status: .passed),
            TestCase(name: "b", status: .failed),
        ])
        #expect(suite.overallStatus == .failed)
    }
}

// MARK: - PluginMarketplaceViewModel

@Suite("PluginMarketplaceViewModel")
struct PluginMarketplaceViewModelTests {

    @Test("init starts with empty plugins array")
    @MainActor
    func initEmptyPlugins() {
        let vm = PluginMarketplaceViewModel()
        #expect(vm.plugins.isEmpty)
    }

    @Test("init selectedCategory is .all")
    @MainActor
    func initSelectedCategoryIsAll() {
        let vm = PluginMarketplaceViewModel()
        #expect(vm.selectedCategory == .all)
    }

    @Test("loadBuiltInPlugins populates plugins")
    @MainActor
    func loadBuiltInPluginsPopulates() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        #expect(!vm.plugins.isEmpty)
    }

    @Test("installPlugin marks plugin installed and enabled")
    @MainActor
    func installPluginSetsFlags() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        let uninstalled = vm.plugins.first { !$0.isInstalled }
        guard let plugin = uninstalled else { return }
        vm.installPlugin(plugin.id)
        let updated = vm.plugins.first { $0.id == plugin.id }
        #expect(updated?.isInstalled == true)
        #expect(updated?.isEnabled == true)
    }

    @Test("uninstallPlugin marks plugin not installed and disabled")
    @MainActor
    func uninstallPluginClearsFlags() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        let installed = vm.plugins.first { $0.isInstalled }
        guard let plugin = installed else { return }
        vm.uninstallPlugin(plugin.id)
        let updated = vm.plugins.first { $0.id == plugin.id }
        #expect(updated?.isInstalled == false)
        #expect(updated?.isEnabled == false)
    }

    @Test("togglePlugin flips isEnabled")
    @MainActor
    func togglePluginFlipsEnabled() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        let installed = vm.plugins.first { $0.isInstalled }
        guard let plugin = installed else { return }
        let before = plugin.isEnabled
        vm.togglePlugin(plugin.id)
        let updated = vm.plugins.first { $0.id == plugin.id }
        #expect(updated?.isEnabled == !before)
    }

    @Test("selectPlugin sets selectedPluginId and viewMode to detail")
    @MainActor
    func selectPluginSetsViewMode() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        let plugin = vm.plugins[0]
        vm.selectPlugin(plugin.id)
        #expect(vm.selectedPluginId == plugin.id)
        if case .detail(let id) = vm.viewMode {
            #expect(id == plugin.id)
        } else {
            Issue.record("Expected viewMode to be .detail but was \(vm.viewMode)")
        }
    }

    @Test("selectedPlugin resolves after selectPlugin")
    @MainActor
    func selectedPluginResolves() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        let plugin = vm.plugins[0]
        vm.selectPlugin(plugin.id)
        #expect(vm.selectedPlugin?.id == plugin.id)
    }

    @Test("selectedPlugin is nil before any selection")
    @MainActor
    func selectedPluginNilInitially() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        #expect(vm.selectedPlugin == nil)
    }

    @Test("installedPlugins returns only installed plugins")
    @MainActor
    func installedPluginsFiltered() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        #expect(vm.installedPlugins.allSatisfy { $0.isInstalled })
        #expect(vm.installedCount == vm.installedPlugins.count)
    }

    @Test("filteredPlugins respects category filter")
    @MainActor
    func filteredPluginsRespectsCategoryFilter() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        vm.selectedCategory = .ai
        #expect(vm.filteredPlugins.allSatisfy { $0.category == .ai })
    }

    @Test("filteredPlugins respects searchText")
    @MainActor
    func filteredPluginsRespectsSearchText() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        vm.searchText = "Python"
        #expect(!vm.filteredPlugins.isEmpty)
        #expect(vm.filteredPlugins.allSatisfy {
            $0.name.localizedCaseInsensitiveContains("Python")
                || $0.pluginDescription.localizedCaseInsensitiveContains("Python")
                || $0.author.localizedCaseInsensitiveContains("Python")
        })
    }

    @Test("searchText that matches nothing yields empty filteredPlugins")
    @MainActor
    func searchTextNoMatchYieldsEmpty() {
        let vm = PluginMarketplaceViewModel()
        vm.loadBuiltInPlugins()
        vm.searchText = "zzzzzzzzzz_no_match"
        #expect(vm.filteredPlugins.isEmpty)
    }

    @Test("downloadCountFormatted formats millions correctly")
    func downloadCountFormatsMillions() {
        let plugin = MarketplacePlugin(
            id: "test", name: "T", pluginDescription: "", author: "A",
            version: "1.0", category: .all, icon: "", downloadCount: 1_200_000,
            rating: 4.0, isInstalled: false, isEnabled: false
        )
        #expect(plugin.downloadCountFormatted == "1.2M")
    }

    @Test("downloadCountFormatted formats thousands correctly")
    func downloadCountFormatsThousands() {
        let plugin = MarketplacePlugin(
            id: "test", name: "T", pluginDescription: "", author: "A",
            version: "1.0", category: .all, icon: "", downloadCount: 500,
            rating: 4.0, isInstalled: false, isEnabled: false
        )
        #expect(plugin.downloadCountFormatted == "500")
    }
}

// MARK: - DocsViewModel

@Suite("DocsViewModel")
struct DocsViewModelTests {

    @Test("init loads demo tree with nodes")
    @MainActor
    func initLoadsDemoTree() {
        let vm = DocsViewModel()
        #expect(!vm.docTree.isEmpty)
    }

    @Test("init expands top-level folders")
    @MainActor
    func initExpandsTopLevelFolders() {
        let vm = DocsViewModel()
        let topFolders = vm.docTree.filter { $0.isFolder }
        #expect(!topFolders.isEmpty)
        for folder in topFolders {
            #expect(vm.expandedFolderIds.contains(folder.id))
        }
    }

    @Test("init selects first document")
    @MainActor
    func initSelectsFirstDoc() {
        let vm = DocsViewModel()
        #expect(vm.selectedDocId != nil)
        #expect(!vm.editorContent.isEmpty)
    }

    @Test("selectDoc updates selectedDocId and editorContent")
    @MainActor
    func selectDocUpdatesState() {
        let vm = DocsViewModel()
        // Find a doc node that is not already selected
        let allFiles = vm.docTree.flatMap { node -> [DocNode] in
            node.isFolder ? node.children : [node]
        }
        guard let anotherDoc = allFiles.first(where: { $0.id != vm.selectedDocId }) else { return }
        vm.selectDoc(anotherDoc.id)
        #expect(vm.selectedDocId == anotherDoc.id)
    }

    @Test("selectedDoc resolves to the current selection")
    @MainActor
    func selectedDocResolvesCorrectly() {
        let vm = DocsViewModel()
        guard let id = vm.selectedDocId else { return }
        #expect(vm.selectedDoc?.id == id)
    }

    @Test("toggleFolder removes an expanded folder from expandedFolderIds")
    @MainActor
    func toggleFolderCollapsesExpanded() {
        let vm = DocsViewModel()
        let folder = vm.docTree.first { $0.isFolder }
        guard let folder else { return }
        #expect(vm.expandedFolderIds.contains(folder.id))
        vm.toggleFolder(folder.id)
        #expect(!vm.expandedFolderIds.contains(folder.id))
    }

    @Test("toggleFolder re-inserts a collapsed folder into expandedFolderIds")
    @MainActor
    func toggleFolderExpandsCollapsed() {
        let vm = DocsViewModel()
        let folder = vm.docTree.first { $0.isFolder }
        guard let folder else { return }
        vm.toggleFolder(folder.id)  // collapse
        vm.toggleFolder(folder.id)  // expand again
        #expect(vm.expandedFolderIds.contains(folder.id))
    }

    @Test("markModified sets isModified to true")
    @MainActor
    func markModifiedSetsFlag() {
        let vm = DocsViewModel()
        #expect(vm.isModified == false)
        vm.markModified()
        #expect(vm.isModified == true)
    }

    @Test("createNewDocument in demo mode appends node and clears newDocName")
    @MainActor
    func createNewDocInDemoMode() {
        let vm = DocsViewModel()
        let countBefore = vm.docTree.count
        vm.newDocName = "MyNewDoc"
        vm.createNewDocument()
        #expect(vm.docTree.count == countBefore + 1)
        #expect(vm.newDocName.isEmpty)
        #expect(vm.showNewDocSheet == false)
    }

    @Test("createNewDocument with empty name does nothing")
    @MainActor
    func createNewDocEmptyNameNoOp() {
        let vm = DocsViewModel()
        let countBefore = vm.docTree.count
        vm.newDocName = ""
        vm.createNewDocument()
        #expect(vm.docTree.count == countBefore)
    }

    @Test("createNewDocument appends .md extension when missing")
    @MainActor
    func createNewDocAppendsMdExtension() {
        let vm = DocsViewModel()
        vm.newDocName = "NoExtension"
        vm.createNewDocument()
        let addedNode = vm.docTree.last
        #expect(addedNode?.name.hasSuffix(".md") == true)
    }

    @Test("projectPath defaults to nil")
    @MainActor
    func projectPathDefaultsNil() {
        let vm = DocsViewModel()
        #expect(vm.projectPath == nil)
    }
}

// MARK: - ShipViewModel

@Suite("ShipViewModel — Initial State")
struct ShipViewModelInitialStateTests {

    @Test("environments is empty on init")
    @MainActor
    func environmentsEmptyOnInit() {
        let vm = ShipViewModel()
        #expect(vm.environments.isEmpty)
    }

    @Test("selectedEnvironmentID is nil on init")
    @MainActor
    func selectedEnvironmentIDNilOnInit() {
        let vm = ShipViewModel()
        #expect(vm.selectedEnvironmentID == nil)
    }

    @Test("isDeploying is false on init")
    @MainActor
    func isDeployingFalseOnInit() {
        let vm = ShipViewModel()
        #expect(vm.isDeploying == false)
    }

    @Test("deployProgress is zero on init")
    @MainActor
    func deployProgressZeroOnInit() {
        let vm = ShipViewModel()
        #expect(vm.deployProgress == 0.0)
    }

    @Test("selectedTab defaults to dashboard")
    @MainActor
    func selectedTabDefaultsToDashboard() {
        let vm = ShipViewModel()
        #expect(vm.selectedTab == .dashboard)
    }
}

@Suite("ShipViewModel — Sample Data and Selection")
struct ShipViewModelDataTests {

    @Test("loadSampleData populates environments")
    @MainActor
    func loadSampleDataPopulatesEnvironments() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        #expect(!vm.environments.isEmpty)
    }

    @Test("loadSampleData sets selectedEnvironmentID to first environment")
    @MainActor
    func loadSampleDataSetsSelectedEnvironment() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        #expect(vm.selectedEnvironmentID == vm.environments.first?.id)
    }

    @Test("selectedEnvironment resolves to correct card")
    @MainActor
    func selectedEnvironmentResolvesCorrectCard() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        let target = vm.environments[1]
        vm.selectedEnvironmentID = target.id
        #expect(vm.selectedEnvironment?.id == target.id)
    }

    @Test("selectedEnvironment is nil when selectedEnvironmentID is nil")
    @MainActor
    func selectedEnvironmentNilWhenNoSelection() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        vm.selectedEnvironmentID = nil
        #expect(vm.selectedEnvironment == nil)
    }

    @Test("envVarsForSelected is empty when no environment is selected")
    @MainActor
    func envVarsForSelectedEmptyWhenNoSelection() {
        let vm = ShipViewModel()
        vm.selectedEnvironmentID = nil
        #expect(vm.envVarsForSelected.isEmpty)
    }

    @Test("deploymentsForSelected returns all deployments when no environment selected")
    @MainActor
    func deploymentsForSelectedReturnsAllWhenNoSelection() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        vm.selectedEnvironmentID = nil
        #expect(vm.deploymentsForSelected.count == vm.deployments.count)
    }
}

@Suite("ShipViewModel — Env Var Management")
struct ShipViewModelEnvVarTests {

    @Test("addEnvVar appends a new var to the specified environment")
    @MainActor
    func addEnvVarAppendsVar() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        guard let envID = vm.selectedEnvironmentID else { return }
        let countBefore = vm.envVars[envID]?.count ?? 0
        vm.newEnvKey = "FEATURE_FLAG"
        vm.newEnvValue = "true"
        vm.addEnvVar(to: envID)
        #expect((vm.envVars[envID]?.count ?? 0) == countBefore + 1)
    }

    @Test("addEnvVar clears newEnvKey and newEnvValue after adding")
    @MainActor
    func addEnvVarClearsInputFields() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        guard let envID = vm.selectedEnvironmentID else { return }
        vm.newEnvKey = "MY_KEY"
        vm.newEnvValue = "my_value"
        vm.addEnvVar(to: envID)
        #expect(vm.newEnvKey.isEmpty)
        #expect(vm.newEnvValue.isEmpty)
    }

    @Test("addEnvVar does nothing when newEnvKey is empty")
    @MainActor
    func addEnvVarIgnoresEmptyKey() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        guard let envID = vm.selectedEnvironmentID else { return }
        let countBefore = vm.envVars[envID]?.count ?? 0
        vm.newEnvKey = ""
        vm.addEnvVar(to: envID)
        #expect((vm.envVars[envID]?.count ?? 0) == countBefore)
    }

    @Test("requestDeleteEnvVar sets showingDeleteConfirm to true")
    @MainActor
    func requestDeleteEnvVarShowsConfirm() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        guard let envID = vm.selectedEnvironmentID,
              let firstVar = vm.envVars[envID]?.first else { return }
        vm.requestDeleteEnvVar(id: firstVar.id, from: envID)
        #expect(vm.showingDeleteConfirm == true)
        #expect(vm.pendingDeleteEnvVarID == firstVar.id)
    }

    @Test("cancelDeleteEnvVar resets delete state")
    @MainActor
    func cancelDeleteEnvVarResetsState() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        guard let envID = vm.selectedEnvironmentID,
              let firstVar = vm.envVars[envID]?.first else { return }
        vm.requestDeleteEnvVar(id: firstVar.id, from: envID)
        vm.cancelDeleteEnvVar()
        #expect(vm.showingDeleteConfirm == false)
        #expect(vm.pendingDeleteEnvVarID == nil)
    }

    @Test("confirmDeleteEnvVar removes the var from the environment")
    @MainActor
    func confirmDeleteEnvVarRemovesVar() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        guard let envID = vm.selectedEnvironmentID,
              let firstVar = vm.envVars[envID]?.first else { return }
        let countBefore = vm.envVars[envID]?.count ?? 0
        vm.requestDeleteEnvVar(id: firstVar.id, from: envID)
        vm.confirmDeleteEnvVar()
        #expect((vm.envVars[envID]?.count ?? 0) == countBefore - 1)
        #expect(vm.envVars[envID]?.contains(where: { $0.id == firstVar.id }) == false)
    }

    @Test("startEditingEnvVar sets editing state correctly for a non-secret var")
    @MainActor
    func startEditingEnvVarSetsEditingState() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        guard let envID = vm.selectedEnvironmentID,
              let plainVar = vm.envVars[envID]?.first(where: { !$0.isSecret }) else { return }
        vm.startEditingEnvVar(plainVar)
        #expect(vm.editingEnvVarID == plainVar.id)
        #expect(vm.editingKey == plainVar.key)
        #expect(vm.editingValue == plainVar.value)
    }

    @Test("cancelEditing clears all editing state")
    @MainActor
    func cancelEditingClearsEditingState() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        guard let envID = vm.selectedEnvironmentID,
              let firstVar = vm.envVars[envID]?.first else { return }
        vm.startEditingEnvVar(firstVar)
        vm.cancelEditing()
        #expect(vm.editingEnvVarID == nil)
        #expect(vm.editingKey.isEmpty)
        #expect(vm.editingValue.isEmpty)
    }
}

@Suite("ShipViewModel — Rollback Flow")
struct ShipViewModelRollbackTests {

    @Test("requestRollback sets showingRollbackConfirm to true")
    @MainActor
    func requestRollbackShowsConfirm() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        vm.requestRollback(deploymentID: "dep-1", environmentID: "env-prod")
        #expect(vm.showingRollbackConfirm == true)
        #expect(vm.pendingRollbackDeployID == "dep-1")
        #expect(vm.pendingRollbackEnvID == "env-prod")
    }

    @Test("cancelRollback resets rollback state")
    @MainActor
    func cancelRollbackResetsState() {
        let vm = ShipViewModel()
        vm.loadSampleData()
        vm.requestRollback(deploymentID: "dep-1", environmentID: "env-prod")
        vm.cancelRollback()
        #expect(vm.showingRollbackConfirm == false)
        #expect(vm.pendingRollbackDeployID == nil)
        #expect(vm.pendingRollbackEnvID == nil)
    }

    @Test("makeSampleData returns three environments")
    @MainActor
    func makeSampleDataReturnsThreeEnvironments() {
        let (envs, _, _, _, _) = ShipViewModel.makeSampleData()
        #expect(envs.count == 3)
    }

    @Test("makeSampleData environments have unique IDs")
    @MainActor
    func makeSampleDataEnvironmentsHaveUniqueIDs() {
        let (envs, _, _, _, _) = ShipViewModel.makeSampleData()
        let ids = envs.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("makeSampleData deployments are non-empty")
    @MainActor
    func makeSampleDataDeploymentsNonEmpty() {
        let (_, deploys, _, _, _) = ShipViewModel.makeSampleData()
        #expect(!deploys.isEmpty)
    }
}

// MARK: - EditorViewModel

@Suite("EditorViewModel — Initial State")
struct EditorViewModelInitialStateTests {

    @Test("openFiles is empty on init")
    @MainActor
    func openFilesEmptyOnInit() {
        let vm = EditorViewModel()
        #expect(vm.openFiles.isEmpty)
    }

    @Test("selectedFileId is nil on init")
    @MainActor
    func selectedFileIdNilOnInit() {
        let vm = EditorViewModel()
        #expect(vm.selectedFileId == nil)
    }

    @Test("selectedFile is nil when openFiles is empty")
    @MainActor
    func selectedFileNilWhenNoFiles() {
        let vm = EditorViewModel()
        #expect(vm.selectedFile == nil)
    }

    @Test("isWordWrapEnabled defaults to false")
    @MainActor
    func isWordWrapEnabledDefaultsFalse() {
        let vm = EditorViewModel()
        #expect(vm.isWordWrapEnabled == false)
    }

    @Test("isFindBarVisible defaults to false")
    @MainActor
    func isFindBarVisibleDefaultsFalse() {
        let vm = EditorViewModel()
        #expect(vm.isFindBarVisible == false)
    }

    @Test("tabSize defaults to four")
    @MainActor
    func tabSizeDefaultsFour() {
        let vm = EditorViewModel()
        #expect(vm.tabSize == 4)
    }

    @Test("isSymbolOutlineVisible defaults to true")
    @MainActor
    func isSymbolOutlineVisibleDefaultsTrue() {
        let vm = EditorViewModel()
        #expect(vm.isSymbolOutlineVisible == true)
    }
}

@Suite("EditorViewModel — File Management")
struct EditorViewModelFileTests {

    private func makeFile(name: String = "Test.swift", path: String = "/tmp/Test.swift") -> EditorFile {
        EditorFile(name: name, path: path, content: "// hello", language: "swift")
    }

    @Test("closeFile removes file from openFiles")
    @MainActor
    func closeFileRemovesFromOpenFiles() {
        let vm = EditorViewModel()
        let file = makeFile()
        vm.openFiles.append(file)
        vm.selectedFileId = file.id
        vm.closeFile(file.id)
        #expect(vm.openFiles.isEmpty)
    }

    @Test("closeFile clears selectedFileId when closing selected file and no others remain")
    @MainActor
    func closeFileSelectedFileWithNoRemaining() {
        let vm = EditorViewModel()
        let file = makeFile()
        vm.openFiles.append(file)
        vm.selectedFileId = file.id
        vm.closeFile(file.id)
        #expect(vm.selectedFileId == nil)
    }

    @Test("closeFile falls back to first remaining file when another file is open")
    @MainActor
    func closeFileFallsBackToFirstRemaining() {
        let vm = EditorViewModel()
        let fileA = makeFile(name: "A.swift", path: "/tmp/A.swift")
        let fileB = makeFile(name: "B.swift", path: "/tmp/B.swift")
        vm.openFiles = [fileA, fileB]
        vm.selectedFileId = fileA.id
        vm.closeFile(fileA.id)
        #expect(vm.selectedFileId == fileB.id)
    }

    @Test("selectFile updates selectedFileId")
    @MainActor
    func selectFileUpdatesSelectedFileId() {
        let vm = EditorViewModel()
        let fileA = makeFile(name: "A.swift", path: "/tmp/A.swift")
        let fileB = makeFile(name: "B.swift", path: "/tmp/B.swift")
        vm.openFiles = [fileA, fileB]
        vm.selectFile(fileB.id)
        #expect(vm.selectedFileId == fileB.id)
    }

    @Test("selectFile resets cursorLine and cursorColumn to 1")
    @MainActor
    func selectFileResetsCursor() {
        let vm = EditorViewModel()
        let file = makeFile()
        vm.openFiles = [file]
        vm.cursorLine = 42
        vm.cursorColumn = 10
        vm.selectFile(file.id)
        #expect(vm.cursorLine == 1)
        #expect(vm.cursorColumn == 1)
    }

    @Test("toggleWordWrap flips isWordWrapEnabled")
    @MainActor
    func toggleWordWrapFlipsValue() {
        let vm = EditorViewModel()
        #expect(vm.isWordWrapEnabled == false)
        vm.toggleWordWrap()
        #expect(vm.isWordWrapEnabled == true)
        vm.toggleWordWrap()
        #expect(vm.isWordWrapEnabled == false)
    }

    @Test("cycleWhitespace advances through all modes and wraps back to none")
    @MainActor
    func cycleWhitespaceAdvancesAndWraps() {
        let vm = EditorViewModel()
        #expect(vm.whitespaceMode == .none)
        vm.cycleWhitespace()
        #expect(vm.whitespaceMode == .boundary)
        vm.cycleWhitespace()
        #expect(vm.whitespaceMode == .all)
        vm.cycleWhitespace()
        #expect(vm.whitespaceMode == .none)
    }

    @Test("toggleReadOnly adds fileId to readOnlyFileIds")
    @MainActor
    func toggleReadOnlyAddsId() {
        let vm = EditorViewModel()
        let file = makeFile()
        vm.openFiles = [file]
        vm.toggleReadOnly(for: file.id)
        #expect(vm.readOnlyFileIds.contains(file.id))
    }

    @Test("toggleReadOnly removes fileId when already read-only")
    @MainActor
    func toggleReadOnlyRemovesId() {
        let vm = EditorViewModel()
        let file = makeFile()
        vm.openFiles = [file]
        vm.toggleReadOnly(for: file.id)
        vm.toggleReadOnly(for: file.id)
        #expect(!vm.readOnlyFileIds.contains(file.id))
    }

    @Test("isSelectedFileReadOnly returns false when no file is selected")
    @MainActor
    func isSelectedFileReadOnlyFalseWhenNoSelection() {
        let vm = EditorViewModel()
        vm.selectedFileId = nil
        #expect(vm.isSelectedFileReadOnly == false)
    }

    @Test("navigateToSymbol updates cursorLine")
    @MainActor
    func navigateToSymbolUpdatesCursorLine() {
        let vm = EditorViewModel()
        let symbol = EditorSymbol(name: "myFunc", kind: .function, line: 55)
        vm.navigateToSymbol(symbol)
        #expect(vm.cursorLine == 55)
    }
}

// MARK: - DatabaseViewModel

@Suite("DatabaseViewModel — Initial State")
struct DatabaseViewModelInitialStateTests {

    @Test("tables is empty on init")
    @MainActor
    func tablesEmptyOnInit() {
        let vm = DatabaseViewModel()
        #expect(vm.tables.isEmpty)
    }

    @Test("views is empty on init")
    @MainActor
    func viewsEmptyOnInit() {
        let vm = DatabaseViewModel()
        #expect(vm.views.isEmpty)
    }

    @Test("isConnected is false on init")
    @MainActor
    func isConnectedFalseOnInit() {
        let vm = DatabaseViewModel()
        #expect(vm.isConnected == false)
    }

    @Test("queryText is empty on init")
    @MainActor
    func queryTextEmptyOnInit() {
        let vm = DatabaseViewModel()
        #expect(vm.queryText.isEmpty)
    }

    @Test("queryResult is nil on init")
    @MainActor
    func queryResultNilOnInit() {
        let vm = DatabaseViewModel()
        #expect(vm.queryResult == nil)
    }

    @Test("isRunningQuery is false on init")
    @MainActor
    func isRunningQueryFalseOnInit() {
        let vm = DatabaseViewModel()
        #expect(vm.isRunningQuery == false)
    }

    @Test("queryHistory is empty on init")
    @MainActor
    func queryHistoryEmptyOnInit() {
        let vm = DatabaseViewModel()
        #expect(vm.queryHistory.isEmpty)
    }
}

@Suite("DatabaseViewModel — State Mutations")
struct DatabaseViewModelMutationTests {

    @Test("selectHistoryEntry updates queryText")
    @MainActor
    func selectHistoryEntryUpdatesQueryText() {
        let vm = DatabaseViewModel()
        let entry = QueryHistoryEntry(sql: "SELECT * FROM users", timestamp: Date(), executionTimeMs: nil, rowCount: nil, error: nil)
        vm.selectHistoryEntry(entry)
        #expect(vm.queryText == "SELECT * FROM users")
    }

    @Test("clearResults resets queryResult, page, and sort state")
    @MainActor
    func clearResultsResetsPaginationState() {
        let vm = DatabaseViewModel()
        vm.currentPage = 3
        vm.totalRowCount = 200
        vm.sortColumn = "id"
        vm.clearResults()
        #expect(vm.queryResult == nil)
        #expect(vm.currentPage == 0)
        #expect(vm.totalRowCount == 0)
        #expect(vm.sortColumn == nil)
    }

    @Test("resetEditor clears queryText and errorMessage")
    @MainActor
    func resetEditorClearsQueryTextAndError() {
        let vm = DatabaseViewModel()
        vm.queryText = "SELECT 1"
        vm.errorMessage = "Something went wrong"
        vm.resetEditor()
        #expect(vm.queryText.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test("toggleTable adds id to expandedTableIds when not present")
    @MainActor
    func toggleTableExpandsId() {
        let vm = DatabaseViewModel()
        vm.toggleTable("users")
        #expect(vm.expandedTableIds.contains("users"))
    }

    @Test("toggleTable removes id from expandedTableIds when already present")
    @MainActor
    func toggleTableCollapsesId() {
        let vm = DatabaseViewModel()
        vm.expandedTableIds.insert("users")
        vm.toggleTable("users")
        #expect(!vm.expandedTableIds.contains("users"))
    }

    @Test("totalPages returns 1 when totalRowCount is zero")
    @MainActor
    func totalPagesIsOneWhenEmpty() {
        let vm = DatabaseViewModel()
        #expect(vm.totalPages == 1)
    }

    @Test("totalPages calculates correctly for page-aligned row count")
    @MainActor
    func totalPagesAligned() {
        let vm = DatabaseViewModel()
        vm.totalRowCount = 100  // exactly 2 pages at pageSize 50
        #expect(vm.totalPages == 2)
    }

    @Test("totalPages rounds up for non-aligned row count")
    @MainActor
    func totalPagesRoundsUp() {
        let vm = DatabaseViewModel()
        vm.totalRowCount = 51  // 51 rows at pageSize 50 needs 2 pages
        #expect(vm.totalPages == 2)
    }

    @Test("canExportResults is false when queryResult is nil")
    @MainActor
    func canExportResultsFalseWhenNil() {
        let vm = DatabaseViewModel()
        #expect(vm.canExportResults == false)
    }

    @Test("resultRows returns empty when queryResult is nil")
    @MainActor
    func resultRowsEmptyWhenNilResult() {
        let vm = DatabaseViewModel()
        #expect(vm.resultRows.isEmpty)
    }
}

// MARK: - GitHubPRViewModel

@Suite("GitHubPRViewModel — Initial State")
struct GitHubPRViewModelInitialStateTests {

    @Test("pullRequests is empty on init")
    @MainActor
    func pullRequestsEmptyOnInit() {
        let vm = GitHubPRViewModel()
        #expect(vm.pullRequests.isEmpty)
    }

    @Test("selectedPR is nil on init")
    @MainActor
    func selectedPRNilOnInit() {
        let vm = GitHubPRViewModel()
        #expect(vm.selectedPR == nil)
    }

    @Test("isLoading is false on init")
    @MainActor
    func isLoadingFalseOnInit() {
        let vm = GitHubPRViewModel()
        #expect(vm.isLoading == false)
    }

    @Test("isMerging is false on init")
    @MainActor
    func isMergingFalseOnInit() {
        let vm = GitHubPRViewModel()
        #expect(vm.isMerging == false)
    }

    @Test("selectedMergeStrategy defaults to squash")
    @MainActor
    func selectedMergeStrategyDefaultsToSquash() {
        let vm = GitHubPRViewModel()
        #expect(vm.selectedMergeStrategy == .squash)
    }

    @Test("repoFullName is empty on init")
    @MainActor
    func repoFullNameEmptyOnInit() {
        let vm = GitHubPRViewModel()
        #expect(vm.repoFullName.isEmpty)
    }
}

@Suite("GitHubPRViewModel — Computed Properties and Mutations")
struct GitHubPRViewModelComputedTests {

    private func makePR(
        id: String,
        number: Int,
        status: PRStatus = .open,
        isDraft: Bool = false
    ) -> PullRequest {
        PullRequest(
            id: id,
            number: number,
            title: "PR \(number)",
            status: status,
            sourceBranch: "feature/x",
            targetBranch: "main",
            author: "alice",
            isDraft: isDraft
        )
    }

    @Test("openPRs filters to open status only")
    @MainActor
    func openPRsFiltersToOpenOnly() {
        let vm = GitHubPRViewModel()
        vm.pullRequests = [
            makePR(id: "1", number: 1, status: .open),
            makePR(id: "2", number: 2, status: .merged),
            makePR(id: "3", number: 3, status: .open),
        ]
        #expect(vm.openPRs.count == 2)
        #expect(vm.openPRs.allSatisfy { $0.status == .open })
    }

    @Test("draftPRs filters to isDraft true only")
    @MainActor
    func draftPRsFiltersToIsDraft() {
        let vm = GitHubPRViewModel()
        vm.pullRequests = [
            makePR(id: "1", number: 1, isDraft: true),
            makePR(id: "2", number: 2, isDraft: false),
        ]
        #expect(vm.draftPRs.count == 1)
        #expect(vm.draftPRs[0].isDraft == true)
    }

    @Test("readyPRs excludes draft PRs")
    @MainActor
    func readyPRsExcludesDrafts() {
        let vm = GitHubPRViewModel()
        vm.pullRequests = [
            makePR(id: "1", number: 1, status: .open, isDraft: false),
            makePR(id: "2", number: 2, status: .open, isDraft: true),
        ]
        #expect(vm.readyPRs.count == 1)
        #expect(vm.readyPRs[0].isDraft == false)
    }

    @Test("clearSelection resets selectedPR, prComments, and ciChecks")
    @MainActor
    func clearSelectionResetsState() {
        let vm = GitHubPRViewModel()
        vm.selectedPR = makePR(id: "1", number: 1)
        vm.prComments = [PRComment(id: "c1", author: "bob", body: "Nice")]
        vm.ciChecks = [CICheck(id: "ci1", name: "Build", status: .completed, conclusion: .success)]
        vm.clearSelection()
        #expect(vm.selectedPR == nil)
        #expect(vm.prComments.isEmpty)
        #expect(vm.ciChecks.isEmpty)
    }

    @Test("ciSummary counts passed, failed, and pending checks correctly")
    @MainActor
    func ciSummaryCountsCorrectly() {
        let vm = GitHubPRViewModel()
        vm.ciChecks = [
            CICheck(id: "1", name: "Lint", status: .completed, conclusion: .success),
            CICheck(id: "2", name: "Tests", status: .completed, conclusion: .failure),
            CICheck(id: "3", name: "Build", status: .inProgress, conclusion: nil),
        ]
        let summary = vm.ciSummary
        #expect(summary.passed == 1)
        #expect(summary.failed == 1)
        #expect(summary.pending == 1)
    }

    @Test("canMerge is false when no PR is selected")
    @MainActor
    func canMergeFalseWhenNoPR() {
        let vm = GitHubPRViewModel()
        vm.selectedPR = nil
        #expect(vm.canMerge == false)
    }

    @Test("canMerge is false for a draft PR")
    @MainActor
    func canMergeFalseForDraft() {
        let vm = GitHubPRViewModel()
        vm.selectedPR = makePR(id: "1", number: 1, status: .open, isDraft: true)
        #expect(vm.canMerge == false)
    }

    @Test("toggleThread adds threadId to expandedThreads")
    @MainActor
    func toggleThreadAddsToExpanded() {
        let vm = GitHubPRViewModel()
        vm.toggleThread("thread-1")
        #expect(vm.expandedThreads.contains("thread-1"))
    }

    @Test("toggleThread removes threadId when already expanded")
    @MainActor
    func toggleThreadRemovesWhenExpanded() {
        let vm = GitHubPRViewModel()
        vm.expandedThreads.insert("thread-1")
        vm.toggleThread("thread-1")
        #expect(!vm.expandedThreads.contains("thread-1"))
    }

    @Test("unresolveThread removes threadId from resolvedThreads")
    @MainActor
    func unresolveThreadRemovesFromResolved() {
        let vm = GitHubPRViewModel()
        vm.resolvedThreads.insert("thread-xyz")
        vm.unresolveThread("thread-xyz")
        #expect(!vm.resolvedThreads.contains("thread-xyz"))
    }

    @Test("needsUpdate is false when no PR is selected")
    @MainActor
    func needsUpdateFalseWhenNoPR() {
        let vm = GitHubPRViewModel()
        vm.selectedPR = nil
        #expect(vm.needsUpdate == false)
    }
}

// MARK: - ObservabilityViewModel

@Suite("ObservabilityViewModel — Initial State")
struct ObservabilityViewModelInitialStateTests {

    @Test("errors is empty on init")
    @MainActor
    func errorsEmptyOnInit() {
        let vm = ObservabilityViewModel()
        #expect(vm.errors.isEmpty)
    }

    @Test("metrics is empty on init")
    @MainActor
    func metricsEmptyOnInit() {
        let vm = ObservabilityViewModel()
        #expect(vm.metrics.isEmpty)
    }

    @Test("isConnected is false on init")
    @MainActor
    func isConnectedFalseOnInit() {
        let vm = ObservabilityViewModel()
        #expect(vm.isConnected == false)
    }

    @Test("selectedTab defaults to errors")
    @MainActor
    func selectedTabDefaultsToErrors() {
        let vm = ObservabilityViewModel()
        #expect(vm.selectedTab == .errors)
    }

    @Test("usingDemoData is false on init")
    @MainActor
    func usingDemoDataFalseOnInit() {
        let vm = ObservabilityViewModel()
        #expect(vm.usingDemoData == false)
    }

    @Test("selectedErrorID is nil on init")
    @MainActor
    func selectedErrorIDNilOnInit() {
        let vm = ObservabilityViewModel()
        #expect(vm.selectedErrorID == nil)
    }
}

@Suite("ObservabilityViewModel — Demo Data and Computed Properties")
struct ObservabilityViewModelDataTests {

    @Test("loadDemoData populates errors")
    @MainActor
    func loadDemoDataPopulatesErrors() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        #expect(!vm.errors.isEmpty)
    }

    @Test("loadDemoData populates metrics")
    @MainActor
    func loadDemoDataPopulatesMetrics() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        #expect(!vm.metrics.isEmpty)
    }

    @Test("loadDemoData sets usingDemoData to true")
    @MainActor
    func loadDemoDataSetsUsingDemoData() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        #expect(vm.usingDemoData == true)
    }

    @Test("loadDemoData sets selectedErrorID to first error")
    @MainActor
    func loadDemoDataSetsSelectedError() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        #expect(vm.selectedErrorID == vm.errors.first?.id)
    }

    @Test("selectedError resolves to correct item")
    @MainActor
    func selectedErrorResolvesCorrectly() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        let target = vm.errors[1]
        vm.selectedErrorID = target.id
        #expect(vm.selectedError?.id == target.id)
    }

    @Test("selectedError is nil when selectedErrorID is nil")
    @MainActor
    func selectedErrorNilWhenNoSelection() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        vm.selectedErrorID = nil
        #expect(vm.selectedError == nil)
    }

    @Test("criticalCount counts only critical severity errors")
    @MainActor
    func criticalCountOnlyCritical() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        let expected = vm.errors.filter { $0.severity == .critical }.count
        #expect(vm.criticalCount == expected)
    }

    @Test("selectError updates selectedErrorID")
    @MainActor
    func selectErrorUpdatesSelectedErrorID() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        let target = vm.errors[0]
        vm.usingDemoData = true  // prevent async detail fetch
        vm.selectError(target.id)
        #expect(vm.selectedErrorID == target.id)
    }

    @Test("disconnect clears errors, metrics, and resets all flags")
    @MainActor
    func disconnectClearsState() {
        let vm = ObservabilityViewModel()
        vm.loadDemoData()
        vm.disconnect()
        #expect(vm.errors.isEmpty)
        #expect(vm.metrics.isEmpty)
        #expect(vm.isConnected == false)
        #expect(vm.usingDemoData == false)
        #expect(vm.selectedErrorID == nil)
    }

    @Test("makeSampleData returns non-empty errors and metrics")
    @MainActor
    func makeSampleDataNonEmpty() {
        let (errors, metrics) = ObservabilityViewModel.makeSampleData()
        #expect(!errors.isEmpty)
        #expect(!metrics.isEmpty)
    }

    @Test("makeSampleTrend returns exactly 24 data points")
    @MainActor
    func makeSampleTrendReturns24Points() {
        let trend = ObservabilityViewModel.makeSampleTrend()
        #expect(trend.count == 24)
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
