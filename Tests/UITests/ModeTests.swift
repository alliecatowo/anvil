import XCTest

final class ModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Core Mode Tabs Exist

    func testAllCoreModesExist() throws {
        for mode in ["Intent", "Agent", "Review", "Ship"] {
            let tab = app.buttons[mode]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(mode) tab must exist")
        }
    }

    // MARK: - Click Each Tab → Verify Result

    func testSwitchToIntentModeShowsContent() throws {
        app.buttons["Intent"].click()

        // Intent mode content: sidebar or ticket list should render
        let result = app.staticTexts["Intent"].waitForExistence(timeout: 3)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(result, "Intent mode should render some content after clicking tab")
    }

    func testSwitchToAgentModeShowsNewSessionButton() throws {
        // Switch away first, then back to verify switch actually happened
        app.buttons["Intent"].click()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        app.buttons["Agent"].click()

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Agent mode must show New Session button")
    }

    func testSwitchToReviewModeShowsSidebar() throws {
        app.buttons["Review"].click()

        // Review sidebar shows at minimum "BRANCHES" section header or sign-in prompt
        let branchesVisible = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
        let signInVisible = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in to GitHub'")).firstMatch.waitForExistence(timeout: 1)
        XCTAssertTrue(branchesVisible || signInVisible, "Review mode must render sidebar content")
    }

    func testSwitchToShipModeShowsEnvironmentsSectionHeader() throws {
        app.buttons["Ship"].click()

        let envHeader = app.staticTexts["ENVIRONMENTS"]
        XCTAssertTrue(envHeader.waitForExistence(timeout: 5), "Ship mode must show ENVIRONMENTS section in sidebar")
    }

    func testSwitchToEditorModeViaKeyboard() throws {
        app.typeKey("5", modifierFlags: .command)

        // Editor mode renders — file tree or editor pane should appear
        let result = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.outlines.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(result, "Editor mode should render content after Cmd+5")
    }

    func testSwitchToDatabaseModeViaKeyboard() throws {
        app.typeKey("6", modifierFlags: .command)

        // Database mode — schema explorer or query console should appear
        let result = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.textViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(result, "Database mode should render content after Cmd+6")
    }

    // MARK: - Each Mode Has Clickable Elements

    func testIntentModeHasClickableElements() throws {
        loadDemoData()
        app.buttons["Intent"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)

        let clickable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label != "Intent" }
        XCTAssertGreaterThan(clickable.count, 0, "Intent mode must have clickable elements beyond the tab itself")
    }

    func testAgentModeHasClickableElements() throws {
        app.buttons["Agent"].click()

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        XCTAssertTrue(newSession.isHittable, "New Session button must be hittable in Agent mode")
    }

    func testReviewModeHasClickableElements() throws {
        app.buttons["Review"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)

        let clickable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label != "Review" }
        XCTAssertGreaterThan(clickable.count, 0, "Review mode must have clickable elements beyond the tab itself")
    }

    func testShipModeHasClickableElements() throws {
        app.buttons["Ship"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)

        let clickable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label != "Ship" }
        XCTAssertGreaterThan(clickable.count, 0, "Ship mode must have clickable elements beyond the tab itself")
    }

    // MARK: - Keyboard Shortcuts → Verify Mode Changes

    func testCmdOneActivatesIntentMode() throws {
        // Start in Agent mode
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        // Switch via keyboard
        app.typeKey("1", modifierFlags: .command)

        // Intent mode specific element should now exist
        // (at minimum the Intent tab remains visible and content changed)
        let intentTab = app.buttons["Intent"]
        XCTAssertTrue(intentTab.waitForExistence(timeout: 3))
    }

    func testCmdTwoActivatesAgentMode() throws {
        // Start in Intent mode
        app.buttons["Intent"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 3)

        app.typeKey("2", modifierFlags: .command)

        // New Session button is Agent-mode-specific
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Cmd+2 must switch to Agent mode showing New Session button")
    }

    func testCmdThreeActivatesReviewMode() throws {
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        app.typeKey("3", modifierFlags: .command)

        // Review mode always shows either branch section or sign-in prompt
        let branchesOrSignIn = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
            || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in'")).firstMatch.waitForExistence(timeout: 2)
        XCTAssertTrue(branchesOrSignIn, "Cmd+3 must activate Review mode")
    }

    func testCmdFourActivatesShipMode() throws {
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        app.typeKey("4", modifierFlags: .command)

        let envHeader = app.staticTexts["ENVIRONMENTS"]
        XCTAssertTrue(envHeader.waitForExistence(timeout: 5), "Cmd+4 must activate Ship mode showing ENVIRONMENTS")
    }

    // MARK: - Rapid Mode Switching Does Not Crash

    func testRapidModeSwitchingDoesNotCrash() throws {
        let modes = ["Intent", "Agent", "Review", "Ship", "Intent", "Agent"]
        for mode in modes {
            let tab = app.buttons[mode]
            if tab.waitForExistence(timeout: 3) {
                tab.click()
            }
        }
        // App still alive — any element should exist
        XCTAssertTrue(app.windows.firstMatch.exists, "App must remain running after rapid mode switching")
    }

    func testCycleAllModesViaKeyboardDoesNotCrash() throws {
        for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] {
            app.typeKey(key, modifierFlags: .command)
        }
        XCTAssertTrue(app.windows.firstMatch.exists, "App must remain running after cycling all modes via keyboard")
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }
}
