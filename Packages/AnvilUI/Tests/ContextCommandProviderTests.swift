import XCTest
@testable import AnvilUI
import AnvilDomain

/// XCTest coverage for ContextCommandProvider:
/// - Ticket entity → Start Work, Edit Ticket, Delete Ticket commands present
/// - File entity → Open File, Copy Path commands present
/// - AgentSession entity → Stop only shown for running/paused sessions
/// - nil entity + build space → global fallback commands
/// - nil entity + non-build space → empty fallback
@MainActor
final class ContextCommandProviderTests: XCTestCase {

    var appState: AppState!

    override func setUp() {
        appState = AppState()
    }

    override func tearDown() {
        appState = nil
    }

    // MARK: - Helpers

    private func makeTicket(id: String = "T-1", title: String = "Fix bug") -> Ticket {
        Ticket(id: id, title: title)
    }

    // MARK: - Ticket entity commands

    func testTicketEntityProvidesStartWorkCommand() {
        let ticket = makeTicket(id: "T-1", title: "Fix the crash")
        appState.intentViewModel.tickets = [ticket]
        appState.intentViewModel.selectedTicketId = "T-1"
        appState.focusedEntity = .ticket(id: "T-1", title: "Fix the crash")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Start Work" }, "Expected 'Start Work' command for ticket entity")
    }

    func testTicketEntityProvidesEditCommand() {
        let ticket = makeTicket(id: "T-2", title: "Refactor")
        appState.intentViewModel.tickets = [ticket]
        appState.intentViewModel.selectedTicketId = "T-2"
        appState.focusedEntity = .ticket(id: "T-2", title: "Refactor")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Edit Ticket" })
    }

    func testTicketEntityProvidesDeleteCommand() {
        let ticket = makeTicket(id: "T-3", title: "Remove feature")
        appState.intentViewModel.tickets = [ticket]
        appState.intentViewModel.selectedTicketId = "T-3"
        appState.focusedEntity = .ticket(id: "T-3", title: "Remove feature")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Delete Ticket" })
    }

    func testTicketEntityProvidesChangeStatusCommand() {
        let ticket = makeTicket(id: "T-4", title: "Status change")
        appState.intentViewModel.tickets = [ticket]
        appState.intentViewModel.selectedTicketId = "T-4"
        appState.focusedEntity = .ticket(id: "T-4", title: "Status change")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Change Status" })
    }

    func testTicketEntityCommandsAreAllEntityContext() {
        let ticket = makeTicket(id: "T-5", title: "Context check")
        appState.intentViewModel.tickets = [ticket]
        appState.intentViewModel.selectedTicketId = "T-5"
        appState.focusedEntity = .ticket(id: "T-5", title: "Context check")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.allSatisfy { $0.category == .entityContext })
    }

    func testTicketEntityFallsBackToBasicCommandWhenNoSelectedTicket() {
        appState.intentViewModel.tickets = []
        appState.intentViewModel.selectedTicketId = nil
        appState.focusedEntity = .ticket(id: "T-99", title: "Unknown")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertFalse(commands.isEmpty, "Should return at least basic edit command")
        XCTAssertTrue(commands.contains { $0.title == "Edit Ticket" })
    }

    // MARK: - File entity commands

    func testFileEntityProvidesOpenFileCommand() {
        appState.focusedEntity = .file(path: "/src/main.swift", name: "main.swift")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Open File" })
    }

    func testFileEntityProvidesCopyPathCommand() {
        appState.focusedEntity = .file(path: "/src/main.swift", name: "main.swift")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Copy Path" })
    }

    func testFileEntityProvidesRenameFileCommand() {
        appState.focusedEntity = .file(path: "/src/utils.swift", name: "utils.swift")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Rename File" })
    }

    func testFileEntityProvidesRunTestsCommand() {
        appState.focusedEntity = .file(path: "/Tests/MyTest.swift", name: "MyTest.swift")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Run Tests for File" })
    }

    func testFileCommandsSubtitleContainsName() {
        appState.focusedEntity = .file(path: "/src/app.swift", name: "app.swift")

        let commands = ContextCommandProvider.commands(for: appState)
        let openCmd = commands.first { $0.title == "Open File" }
        XCTAssertEqual(openCmd?.subtitle, "app.swift")
    }

    func testCopyPathCommandSubtitleIsPath() {
        appState.focusedEntity = .file(path: "/src/app.swift", name: "app.swift")

        let commands = ContextCommandProvider.commands(for: appState)
        let copyCmd = commands.first { $0.title == "Copy Path" }
        XCTAssertEqual(copyCmd?.subtitle, "/src/app.swift")
    }

    // MARK: - Agent session commands (stop only for running/paused)

    func testAgentSessionAlwaysProvidesOpenSessionCommand() {
        let session = AgentSession(id: "s1", providerId: "test", model: "test-model", status: .idle)
        appState.agentViewModel.sessions = [session]
        appState.agentViewModel.selectedSessionId = "s1"
        appState.focusedEntity = .agentSession(id: "s1", name: "My Session")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Open Session" })
    }

    func testAgentSessionStopCommandAppearsWhenRunning() {
        let session = AgentSession(id: "s2", providerId: "test", model: "test-model", status: .running)
        appState.agentViewModel.sessions = [session]
        appState.agentViewModel.selectedSessionId = "s2"
        appState.focusedEntity = .agentSession(id: "s2", name: "Running Session")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Stop Session" }, "Stop command should appear for running session")
    }

    func testAgentSessionStopCommandAppearsWhenPaused() {
        let session = AgentSession(id: "s3", providerId: "test", model: "test-model", status: .paused)
        appState.agentViewModel.sessions = [session]
        appState.agentViewModel.selectedSessionId = "s3"
        appState.focusedEntity = .agentSession(id: "s3", name: "Paused Session")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Stop Session" }, "Stop command should appear for paused session")
    }

    func testAgentSessionStopCommandHiddenWhenCompleted() {
        let session = AgentSession(id: "s4", providerId: "test", model: "test-model", status: .completed)
        appState.agentViewModel.sessions = [session]
        appState.agentViewModel.selectedSessionId = "s4"
        appState.focusedEntity = .agentSession(id: "s4", name: "Done Session")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertFalse(commands.contains { $0.title == "Stop Session" }, "Stop command should NOT appear for completed session")
    }

    func testAgentSessionStopCommandHiddenWhenFailed() {
        let session = AgentSession(id: "s5", providerId: "test", model: "test-model", status: .failed)
        appState.agentViewModel.sessions = [session]
        appState.agentViewModel.selectedSessionId = "s5"
        appState.focusedEntity = .agentSession(id: "s5", name: "Failed Session")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertFalse(commands.contains { $0.title == "Stop Session" }, "Stop command should NOT appear for failed session")
    }

    func testAgentSessionStopCommandHiddenWhenIdle() {
        let session = AgentSession(id: "s6", providerId: "test", model: "test-model", status: .idle)
        appState.agentViewModel.sessions = [session]
        appState.agentViewModel.selectedSessionId = "s6"
        appState.focusedEntity = .agentSession(id: "s6", name: "Idle Session")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertFalse(commands.contains { $0.title == "Stop Session" })
    }

    func testAgentSessionAlwaysProvidesExportCommand() {
        let session = AgentSession(id: "s7", providerId: "test", model: "test-model", status: .completed)
        appState.agentViewModel.sessions = [session]
        appState.agentViewModel.selectedSessionId = "s7"
        appState.focusedEntity = .agentSession(id: "s7", name: "Export me")

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Export Session" })
    }

    // MARK: - nil entity fallback

    func testNilEntityInBuildSpaceReturnsFallbackCommands() {
        appState.focusedEntity = nil
        appState.currentSpace = .build

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertFalse(commands.isEmpty, "Build space fallback should return commands")
    }

    func testNilEntityInBuildSpaceContainsFindInFiles() {
        appState.focusedEntity = nil
        appState.currentSpace = .build

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Find in Files" })
    }

    func testNilEntityInBuildSpaceContainsOpenTerminal() {
        appState.focusedEntity = nil
        appState.currentSpace = .build

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Open Terminal" })
    }

    func testNilEntityInBuildSpaceContainsGoToLine() {
        appState.focusedEntity = nil
        appState.currentSpace = .build

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.contains { $0.title == "Go to Line" })
    }

    func testNilEntityInPlanSpaceReturnsEmpty() {
        appState.focusedEntity = nil
        appState.currentSpace = .plan

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.isEmpty, "Plan space fallback should return empty")
    }

    func testNilEntityInReviewSpaceReturnsEmpty() {
        appState.focusedEntity = nil
        appState.currentSpace = .review

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.isEmpty)
    }

    func testNilEntityInOperateSpaceReturnsEmpty() {
        appState.focusedEntity = nil
        appState.currentSpace = .operate

        let commands = ContextCommandProvider.commands(for: appState)
        XCTAssertTrue(commands.isEmpty)
    }
}
