import XCTest

final class SidebarTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        loadDemoData()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Toggle Sidebar

    func testSidebarToggleViaKeyboard() throws {
        app.typeKey("2", modifierFlags: .command)
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))

        // Collapse
        app.typeKey("b", modifierFlags: .command)
        // Sidebar should be hidden — New Session button may not be visible
        // (allow a beat for animation)
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 1)

        // Restore
        app.typeKey("b", modifierFlags: .command)
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Sidebar New Session button must reappear after toggle")
    }

    // MARK: - Agent Sidebar

    func testAgentSidebarShowsNewSessionButton() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Agent sidebar must show New Session button")
    }

    func testAgentSidebarSessionDashboardButton() throws {
        app.typeKey("2", modifierFlags: .command)

        let dashboard = app.buttons["Session Dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5), "Agent sidebar must show Session Dashboard button")
    }

    func testAgentSidebarSessionsSection() throws {
        app.typeKey("2", modifierFlags: .command)
        // Create a session to populate sidebar
        let newSession = app.buttons["New Session"]
        if newSession.waitForExistence(timeout: 5) {
            newSession.click()
        }

        // Sessions section header should appear
        let sessionsHeader = app.staticTexts["SESSIONS"]
        XCTAssertTrue(sessionsHeader.waitForExistence(timeout: 5), "Agent sidebar must show SESSIONS section after creating a session")
    }

    // MARK: - Intent Sidebar

    func testIntentSidebarHasScrollContent() throws {
        app.typeKey("1", modifierFlags: .command)

        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "Intent sidebar must have scrollable content")
    }

    // MARK: - Review Sidebar

    func testReviewSidebarShowsBranchesSection() throws {
        app.typeKey("3", modifierFlags: .command)

        let branches = app.staticTexts["BRANCHES"]
        XCTAssertTrue(branches.waitForExistence(timeout: 5), "Review sidebar must show BRANCHES section")
    }

    func testReviewSidebarShowsPullRequestsSection() throws {
        app.typeKey("3", modifierFlags: .command)

        let prs = app.staticTexts["PULL REQUESTS"]
        XCTAssertTrue(prs.waitForExistence(timeout: 5), "Review sidebar must show PULL REQUESTS section")
    }

    // MARK: - Ship Sidebar

    func testShipSidebarShowsEnvironmentsSection() throws {
        app.typeKey("4", modifierFlags: .command)

        let envs = app.staticTexts["ENVIRONMENTS"]
        XCTAssertTrue(envs.waitForExistence(timeout: 5), "Ship sidebar must show ENVIRONMENTS section")
    }

    func testShipSidebarEnvironmentRowClickable() throws {
        app.typeKey("4", modifierFlags: .command)

        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))

        let firstEnv = scroll.otherElements.firstMatch
        XCTAssertTrue(firstEnv.waitForExistence(timeout: 5), "Ship sidebar must have at least one environment row")
        XCTAssertTrue(firstEnv.isHittable, "Environment row must be hittable")
    }

    // MARK: - Editor Sidebar

    func testEditorSidebarHasContent() throws {
        app.typeKey("5", modifierFlags: .command)

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.outlines.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent, "Editor sidebar must render content")
    }

    // MARK: - Database Sidebar

    func testDatabaseSidebarHasContent() throws {
        app.typeKey("6", modifierFlags: .command)

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Database sidebar must render content")
    }

    // MARK: - Messaging Sidebar

    func testMessagingSidebarHasContent() throws {
        app.typeKey("9", modifierFlags: .command)

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Messaging sidebar must render content")
    }

    // MARK: - Notifications Sidebar

    func testNotificationsSidebarHasContent() throws {
        app.typeKey("0", modifierFlags: .command)

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Notifications sidebar must render content")
    }

    // MARK: - Sidebar Content Changes On Mode Switch

    func testSidebarContentChangesOnModeSwitch() throws {
        // Agent mode: New Session button
        app.typeKey("2", modifierFlags: .command)
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))

        // Switch to Review mode: New Session should be gone, BRANCHES should appear
        app.typeKey("3", modifierFlags: .command)
        XCTAssertFalse(newSession.waitForExistence(timeout: 3), "New Session button must not be visible in Review mode")

        let branches = app.staticTexts["BRANCHES"]
        XCTAssertTrue(branches.waitForExistence(timeout: 5), "Review sidebar must show BRANCHES after mode switch from Agent")
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }
}
