import XCTest
@testable import AnvilUI
@testable import AnvilTerminal

/// XCTest coverage for TerminalViewModel tab management:
/// - addTab creates session and sets it active
/// - closeTab removes session, falls back to last
/// - selectTab switches activeSessionId
/// - session(with:) lookup
/// - Multiple tabs lifecycle
@MainActor
final class TerminalViewModelTabTests: XCTestCase {

    var vm: TerminalViewModel!

    override func setUp() {
        vm = TerminalViewModel()
    }

    override func tearDown() {
        vm = nil
    }

    // MARK: - Initial state

    func testInitialSessionsAreEmpty() {
        XCTAssertTrue(vm.sessions.isEmpty)
    }

    func testInitialSelectedSessionIsNil() {
        XCTAssertNil(vm.selectedSession)
    }

    func testInitialSelectedSessionIdIsNil() {
        XCTAssertNil(vm.selectedSessionId)
    }

    // MARK: - addTab

    func testAddTabCreatesSession() {
        vm.addTab()
        XCTAssertEqual(vm.sessions.count, 1)
    }

    func testAddTabSetsSessionActive() {
        let session = vm.addTab()
        XCTAssertEqual(vm.selectedSessionId, session.id)
    }

    func testAddTabReturnsSession() {
        let session = vm.addTab()
        XCTAssertNotNil(session)
    }

    func testAddTabTwiceCreatesTwoSessions() {
        vm.addTab()
        vm.addTab()
        XCTAssertEqual(vm.sessions.count, 2)
    }

    func testAddTabActivatesLatestSession() {
        vm.addTab()
        let second = vm.addTab()
        XCTAssertEqual(vm.selectedSessionId, second.id)
    }

    func testAddTabSelectedSessionMatchesId() {
        let session = vm.addTab()
        XCTAssertEqual(vm.selectedSession?.id, session.id)
    }

    // MARK: - closeTab

    func testCloseTabRemovesSession() {
        let session = vm.addTab()
        vm.closeTab(session.id)
        XCTAssertTrue(vm.sessions.isEmpty)
    }

    func testCloseTabClearsActiveWhenLast() {
        let session = vm.addTab()
        vm.closeTab(session.id)
        XCTAssertNil(vm.selectedSessionId)
    }

    func testCloseTabFallsBackToLastSession() {
        let first = vm.addTab()
        let second = vm.addTab()
        _ = vm.addTab() // third, currently active

        // Close the active (third) → should fall back to second
        vm.closeTab(vm.selectedSessionId!)
        XCTAssertEqual(vm.selectedSessionId, second.id)
    }

    func testCloseNonActiveTabPreservesActiveSession() {
        let first = vm.addTab()
        let second = vm.addTab()
        // second is active; close first
        vm.closeTab(first.id)
        XCTAssertEqual(vm.selectedSessionId, second.id)
        XCTAssertEqual(vm.sessions.count, 1)
    }

    func testCloseTabWithUnknownIdIsSafe() {
        vm.addTab()
        let unknownId = UUID()
        vm.closeTab(unknownId) // must not crash
        XCTAssertEqual(vm.sessions.count, 1)
    }

    func testCloseTabReducesCount() {
        let a = vm.addTab()
        let b = vm.addTab()
        let c = vm.addTab()
        vm.closeTab(b.id)
        XCTAssertEqual(vm.sessions.count, 2)
        XCTAssertFalse(vm.sessions.contains { $0.id == b.id })
        XCTAssertTrue(vm.sessions.contains { $0.id == a.id })
        XCTAssertTrue(vm.sessions.contains { $0.id == c.id })
    }

    // MARK: - selectTab

    func testSelectTabSwitchesActiveId() {
        let first = vm.addTab()
        vm.addTab() // second is now active
        vm.selectTab(first.id)
        XCTAssertEqual(vm.selectedSessionId, first.id)
    }

    func testSelectTabUpdatesSelectedSession() {
        let first = vm.addTab()
        vm.addTab()
        vm.selectTab(first.id)
        XCTAssertEqual(vm.selectedSession?.id, first.id)
    }

    func testSelectTabDoesNotChangeSessionCount() {
        let first = vm.addTab()
        vm.addTab()
        vm.selectTab(first.id)
        XCTAssertEqual(vm.sessions.count, 2)
    }

    func testSelectTabCycleThroughAll() {
        let a = vm.addTab()
        let b = vm.addTab()
        let c = vm.addTab()

        vm.selectTab(a.id)
        XCTAssertEqual(vm.selectedSessionId, a.id)

        vm.selectTab(b.id)
        XCTAssertEqual(vm.selectedSessionId, b.id)

        vm.selectTab(c.id)
        XCTAssertEqual(vm.selectedSessionId, c.id)
    }

    // MARK: - session(with:)

    func testSessionWithIdReturnsCorrectSession() {
        let session = vm.addTab()
        let found = vm.session(with: session.id)
        XCTAssertEqual(found?.id, session.id)
    }

    func testSessionWithNilReturnsNil() {
        vm.addTab()
        XCTAssertNil(vm.session(with: nil))
    }

    func testSessionWithUnknownIdReturnsNil() {
        vm.addTab()
        XCTAssertNil(vm.session(with: UUID()))
    }

    // MARK: - rename (via TerminalSession.title)

    func testRenameTabUpdatesTitle() {
        let session = vm.addTab()
        session.title = "my-server"
        XCTAssertEqual(vm.sessions.first?.title, "my-server")
    }

    func testRenameDoesNotChangeSessionCount() {
        let session = vm.addTab()
        vm.addTab()
        session.title = "renamed"
        XCTAssertEqual(vm.sessions.count, 2)
    }

    func testRenameOnlyChangesTargetSession() {
        let first = vm.addTab()
        let second = vm.addTab()
        first.title = "first-renamed"
        XCTAssertEqual(first.title, "first-renamed")
        XCTAssertEqual(second.title, "zsh") // default unchanged
    }

    // MARK: - configure

    func testConfigureProjectPathStored() {
        vm.configure(projectPath: "/Users/dev/myproject")
        // addTab uses the stored path — just verify configure doesn't crash
        // and a subsequent addTab picks it up (workingDirectory on session)
        let session = vm.addTab()
        XCTAssertEqual(session.workingDirectory, "/Users/dev/myproject")
    }

    func testConfigureNilPathUsesHomeDirectory() {
        vm.configure(projectPath: nil)
        let session = vm.addTab()
        // With nil projectPath, addTab falls back to homeDirectoryForCurrentUser
        XCTAssertNotNil(session.workingDirectory)
    }

    // MARK: - Multi-tab lifecycle

    func testAddThreeCloseMiddleSelectFirst() {
        let a = vm.addTab()
        let b = vm.addTab()
        let c = vm.addTab()

        vm.closeTab(b.id)
        vm.selectTab(a.id)

        XCTAssertEqual(vm.sessions.count, 2)
        XCTAssertEqual(vm.selectedSessionId, a.id)
        XCTAssertFalse(vm.sessions.contains { $0.id == b.id })
        XCTAssertTrue(vm.sessions.contains { $0.id == c.id })
    }

    func testAddManyTabsThenCloseAll() {
        let sessions = (1...5).map { _ in vm.addTab() }
        for s in sessions {
            vm.closeTab(s.id)
        }
        XCTAssertTrue(vm.sessions.isEmpty)
        XCTAssertNil(vm.selectedSessionId)
    }
}
