import XCTest
@testable import AnvilTerminal

/// XCTest coverage for TerminalSessionManager session lifecycle:
/// - createSession adds to list and sets active
/// - closeSession removes from list and falls back to last
/// - selectSession changes activeSessionId
/// - terminateAll clears everything
@MainActor
final class TerminalSessionManagerTests: XCTestCase {

    var manager: TerminalSessionManager!

    override func setUp() {
        manager = TerminalSessionManager()
    }

    override func tearDown() {
        manager = nil
    }

    // MARK: - Initial state

    func testInitialSessionsAreEmpty() {
        XCTAssertTrue(manager.sessions.isEmpty)
    }

    func testInitialActiveSessionIdIsNil() {
        XCTAssertNil(manager.activeSessionId)
    }

    func testInitialActiveSessionIsNil() {
        XCTAssertNil(manager.activeSession)
    }

    // MARK: - createSession

    func testCreateSessionAddsToList() {
        manager.createSession()
        XCTAssertEqual(manager.sessions.count, 1)
    }

    func testCreateSessionSetsActiveSessionId() {
        let session = manager.createSession()
        XCTAssertEqual(manager.activeSessionId, session.id)
    }

    func testCreateSessionReturnsSession() {
        let session = manager.createSession(title: "bash")
        XCTAssertEqual(session.title, "bash")
    }

    func testCreateMultipleSessionsAllAdded() {
        manager.createSession()
        manager.createSession()
        manager.createSession()
        XCTAssertEqual(manager.sessions.count, 3)
    }

    func testCreateSessionActivatesLatest() {
        manager.createSession(title: "first")
        let second = manager.createSession(title: "second")
        XCTAssertEqual(manager.activeSessionId, second.id)
    }

    func testCreateSessionWithWorkingDirectory() {
        let session = manager.createSession(workingDirectory: "/tmp")
        XCTAssertEqual(session.workingDirectory, "/tmp")
    }

    func testCreateSessionCustomColumns() {
        let session = manager.createSession(columns: 120, rows: 40)
        // No stored columns on TerminalSession, but createSession must not crash
        XCTAssertNotNil(session)
    }

    // MARK: - closeSession

    func testCloseSessionRemovesFromList() {
        let session = manager.createSession()
        manager.closeSession(session.id)
        XCTAssertTrue(manager.sessions.isEmpty)
    }

    func testCloseSessionFallsBackToLastSession() {
        let first = manager.createSession(title: "first")
        let second = manager.createSession(title: "second")
        _ = manager.createSession(title: "third")

        // Close the third (active), expect active to fall back to second
        manager.closeSession(manager.activeSessionId!)
        XCTAssertEqual(manager.activeSessionId, second.id)
    }

    func testCloseSessionClearsActiveWhenLast() {
        let session = manager.createSession()
        manager.closeSession(session.id)
        XCTAssertNil(manager.activeSessionId)
    }

    func testCloseSessionForUnknownIdIsSafe() {
        manager.createSession()
        manager.closeSession(UUID()) // random unknown id — must not crash
        XCTAssertEqual(manager.sessions.count, 1)
    }

    func testCloseNonActiveSessionPreservesActive() {
        let first = manager.createSession(title: "first")
        let second = manager.createSession(title: "second")
        // second is active; close first
        manager.closeSession(first.id)
        XCTAssertEqual(manager.activeSessionId, second.id)
        XCTAssertEqual(manager.sessions.count, 1)
    }

    func testCloseSessionReducesCount() {
        let a = manager.createSession()
        let b = manager.createSession()
        let c = manager.createSession()
        manager.closeSession(b.id)
        XCTAssertEqual(manager.sessions.count, 2)
        XCTAssertFalse(manager.sessions.contains { $0.id == b.id })
        XCTAssertTrue(manager.sessions.contains { $0.id == a.id })
        XCTAssertTrue(manager.sessions.contains { $0.id == c.id })
    }

    // MARK: - selectSession

    func testSelectSessionSetsActiveId() {
        let first = manager.createSession(title: "first")
        let second = manager.createSession(title: "second")
        // second is now active; switch back to first
        manager.selectSession(first.id)
        XCTAssertEqual(manager.activeSessionId, first.id)
    }

    func testSelectSessionUpdatesActiveSession() {
        let first = manager.createSession(title: "first")
        manager.createSession(title: "second")
        manager.selectSession(first.id)
        XCTAssertEqual(manager.activeSession?.id, first.id)
    }

    func testSelectSessionDoesNotChangeSessionCount() {
        let first = manager.createSession()
        manager.createSession()
        manager.selectSession(first.id)
        XCTAssertEqual(manager.sessions.count, 2)
    }

    func testSelectUnknownIdSetsActiveToUnknown() {
        manager.createSession()
        let randomId = UUID()
        manager.selectSession(randomId)
        // Spec: selectSession just sets activeSessionId; activeSession returns nil if not found
        XCTAssertEqual(manager.activeSessionId, randomId)
        XCTAssertNil(manager.activeSession)
    }

    // MARK: - terminateAll

    func testTerminateAllClearsSessions() {
        manager.createSession()
        manager.createSession()
        manager.createSession()
        manager.terminateAll()
        XCTAssertTrue(manager.sessions.isEmpty)
    }

    func testTerminateAllClearsActiveSessionId() {
        manager.createSession()
        manager.terminateAll()
        XCTAssertNil(manager.activeSessionId)
    }

    func testTerminateAllOnEmptyIsSafe() {
        manager.terminateAll() // must not crash
        XCTAssertTrue(manager.sessions.isEmpty)
        XCTAssertNil(manager.activeSessionId)
    }

    func testTerminateAllThenCreateNewSession() {
        manager.createSession()
        manager.terminateAll()
        let fresh = manager.createSession(title: "fresh")
        XCTAssertEqual(manager.sessions.count, 1)
        XCTAssertEqual(manager.activeSessionId, fresh.id)
    }

    // MARK: - activeSession computed property

    func testActiveSessionMatchesActiveId() {
        let session = manager.createSession(title: "main")
        XCTAssertEqual(manager.activeSession?.id, session.id)
        XCTAssertEqual(manager.activeSession?.title, "main")
    }

    func testActiveSessionNilWhenActiveIdDoesNotMatch() {
        manager.createSession()
        manager.activeSessionId = UUID() // point to non-existent session
        XCTAssertNil(manager.activeSession)
    }
}
