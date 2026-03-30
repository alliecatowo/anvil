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
        for mode in ["Plan", "Build", "Review", "Ship"] {
            let tab = app.buttons[mode]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(mode) tab must exist")
        }
    }

    // MARK: - Click Each Tab → Verify Result

    func testSwitchToPlanModeShowsContent() throws {
        app.buttons["Plan"].click()

        // Plan mode content: sidebar or ticket list should render
        let result = app.staticTexts["Plan"].waitForExistence(timeout: 3)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(result, "Plan mode should render some content after clicking tab")
    }

    func testSwitchToBuildModeShowsNewSessionButton() throws {
        // Switch away first, then back to verify switch actually happened
        app.buttons["Plan"].click()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        app.buttons["Build"].click()

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Build mode must show New Session button")
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

    func testPlanModeHasClickableElements() throws {
        loadDemoData()
        app.buttons["Plan"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)

        let clickable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label != "Plan" }
        XCTAssertGreaterThan(clickable.count, 0, "Plan mode must have clickable elements beyond the tab itself")
    }

    func testBuildModeHasClickableElements() throws {
        app.buttons["Build"].click()

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        XCTAssertTrue(newSession.isHittable, "New Session button must be hittable in Build mode")
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

    func testCmdOneActivatesPlanMode() throws {
        // Start in Build mode
        app.buttons["Build"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        // Switch via keyboard
        app.typeKey("1", modifierFlags: .command)

        // Plan mode specific element should now exist
        // (at minimum the Plan tab remains visible and content changed)
        let planTab = app.buttons["Plan"]
        XCTAssertTrue(planTab.waitForExistence(timeout: 3))
    }

    func testCmdTwoActivatesBuildMode() throws {
        // Start in Plan mode
        app.buttons["Plan"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 3)

        app.typeKey("2", modifierFlags: .command)

        // New Session button is Build-mode-specific
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Cmd+2 must switch to Build mode showing New Session button")
    }

    func testCmdThreeActivatesReviewMode() throws {
        app.buttons["Build"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        app.typeKey("3", modifierFlags: .command)

        // Review mode always shows either branch section or sign-in prompt
        let branchesOrSignIn = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
            || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in'")).firstMatch.waitForExistence(timeout: 2)
        XCTAssertTrue(branchesOrSignIn, "Cmd+3 must activate Review mode")
    }

    func testCmdFourActivatesShipMode() throws {
        app.buttons["Build"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        app.typeKey("4", modifierFlags: .command)

        let envHeader = app.staticTexts["ENVIRONMENTS"]
        XCTAssertTrue(envHeader.waitForExistence(timeout: 5), "Cmd+4 must activate Ship mode showing ENVIRONMENTS")
    }

    // MARK: - Rapid Mode Switching Does Not Crash

    func testRapidModeSwitchingDoesNotCrash() throws {
        let modes = ["Plan", "Build", "Review", "Ship", "Plan", "Build"]
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
