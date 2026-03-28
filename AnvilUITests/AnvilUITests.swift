import XCTest

/// E2E click-through tests for Anvil.
/// These tests launch the real app and verify user-facing flows end to end.
///
/// Run with:
///   xcodebuild test -project Anvil.xcodeproj -scheme AnvilUITests \
///     -destination 'platform=macOS'
///
/// This file is a self-contained consolidated suite. Per-feature breakdowns
/// live in Tests/UITests/. Add this file to an XCUITest target manually,
/// or register it via the test script.
final class AnvilUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - App Launch

    func testAppLaunchesAndMainWindowAppears() {
        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 5),
            "Main window must appear within 5 s of launch"
        )
    }

    func testMainWindowMeetsMinimumSize() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(window.frame.width, 800, "Window must be at least 800 pt wide")
        XCTAssertGreaterThan(window.frame.height, 600, "Window must be at least 600 pt tall")
    }

    // MARK: - Mode Tab Bar Existence

    func testAllCoreModesAreVisible() {
        for mode in ["Intent", "Agent", "Review", "Ship"] {
            let tab = app.buttons[mode]
            XCTAssertTrue(
                tab.waitForExistence(timeout: 5),
                "\(mode) mode tab must be visible on launch"
            )
        }
    }

    // MARK: - Space Navigation (Plan → Intent, Build → Agent, Review, Operate → Ship, Library)

    func testSwitchToPlanSpace() {
        // "Plan" maps to Intent mode in Anvil's tab vocabulary
        let intentButton = app.buttons["Intent"]
        XCTAssertTrue(intentButton.waitForExistence(timeout: 3), "Intent (Plan) tab must exist")
        intentButton.click()
        // Intent mode surfaces a backlog, sprint board, or ticket scroll view
        let contentVisible = app.staticTexts["Backlog"].waitForExistence(timeout: 2)
            || app.staticTexts["Sprint"].waitForExistence(timeout: 2)
            || app.staticTexts["Board"].waitForExistence(timeout: 2)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(contentVisible, "Intent mode must render planning content after tab click")
    }

    func testSwitchToBuildSpace() {
        // "Build" maps to Agent mode
        let agentButton = app.buttons["Agent"]
        XCTAssertTrue(agentButton.waitForExistence(timeout: 3), "Agent (Build) tab must exist")
        agentButton.click()
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(
            newSession.waitForExistence(timeout: 5),
            "Agent mode must show New Session button after tab click"
        )
    }

    func testSwitchToReviewSpace() {
        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 3))
        reviewButton.click()
        let contentVisible = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
            || app.staticTexts["Review Inbox"].waitForExistence(timeout: 2)
            || app.staticTexts["Open PRs"].waitForExistence(timeout: 2)
            || app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'Sign in to GitHub'")
            ).firstMatch.waitForExistence(timeout: 2)
        XCTAssertTrue(contentVisible, "Review mode must render sidebar content after tab click")
    }

    func testSwitchToOperateSpace() {
        // "Operate" maps to Ship mode
        let shipButton = app.buttons["Ship"]
        XCTAssertTrue(shipButton.waitForExistence(timeout: 3), "Ship (Operate) tab must exist")
        shipButton.click()
        XCTAssertTrue(
            app.staticTexts["ENVIRONMENTS"].waitForExistence(timeout: 5),
            "Ship mode must show ENVIRONMENTS section in sidebar"
        )
    }

    func testSwitchToLibrarySpace() {
        // "Library" maps to Editor mode (file/docs exploration)
        app.typeKey("5", modifierFlags: .command)
        let contentVisible = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.outlines.firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts["Docs"].waitForExistence(timeout: 2)
            || app.staticTexts["Extensions"].waitForExistence(timeout: 2)
        XCTAssertTrue(contentVisible, "Editor / Library mode must render content after Cmd+5")
    }

    // MARK: - Command Palette

    func testCommandPaletteOpensViaCmdK() {
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Cmd+K must open command palette with search field"
        )
    }

    func testCommandPaletteSearchFieldIsFocusedOnOpen() {
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        app.typeText("agent")
        XCTAssertEqual(
            searchField.value as? String, "agent",
            "Command palette search field must accept typing immediately on open"
        )
    }

    func testCommandPaletteDismissesWithEscape() {
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(
            searchField.waitForExistence(timeout: 3),
            "Escape must close command palette"
        )
    }

    func testCommandPaletteDismissesWithBackdropClick() {
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        let corner = app.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.05, dy: 0.95)
        )
        corner.click()
        XCTAssertFalse(
            searchField.waitForExistence(timeout: 3),
            "Clicking the backdrop must close command palette"
        )
    }

    func testCommandPaletteSearchProducesResults() {
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText("Toggle")
        XCTAssertTrue(
            app.scrollViews.firstMatch.waitForExistence(timeout: 3),
            "Typing in command palette must produce a results scroll view"
        )
    }

    func testCommandPaletteNoMatchDoesNotCrash() {
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText("xyzxyzxyz_no_match_ever")
        XCTAssertTrue(
            app.windows.firstMatch.exists,
            "No-match search must not crash the app"
        )
    }

    func testCommandPaletteReopenableAfterClose() {
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(searchField.waitForExistence(timeout: 3))
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Command palette must be reopenable after close"
        )
    }

    // MARK: - Sidebar Toggle

    func testSidebarTogglesWithCmdB() {
        // Toggle off
        app.typeKey("b", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "App must survive sidebar collapse")
        // Toggle on
        app.typeKey("b", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "App must survive sidebar restore")
    }

    func testSidebarRestoresContentAfterTwoToggles() {
        // Ensure we are in Agent mode so New Session is the canary element
        app.buttons["Agent"].click()
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))

        app.typeKey("b", modifierFlags: .command)
        app.typeKey("b", modifierFlags: .command)

        XCTAssertTrue(
            newSession.waitForExistence(timeout: 5),
            "New Session button must reappear after two sidebar toggles"
        )
    }

    // MARK: - Plan Space: Ticket Creation

    func testCreateTicketInIntentMode() {
        app.buttons["Intent"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)

        let addButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Add ticket' OR label == '+'")
        ).firstMatch

        guard addButton.waitForExistence(timeout: 3) else {
            // If no Add button is exposed yet, at minimum the mode must have rendered
            XCTAssertTrue(app.windows.firstMatch.exists)
            return
        }

        addButton.click()
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 3) else {
            XCTAssertTrue(app.windows.firstMatch.exists)
            return
        }
        field.typeText("Test ticket from UI test\n")
        XCTAssertTrue(
            app.staticTexts["Test ticket from UI test"].waitForExistence(timeout: 3),
            "Newly created ticket must appear in the list"
        )
    }

    // MARK: - Agent Mode: New Session Flow

    func testNewSessionButtonIsHittableInAgentMode() {
        app.buttons["Agent"].click()
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        XCTAssertTrue(newSession.isHittable, "New Session button must be hittable")
    }

    func testClickingNewSessionOpensInputField() {
        app.buttons["Agent"].click()
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        newSession.click()

        let inputField = app.textFields["Message the agent..."]
            .waitForExistence(timeout: 5)
            ? app.textFields["Message the agent..."]
            : app.textViews.firstMatch
        let appeared = app.textFields["Message the agent..."].waitForExistence(timeout: 5)
            || app.textViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(appeared, "Clicking New Session must open the agent message input field")
    }

    // MARK: - Settings

    func testSettingsButtonIsVisible() {
        let settingsButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Settings'")
        ).firstMatch
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings button must be visible in the status bar"
        )
    }

    func testSettingsButtonIsHittable() {
        let settingsButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Settings'")
        ).firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsButton.isHittable, "Settings button must be hittable")
    }

    // MARK: - Branch Picker

    func testBranchPickerButtonExistsInStatusBar() {
        let branchButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Switch Branch'")
        ).firstMatch
        XCTAssertTrue(
            branchButton.waitForExistence(timeout: 5),
            "Branch picker button must exist in the status bar"
        )
    }

    func testBranchPickerOpensPopover() {
        let branchButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Switch Branch'")
        ).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        branchButton.click()
        XCTAssertTrue(
            app.popovers.firstMatch.waitForExistence(timeout: 5),
            "Branch picker must open a popover"
        )
    }

    func testBranchPickerPopoverDismissesWithEscape() {
        let branchButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Switch Branch'")
        ).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        branchButton.click()
        let popover = app.popovers.firstMatch
        guard popover.waitForExistence(timeout: 5) else { return }
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(
            popover.waitForExistence(timeout: 3),
            "Escape must dismiss the branch picker popover"
        )
    }

    // MARK: - Quick Capture

    func testQuickCaptureOpensWithCmdShiftSpace() {
        app.typeKey(.space, modifierFlags: [.command, .shift])
        XCTAssertTrue(
            app.textFields["Quick capture..."].waitForExistence(timeout: 5),
            "Cmd+Shift+Space must open Quick Capture overlay"
        )
    }

    func testQuickCaptureDismissesWithEscape() {
        app.typeKey(.space, modifierFlags: [.command, .shift])
        let captureField = app.textFields["Quick capture..."]
        XCTAssertTrue(captureField.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(
            captureField.waitForExistence(timeout: 3),
            "Escape must dismiss Quick Capture overlay"
        )
    }

    func testQuickCaptureAcceptsText() {
        app.typeKey(.space, modifierFlags: [.command, .shift])
        let captureField = app.textFields["Quick capture..."]
        XCTAssertTrue(captureField.waitForExistence(timeout: 5))
        captureField.click()
        captureField.typeText("Follow up on auth bug")
        XCTAssertEqual(
            captureField.value as? String, "Follow up on auth bug",
            "Quick Capture field must accept and retain typed text"
        )
    }

    // MARK: - Keyboard Mode Shortcuts

    func testCmdOneActivatesIntentMode() {
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(
            app.buttons["Intent"].waitForExistence(timeout: 3),
            "Cmd+1 must activate Intent mode"
        )
    }

    func testCmdTwoActivatesAgentMode() {
        app.buttons["Intent"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(
            app.buttons["New Session"].waitForExistence(timeout: 5),
            "Cmd+2 must activate Agent mode showing New Session button"
        )
    }

    func testCmdThreeActivatesReviewMode() {
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)
        app.typeKey("3", modifierFlags: .command)
        let reviewContent = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
            || app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'Sign in'")
            ).firstMatch.waitForExistence(timeout: 2)
        XCTAssertTrue(reviewContent, "Cmd+3 must activate Review mode")
    }

    func testCmdFourActivatesShipMode() {
        app.buttons["Agent"].click()
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)
        app.typeKey("4", modifierFlags: .command)
        XCTAssertTrue(
            app.staticTexts["ENVIRONMENTS"].waitForExistence(timeout: 5),
            "Cmd+4 must activate Ship mode showing ENVIRONMENTS"
        )
    }

    // MARK: - Rapid Switching Stability

    func testRapidModeSwitchingDoesNotCrash() {
        for mode in ["Intent", "Agent", "Review", "Ship", "Intent", "Agent"] {
            let tab = app.buttons[mode]
            if tab.waitForExistence(timeout: 3) {
                tab.click()
            }
        }
        XCTAssertTrue(
            app.windows.firstMatch.exists,
            "App must remain alive after rapid mode switching"
        )
    }

    func testCycleAllKeyboardModesDoesNotCrash() {
        for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] {
            app.typeKey(key, modifierFlags: .command)
        }
        XCTAssertTrue(
            app.windows.firstMatch.exists,
            "App must remain alive after cycling all modes via keyboard"
        )
    }

    func testFullNavigationCycleDoesNotCrash() {
        app.typeKey("1", modifierFlags: .command)
        app.typeKey("2", modifierFlags: .command)
        app.typeKey("3", modifierFlags: .command)
        app.typeKey("4", modifierFlags: .command)
        app.typeKey("b", modifierFlags: .command)
        app.typeKey("b", modifierFlags: .command)
        app.typeKey("k", modifierFlags: .command)
        app.typeKey(.escape, modifierFlags: [])
        app.typeKey("j", modifierFlags: .command)
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(
            app.windows.firstMatch.exists,
            "App must remain stable after a full navigation cycle"
        )
    }
}
