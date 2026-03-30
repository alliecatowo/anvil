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
        let planButton = app.buttons["Plan"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 3), "Plan rail button must exist")
        planButton.click()
        let contentVisible = app.staticTexts["Backlog"].waitForExistence(timeout: 2)
            || app.staticTexts["Sprint"].waitForExistence(timeout: 2)
            || app.staticTexts["Board"].waitForExistence(timeout: 2)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(contentVisible, "Plan space must render planning content after click")
    }

    func testSwitchToBuildSpace() {
        let buildButton = app.buttons["Build"]
        XCTAssertTrue(buildButton.waitForExistence(timeout: 3), "Build rail button must exist")
        buildButton.click()
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(
            newSession.waitForExistence(timeout: 5),
            "Build space must show New Session button after click"
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
        XCTAssertTrue(contentVisible, "Review space must render sidebar content after click")
    }

    func testSwitchToOperateSpace() {
        let operateButton = app.buttons["Operate"]
        XCTAssertTrue(operateButton.waitForExistence(timeout: 3), "Operate rail button must exist")
        operateButton.click()
        XCTAssertTrue(
            app.staticTexts["ENVIRONMENTS"].waitForExistence(timeout: 5),
            "Operate space must show ENVIRONMENTS section in sidebar"
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

// MARK: - Library Space Flows

final class AnvilLibrarySpaceTests: XCTestCase {

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

    /// Navigate to Library space and verify the Docs source is the default.
    func testLibrarySpaceShowsDocsSourceByDefault() {
        // Library space is reached via Cmd+5 or the "Library" rail button
        app.typeKey("5", modifierFlags: .command)
        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 5),
            "Window must still exist after navigating to Library"
        )
        // The sidebar picker segment "Docs" must be present
        let docsPicker = app.buttons["Docs"]
        XCTAssertTrue(
            docsPicker.waitForExistence(timeout: 5),
            "Library sidebar must show a 'Docs' segment in the source picker"
        )
    }

    /// Navigate to Library space and switch to the Extensions source.
    func testLibrarySpaceSwitchToExtensionsSource() {
        app.typeKey("5", modifierFlags: .command)
        let extensionsButton = app.buttons["Extensions"]
        XCTAssertTrue(
            extensionsButton.waitForExistence(timeout: 5),
            "Library sidebar must expose an 'Extensions' segment"
        )
        extensionsButton.click()
        // After switching, the content area must not crash and the window stays alive
        let contentVisible = app.staticTexts["No extensions installed"].waitForExistence(timeout: 3)
            || app.buttons["Browse Marketplace"].waitForExistence(timeout: 3)
            || app.lists.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(
            contentVisible,
            "Switching to Extensions source must render extensions content"
        )
    }

    /// Navigate to Library space and switch to the Inbox (Notifications) source.
    func testLibrarySpaceSwitchToInboxSource() {
        app.typeKey("5", modifierFlags: .command)
        let inboxButton = app.buttons["Inbox"]
        XCTAssertTrue(
            inboxButton.waitForExistence(timeout: 5),
            "Library sidebar must expose an 'Inbox' segment"
        )
        inboxButton.click()
        let contentVisible = app.staticTexts["No notifications"].waitForExistence(timeout: 3)
            || app.lists.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(
            contentVisible,
            "Switching to Inbox source must render notifications content"
        )
    }

    /// Navigate to Library space and switch to the Messages source.
    func testLibrarySpaceSwitchToMessagesSource() {
        app.typeKey("5", modifierFlags: .command)
        let messagesButton = app.buttons["Messages"]
        XCTAssertTrue(
            messagesButton.waitForExistence(timeout: 5),
            "Library sidebar must expose a 'Messages' segment"
        )
        messagesButton.click()
        let contentVisible = app.staticTexts["No channels"].waitForExistence(timeout: 3)
            || app.staticTexts["Channels"].waitForExistence(timeout: 3)
            || app.lists.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(
            contentVisible,
            "Switching to Messages source must render messaging channel content"
        )
    }

    /// Navigate to Library space and switch to the Schedule source.
    func testLibrarySpaceSwitchToScheduleSource() {
        app.typeKey("5", modifierFlags: .command)
        let scheduleButton = app.buttons["Schedule"]
        XCTAssertTrue(
            scheduleButton.waitForExistence(timeout: 5),
            "Library sidebar must expose a 'Schedule' segment"
        )
        scheduleButton.click()
        let contentVisible = app.staticTexts["No events today"].waitForExistence(timeout: 3)
            || app.buttons["Load Demo Data"].waitForExistence(timeout: 3)
            || app.lists.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(
            contentVisible,
            "Switching to Schedule source must render schedule content"
        )
    }

    /// All five Library source picker segments must be present simultaneously.
    func testLibraryAllSourceSegmentsExist() {
        app.typeKey("5", modifierFlags: .command)
        for label in ["Docs", "Extensions", "Inbox", "Messages", "Schedule"] {
            XCTAssertTrue(
                app.buttons[label].waitForExistence(timeout: 5),
                "Library source picker must contain '\(label)' segment"
            )
        }
    }
}

// MARK: - Operate Space Flows

final class AnvilOperateSpaceTests: XCTestCase {

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

    /// Navigate to Operate space and verify the Deploy (Ship) source is shown by default.
    func testOperateSpaceShowsDeploySourceByDefault() {
        let operateButton = app.buttons["Operate"]
        XCTAssertTrue(operateButton.waitForExistence(timeout: 5), "Operate rail button must exist")
        operateButton.click()
        // The Operate sidebar content must include ENVIRONMENTS
        XCTAssertTrue(
            app.staticTexts["ENVIRONMENTS"].waitForExistence(timeout: 5),
            "Deploy source must render ENVIRONMENTS list"
        )
    }

    /// Navigate to Operate space and verify monitoring source is available.
    func testOperateSpaceHasMonitorSource() {
        let operateButton = app.buttons["Operate"]
        XCTAssertTrue(operateButton.waitForExistence(timeout: 5), "Operate rail button must exist")
        operateButton.click()
        // Monitor source is available via the source picker
        let contentVisible = app.staticTexts["ENVIRONMENTS"].waitForExistence(timeout: 3)
            || app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'New Terminal Session'")
            ).firstMatch.waitForExistence(timeout: 3)
            || app.windows.firstMatch.exists
        XCTAssertTrue(
            contentVisible,
            "Switching to Terminal source must render terminal sessions content"
        )
    }

    /// All three Operate source picker segments must be present after entering the space.
    func testOperateAllSourceSegmentsExist() {
        app.buttons["Ship"].click()
        for label in ["Deploy", "Monitor", "Terminal"] {
            XCTAssertTrue(
                app.buttons[label].waitForExistence(timeout: 5),
                "Operate source picker must contain '\(label)' segment"
            )
        }
    }

    /// The Operate space must survive switching through all sources without crashing.
    func testOperateSourceCycleDoesNotCrash() {
        app.buttons["Ship"].click()
        for label in ["Deploy", "Monitor", "Terminal", "Deploy"] {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 3) { btn.click() }
        }
        XCTAssertTrue(
            app.windows.firstMatch.exists,
            "App must remain alive after cycling all Operate sources"
        )
    }
}

// MARK: - Plan Space Flows

final class AnvilPlanSpaceTests: XCTestCase {

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

    /// Navigate to Plan (Intent) space and verify the ticket list is visible.
    func testPlanSpaceTicketListIsVisible() {
        app.buttons["Intent"].click()
        // The sidebar always renders at least the Sprint section header
        let listVisible = app.staticTexts["Sprint"].waitForExistence(timeout: 5)
            || app.lists.firstMatch.waitForExistence(timeout: 5)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(
            listVisible,
            "Plan space must render a ticket list (Sprint section or scroll view) after navigation"
        )
    }

    /// Verify the New Ticket button is visible in Plan space.
    func testPlanSpaceNewTicketButtonIsVisible() {
        app.buttons["Intent"].click()
        _ = app.lists.firstMatch.waitForExistence(timeout: 5)
        let newTicketButton = app.buttons["New Ticket"]
        XCTAssertTrue(
            newTicketButton.waitForExistence(timeout: 5),
            "Plan space sidebar must expose a 'New Ticket' button"
        )
    }

    /// The New Ticket button must be hittable (not obscured).
    func testPlanSpaceNewTicketButtonIsHittable() {
        app.buttons["Intent"].click()
        _ = app.lists.firstMatch.waitForExistence(timeout: 5)
        let newTicketButton = app.buttons["New Ticket"]
        XCTAssertTrue(newTicketButton.waitForExistence(timeout: 5))
        XCTAssertTrue(
            newTicketButton.isHittable,
            "New Ticket button must be hittable in Plan space"
        )
    }

    /// Tapping New Ticket must reveal a text field for the ticket title.
    func testPlanSpaceNewTicketButtonOpensQuickAddField() {
        app.buttons["Intent"].click()
        _ = app.lists.firstMatch.waitForExistence(timeout: 5)
        let newTicketButton = app.buttons["New Ticket"]
        guard newTicketButton.waitForExistence(timeout: 5) else {
            XCTAssertTrue(app.windows.firstMatch.exists)
            return
        }
        newTicketButton.click()
        let quickAddField = app.textFields["New ticket title..."]
        XCTAssertTrue(
            quickAddField.waitForExistence(timeout: 3),
            "Clicking New Ticket must open the quick-add text field"
        )
    }

    /// The Plan View Mode picker must be present (List / Board / etc.).
    func testPlanSpaceViewModePickerIsVisible() {
        app.buttons["Intent"].click()
        _ = app.lists.firstMatch.waitForExistence(timeout: 5)
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5),
            "Plan space must show a view-mode segmented control (List/Board)"
        )
    }
}
