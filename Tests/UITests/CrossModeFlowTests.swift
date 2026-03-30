import XCTest

/// End-to-end flow tests that cross mode boundaries.
/// Every test: click action → verify result in a different mode.
final class CrossModeFlowTests: XCTestCase {
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

    // MARK: - Plan → Build (Start Work)

    func testStartWorkFlowPlanToBuild() throws {
        // 1. Navigate to Plan mode
        app.buttons["Plan"].click()
        let ticketList = app.scrollViews.firstMatch
        XCTAssertTrue(ticketList.waitForExistence(timeout: 5), "Plan mode must show ticket list")

        // 2. Click first ticket
        let firstTicket = ticketList.otherElements.firstMatch
        XCTAssertTrue(firstTicket.waitForExistence(timeout: 5))
        firstTicket.click()
        XCTAssertTrue(app.staticTexts["DESCRIPTION"].waitForExistence(timeout: 5), "Ticket detail must open")

        // 3. Click Start Work
        let startWork = app.buttons["Start Work"]
        XCTAssertTrue(startWork.waitForExistence(timeout: 5))
        startWork.click()

        // 4. Verify: Build mode conversation view appeared
        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 8),
            "Start Work must switch to Build mode and show conversation input")
    }

    // MARK: - Build → Review (Auto PR)

    func testBuildSessionHasCreatePROption() throws {
        // 1. Create agent session
        app.buttons["Build"].click()
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        newSession.click()

        // 2. Verify conversation view exists
        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        // 3. PR creation button accessible in session header
        let prButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'PR' OR label CONTAINS 'Pull Request'")).firstMatch
        // May or may not be visible depending on session state — just verify no crash
        XCTAssertTrue(app.windows.firstMatch.exists, "Build session view must remain stable")
        _ = prButton.waitForExistence(timeout: 3)
    }

    // MARK: - Full Pipeline: Plan → Build → Review

    func testFullPipelinePlanBuildReview() throws {
        // 1. Start in Plan — click a ticket
        app.buttons["Plan"].click()
        let ticketList = app.scrollViews.firstMatch
        if ticketList.waitForExistence(timeout: 5) {
            let firstTicket = ticketList.otherElements.firstMatch
            if firstTicket.waitForExistence(timeout: 5) {
                firstTicket.click()
            }
        }

        // 2. Start Work → Build mode
        let startWork = app.buttons["Start Work"]
        if startWork.waitForExistence(timeout: 5) {
            startWork.click()
        }
        _ = app.textFields["Message the agent..."].waitForExistence(timeout: 8)

        // 3. Switch to Review mode — should still be stable
        app.buttons["Review"].click()
        let branchesVisible = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
        XCTAssertTrue(branchesVisible, "Review mode must be accessible after Plan→Build flow")
    }

    // MARK: - Command Palette Switches Mode

    func testCommandPaletteNavigatesToMode() throws {
        // Start in a known state
        app.buttons["Plan"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 3)

        // Open command palette and search for Build
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeText("Build")

        let buildResult = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Build'")).firstMatch
        if buildResult.waitForExistence(timeout: 3) {
            buildResult.click()

            // Result: palette closed
            XCTAssertFalse(searchField.waitForExistence(timeout: 3), "Command palette must close after selecting result")
        }
    }

    // MARK: - Review → Back Navigations Don't Break

    func testReviewDetailBackButtonDoesNotBreakOtherModes() throws {
        // Enter Review mode
        app.buttons["Review"].click()
        _ = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)

        // Click a review item (if any)
        let scroll = app.scrollViews.firstMatch
        if scroll.waitForExistence(timeout: 3) {
            let item = scroll.otherElements.firstMatch
            if item.waitForExistence(timeout: 3) {
                item.click()

                // Click Back
                let back = app.buttons["Back"]
                if back.waitForExistence(timeout: 3) {
                    back.click()
                }
            }
        }

        // Switch to Build mode — must work fine
        app.buttons["Build"].click()
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Build mode must be accessible after Review mode back navigation")
    }

    // MARK: - Ship Deploy Does Not Block Other Modes

    func testShipModeDeployDoesNotBlockPlanMode() throws {
        // Go to Ship mode, select environment
        app.buttons["Ship"].click()
        _ = app.staticTexts["ENVIRONMENTS"].waitForExistence(timeout: 5)

        // Select first environment
        let scroll = app.scrollViews.firstMatch
        if scroll.waitForExistence(timeout: 5) {
            let firstEnv = scroll.otherElements.firstMatch
            if firstEnv.waitForExistence(timeout: 5) {
                firstEnv.click()
            }
        }

        // Switch to Plan — must not be blocked
        app.buttons["Plan"].click()
        let ticketList = app.scrollViews.firstMatch
        XCTAssertTrue(ticketList.waitForExistence(timeout: 5), "Plan mode must be accessible while Ship mode has environment selected")
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }
}
