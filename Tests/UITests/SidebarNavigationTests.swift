import XCTest

final class SidebarNavigationTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Rail Icon Navigation

    func testClickingIntentRailIconChangesContent() throws {
        // First navigate somewhere else
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 5)

        // Now click Intent rail icon
        app.buttons["Intent"].click()

        // Intent mode content renders — sidebar or ticket list
        let result = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Intent'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(result, "Clicking Intent rail icon must change main content area")
    }

    func testClickingAgentRailIconShowsNewSessionButton() throws {
        app.buttons["Intent"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 3)

        app.buttons["Agent"].click()

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Clicking Agent rail icon must show New Session button")
    }

    func testClickingReviewRailIconShowsReviewContent() throws {
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        app.buttons["Review"].click()

        let branchesOrSignIn = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
            || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(branchesOrSignIn, "Clicking Review rail icon must show Review content")
    }

    func testClickingShipRailIconShowsEnvironmentsSection() throws {
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        app.buttons["Ship"].click()

        let envHeader = app.staticTexts["ENVIRONMENTS"]
        XCTAssertTrue(envHeader.waitForExistence(timeout: 5), "Clicking Ship rail icon must show ENVIRONMENTS section")
    }

    // MARK: - Rail Icon Accessibility

    func testAllCoreRailIconsAreHittable() throws {
        for modeName in ["Intent", "Agent", "Review", "Ship"] {
            let button = app.buttons[modeName]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(modeName) rail icon must exist")
            XCTAssertTrue(button.isHittable, "\(modeName) rail icon must be hittable")
        }
    }

    // MARK: - Main Content Area Changes

    func testMainContentAreaDiffersAcrossModes() throws {
        // Agent mode: New Session button is the distinguishing element
        app.buttons["Agent"].click()
        let agentElement = app.buttons["New Session"]
        XCTAssertTrue(agentElement.waitForExistence(timeout: 5))

        // Review mode: New Session must not be visible
        app.buttons["Review"].click()
        XCTAssertFalse(agentElement.waitForExistence(timeout: 3),
            "Main content area must change when switching modes — Agent elements must not persist in Review mode")
    }

    func testIntentToAgentContentSwitch() throws {
        app.buttons["Intent"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 3)

        app.buttons["Agent"].click()

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Switching from Intent to Agent must reveal Agent content")
    }

    func testAgentToShipContentSwitch() throws {
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        app.buttons["Ship"].click()

        // Ship mode shows ENVIRONMENTS, not New Session
        let envHeader = app.staticTexts["ENVIRONMENTS"]
        XCTAssertTrue(envHeader.waitForExistence(timeout: 5))

        let newSession = app.buttons["New Session"]
        XCTAssertFalse(newSession.waitForExistence(timeout: 3), "New Session must not be visible in Ship mode")
    }

    // MARK: - Keyboard Shortcut Navigation

    func testKeyboardShortcutsNavigateToMatchingMode() throws {
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "Cmd+1 must not crash")

        app.typeKey("2", modifierFlags: .command)
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Cmd+2 must navigate to Agent mode")

        app.typeKey("3", modifierFlags: .command)
        let branches = app.staticTexts["BRANCHES"]
        let signIn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in'")).firstMatch
        XCTAssertTrue(branches.waitForExistence(timeout: 5) || signIn.waitForExistence(timeout: 2),
            "Cmd+3 must navigate to Review mode")

        app.typeKey("4", modifierFlags: .command)
        let envs = app.staticTexts["ENVIRONMENTS"]
        XCTAssertTrue(envs.waitForExistence(timeout: 5), "Cmd+4 must navigate to Ship mode")
    }

    // MARK: - Library / Auxiliary Modes

    func testEditorModeAccessibleViaKeyboard() throws {
        app.typeKey("5", modifierFlags: .command)

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.outlines.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent, "Cmd+5 must navigate to Editor mode with content")
    }

    func testDatabaseModeAccessibleViaKeyboard() throws {
        app.typeKey("6", modifierFlags: .command)

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Cmd+6 must navigate to Database mode with content")
    }

    // MARK: - Cycle All Modes Does Not Crash

    func testCyclingAllRailIconsDoesNotCrash() throws {
        for mode in ["Intent", "Agent", "Review", "Ship"] {
            let button = app.buttons[mode]
            if button.waitForExistence(timeout: 3) {
                button.click()
                _ = app.windows.firstMatch.waitForExistence(timeout: 1)
            }
        }
        XCTAssertTrue(app.windows.firstMatch.exists, "App must survive clicking all core rail icons in sequence")
    }
}
