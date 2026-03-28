import XCTest
@testable import AnvilUI
import AnvilDomain

@MainActor
final class AgentViewModelTests: XCTestCase {

    // MARK: - Init

    func testInitHasNoSessions() {
        let vm = AgentViewModel()
        XCTAssertTrue(vm.sessions.isEmpty, "AgentViewModel must start with no sessions")
    }

    func testInitHasNoSelectedSession() {
        let vm = AgentViewModel()
        XCTAssertNil(vm.selectedSessionId, "AgentViewModel must start with no selected session")
    }

    func testInitDefaultsToSonnet() {
        let vm = AgentViewModel()
        XCTAssertEqual(vm.selectedModelId, "claude-sonnet-4-6", "AgentViewModel must default to claude-sonnet-4-6")
    }

    // MARK: - startNewSession

    func testStartNewSessionIncreasesCount() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        XCTAssertEqual(vm.sessions.count, 1, "startNewSession must create one session")
    }

    func testStartNewSessionMultipleTimesIncreasesCount() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        vm.startNewSession(prompt: "", model: "claude-opus-4-6")
        XCTAssertEqual(vm.sessions.count, 3, "Each startNewSession call must create a new session")
    }

    func testStartNewSessionSetsSelectedID() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        XCTAssertNotNil(vm.selectedSessionId, "startNewSession must set selectedSessionId")
        XCTAssertEqual(vm.selectedSessionId, vm.sessions.first?.id,
            "selectedSessionId must match the newly created session")
    }

    func testStartNewSessionSetsModel() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-opus-4-6")
        XCTAssertEqual(vm.sessions.first?.model, "claude-opus-4-6",
            "startNewSession must store the given model on the session")
    }

    func testStartNewSessionUpdatesSelectedModelId() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-haiku-4-5-20251001")
        XCTAssertEqual(vm.selectedModelId, "claude-haiku-4-5-20251001",
            "startNewSession must update selectedModelId to match new session's model")
    }

    func testStartNewSessionInsertsAtFront() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let firstId = vm.sessions.first!.id
        vm.startNewSession(prompt: "", model: "claude-opus-4-6")
        XCTAssertNotEqual(vm.sessions.first!.id, firstId,
            "startNewSession must insert new session at front (index 0)")
    }

    func testStartNewSessionCreatesIdleStatus() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        XCTAssertEqual(vm.sessions.first?.status, .idle,
            "New session must have idle status")
    }

    // MARK: - selectedSession

    func testSelectedSessionMatchesID() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.selectedSessionId = id
        XCTAssertEqual(vm.selectedSession?.id, id, "selectedSession must return session matching selectedSessionId")
    }

    func testSelectedSessionNilWhenNoSelection() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        vm.selectedSessionId = nil
        XCTAssertNil(vm.selectedSession, "selectedSession must be nil when selectedSessionId is nil")
    }

    func testSelectedSessionNilWithInvalidId() {
        let vm = AgentViewModel()
        vm.selectedSessionId = "does-not-exist"
        XCTAssertNil(vm.selectedSession, "selectedSession must be nil for invalid id")
    }

    // MARK: - deleteSession

    func testDeleteSessionRemovesIt() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.deleteSession(id)
        XCTAssertFalse(vm.sessions.contains(where: { $0.id == id }),
            "deleteSession must remove the session from the list")
    }

    func testDeleteSessionClearsSelectionWhenSelected() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.selectedSessionId = id
        vm.deleteSession(id)
        XCTAssertNil(vm.selectedSessionId, "deleteSession must clear selectedSessionId when deleted session was selected")
    }

    func testDeleteSessionSelectsNextWhenMultipleExist() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let toDelete = vm.sessions.first!.id
        vm.selectedSessionId = toDelete
        vm.deleteSession(toDelete)
        // Should select a remaining session
        XCTAssertNotNil(vm.selectedSessionId, "Deleting selected session must select another when one exists")
    }

    func testDeleteSessionPreservesOtherSessions() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let keep = vm.sessions.last!.id
        let del = vm.sessions.first!.id
        vm.deleteSession(del)
        XCTAssertTrue(vm.sessions.contains(where: { $0.id == keep }),
            "deleteSession must preserve other sessions")
    }

    func testDeleteNonSelectedSessionPreservesSelection() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let selected = vm.sessions.first!.id
        vm.selectedSessionId = selected
        let other = vm.sessions.last!.id
        vm.deleteSession(other)
        XCTAssertEqual(vm.selectedSessionId, selected,
            "Deleting an unselected session must not change current selection")
    }

    // MARK: - renameSession

    func testRenameSessionUpdatesCustomName() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.renameSession(id, name: "My Auth Fix Session")
        XCTAssertEqual(vm.sessions.first?.customName, "My Auth Fix Session",
            "renameSession must update customName")
    }

    func testRenameSessionUpdatesDisplayName() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.renameSession(id, name: "Custom Name")
        XCTAssertEqual(vm.sessions.first?.displayName, "Custom Name",
            "displayName must use customName when set")
    }

    func testRenameSessionIgnoresUnknownId() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        vm.renameSession("no-such-id", name: "Ghost")
        XCTAssertNil(vm.sessions.first?.customName, "renameSession must ignore unknown IDs")
    }

    // MARK: - updateSessionModel

    func testUpdateSessionModelChangesModel() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.updateSessionModel(id, modelId: "claude-opus-4-6")
        XCTAssertEqual(vm.sessions.first?.model, "claude-opus-4-6",
            "updateSessionModel must change the session's model")
    }

    // MARK: - setSessionBudget

    func testSetSessionBudgetStoresBudget() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.setSessionBudget(id, budget: Decimal(5.0), hardStop: true)
        XCTAssertEqual(vm.sessions.first?.costBudget, Decimal(5.0),
            "setSessionBudget must store the budget value")
        XCTAssertTrue(vm.sessions.first?.hardStopOnBudget == true,
            "setSessionBudget must store hardStop flag")
    }

    func testSetSessionBudgetNilClearsBudget() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.setSessionBudget(id, budget: Decimal(5.0), hardStop: false)
        vm.setSessionBudget(id, budget: nil, hardStop: false)
        XCTAssertNil(vm.sessions.first?.costBudget, "setSessionBudget(nil) must clear the budget")
    }

    // MARK: - Context Attachments

    func testAddAttachmentIncreasesCount() {
        let vm = AgentViewModel()
        let att = ContextAttachment(id: "att-1", type: .file, title: "main.swift", content: "let x = 1")
        vm.addAttachment(att)
        XCTAssertEqual(vm.contextAttachments.count, 1, "addAttachment must add one attachment")
    }

    func testAddAttachmentIgnoresDuplicates() {
        let vm = AgentViewModel()
        let att = ContextAttachment(id: "att-1", type: .file, title: "main.swift", content: "let x = 1")
        vm.addAttachment(att)
        vm.addAttachment(att)
        XCTAssertEqual(vm.contextAttachments.count, 1, "addAttachment must not add duplicate attachments")
    }

    func testRemoveAttachmentDecreasesCount() {
        let vm = AgentViewModel()
        let att = ContextAttachment(id: "att-1", type: .file, title: "file.swift", content: "")
        vm.addAttachment(att)
        vm.removeAttachment(id: "att-1")
        XCTAssertTrue(vm.contextAttachments.isEmpty, "removeAttachment must remove the attachment")
    }

    func testClearAttachmentsRemovesAll() {
        let vm = AgentViewModel()
        vm.addAttachment(ContextAttachment(id: "a1", type: .file, title: "f1.swift", content: ""))
        vm.addAttachment(ContextAttachment(id: "a2", type: .file, title: "f2.swift", content: ""))
        vm.clearAttachments()
        XCTAssertTrue(vm.contextAttachments.isEmpty, "clearAttachments must remove all attachments")
    }

    // MARK: - dispatchFromTicket

    func testDispatchFromTicketCreatesSession() {
        let vm = AgentViewModel()
        vm.dispatchFromTicket(ticketId: "ANV-101", title: "Fix auth bug", description: "Details")
        XCTAssertEqual(vm.sessions.count, 1, "dispatchFromTicket must create one session")
    }

    func testDispatchFromTicketStoresWorkItemId() {
        let vm = AgentViewModel()
        vm.dispatchFromTicket(ticketId: "ANV-101", title: "Fix auth bug", description: "Details")
        XCTAssertEqual(vm.sessions.first?.workItemId, "ANV-101",
            "dispatchFromTicket must store the ticket ID as workItemId")
    }

    func testDispatchFromTicketSelectsSession() {
        let vm = AgentViewModel()
        vm.dispatchFromTicket(ticketId: "ANV-101", title: "Fix auth bug", description: "")
        XCTAssertEqual(vm.selectedSessionId, vm.sessions.first?.id,
            "dispatchFromTicket must select the new session")
    }

    func testDispatchFromTicketPopulatesContextMessage() {
        let vm = AgentViewModel()
        vm.dispatchFromTicket(ticketId: "ANV-101", title: "Fix auth bug", description: "Auth is broken")
        XCTAssertFalse(vm.sessions.first?.messages.isEmpty == true,
            "dispatchFromTicket must add an initial context message to the session")
    }

    func testDispatchFromTicketMessageContainsTicketId() {
        let vm = AgentViewModel()
        vm.dispatchFromTicket(ticketId: "ANV-101", title: "Fix auth bug", description: "Details")
        let firstMessage = vm.sessions.first?.messages.first
        XCTAssertTrue(firstMessage?.content.contains("ANV-101") == true,
            "Dispatched session message must reference the ticket ID")
    }

    func testDispatchFromTicketMessageContainsTitle() {
        let vm = AgentViewModel()
        vm.dispatchFromTicket(ticketId: "ANV-101", title: "Fix auth bug", description: "")
        let firstMessage = vm.sessions.first?.messages.first
        XCTAssertTrue(firstMessage?.content.contains("Fix auth bug") == true,
            "Dispatched session message must contain the ticket title")
    }

    func testDispatchFromTicketUsesCustomModel() {
        let vm = AgentViewModel()
        vm.dispatchFromTicket(ticketId: "ANV-101", title: "Fix bug", description: "", model: "claude-opus-4-6")
        XCTAssertEqual(vm.sessions.first?.model, "claude-opus-4-6",
            "dispatchFromTicket must use the provided model")
    }

    // MARK: - exportSession

    func testExportSessionReturnsNonEmptyString() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        let exported = vm.exportSession(id)
        XCTAssertFalse(exported.isEmpty, "exportSession must return non-empty markdown string")
    }

    func testExportSessionContainsModel() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-opus-4-6")
        let id = vm.sessions.first!.id
        let exported = vm.exportSession(id)
        XCTAssertTrue(exported.contains("claude-opus-4-6"),
            "Exported session must include the model name")
    }

    func testExportSessionReturnsEmptyForUnknownId() {
        let vm = AgentViewModel()
        let exported = vm.exportSession("non-existent-id")
        XCTAssertTrue(exported.isEmpty, "exportSession must return empty string for unknown session ID")
    }

    func testExportSessionJSONReturnsNonNilData() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        let data = vm.exportSessionJSON(id)
        XCTAssertNotNil(data, "exportSessionJSON must return non-nil Data for a valid session")
    }

    // MARK: - displayName

    func testDisplayNameUsesCustomNameWhenSet() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let id = vm.sessions.first!.id
        vm.renameSession(id, name: "My Custom Name")
        XCTAssertEqual(vm.sessions.first?.displayName, "My Custom Name")
    }

    func testDisplayNameFallsBackToSessionLabel() {
        let vm = AgentViewModel()
        vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
        let name = vm.sessions.first!.displayName
        XCTAssertFalse(name.isEmpty, "displayName must never be empty")
    }
}
