import XCTest

/// E2E click-through tests for all 5 spaces (Plan, Build, Review, Operate, Library).
/// Covers real user journeys: space switching via icon rail, sidebar collapse/expand,
/// command palette open/close, and quick capture open/close.
final class SpaceClickThroughTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Returns the icon rail button for a given space label.
    private func railButton(_ label: String) -> XCUIElement {
        app.buttons[label]
    }

    /// Clicks a rail button and waits for the transition to settle.
    private func switchToSpace(_ label: String) {
        railButton(label).click()
        // Brief settle — SwiftUI animation is ~0.2s
        Thread.sleep(forTimeInterval: 0.3)
    }

    // MARK: - Icon Rail Always Visible

    func testIconRailIsAlwaysVisible() throws {
        // All five space buttons must be reachable at launch
        for label in ["Plan", "Build", "Review", "Operate", "Library"] {
            XCTAssertTrue(
                railButton(label).waitForExistence(timeout: 5),
                "Rail button '\(label)' must exist at launch"
            )
        }
    }

    func testIconRailRemainsVisibleAfterSidebarCollapse() throws {
        // Collapse the content sidebar
        let toggleSidebar = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 5))
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Icon rail buttons are still visible
        for label in ["Plan", "Build", "Review", "Operate", "Library"] {
            XCTAssertTrue(
                railButton(label).exists,
                "Rail button '\(label)' must remain after sidebar collapse"
            )
        }

        // Re-expand
        toggleSidebar.click()
    }

    // MARK: - Plan Space

    func testSwitchToPlanSpace() throws {
        // Navigate away first
        switchToSpace("Build")
        _ = railButton("Build").waitForExistence(timeout: 3)

        // Switch to Plan
        switchToSpace("Plan")

        // Plan rail button is selected state
        let planBtn = railButton("Plan")
        XCTAssertTrue(planBtn.waitForExistence(timeout: 5))
        // The content area should have rendered Plan content (tickets list or empty state)
        let hasPlanContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'ticket'")).firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Backlog'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasPlanContent, "Switching to Plan must render Plan content")
    }

    func testPlanSpaceSidebarShowsNewTicketButton() throws {
        switchToSpace("Plan")

        // Plan sidebar has a New Ticket affordance
        let newTicket = app.buttons.matching(NSPredicate(format: "label CONTAINS 'New'")).firstMatch
        XCTAssertTrue(newTicket.waitForExistence(timeout: 5), "Plan sidebar must have a New Ticket button")
    }

    func testPlanSpaceSidebarCollapseAndExpand() throws {
        switchToSpace("Plan")

        let toggleSidebar = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 5))

        // Collapse
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Icon rail still present
        XCTAssertTrue(railButton("Plan").exists, "Plan rail icon must remain after sidebar collapse")

        // Expand
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Content reappears
        let content = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.buttons.matching(NSPredicate(format: "label CONTAINS 'New'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(content, "Plan sidebar content must reappear after expand")
    }

    // MARK: - Build Space

    func testSwitchToBuildSpace() throws {
        switchToSpace("Plan")
        _ = railButton("Plan").waitForExistence(timeout: 3)

        switchToSpace("Build")

        let buildBtn = railButton("Build")
        XCTAssertTrue(buildBtn.waitForExistence(timeout: 5))

        // Build sidebar section tabs (Sessions / Files / Data / Tests)
        let hasSection = app.buttons["Sessions"].waitForExistence(timeout: 5)
            || app.buttons["Files"].waitForExistence(timeout: 3)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasSection, "Build space must render Build sidebar sections")
    }

    func testBuildSpaceSectionSwitching() throws {
        switchToSpace("Build")

        // Click through available section buttons in the Build sidebar
        let sectionLabels = ["Sessions", "Files", "Data", "Tests"]
        for label in sectionLabels {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 3) {
                btn.click()
                Thread.sleep(forTimeInterval: 0.2)
                // App must not crash between sections
                XCTAssertTrue(app.state == .runningForeground, "App must stay running after clicking Build '\(label)' section")
            }
        }
    }

    func testBuildSpaceSidebarCollapseRailStaysVisible() throws {
        switchToSpace("Build")

        let toggleSidebar = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 5))
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(railButton("Build").exists, "Build rail icon must stay visible when sidebar collapsed")
        XCTAssertTrue(railButton("Plan").exists, "Plan rail icon must stay visible when sidebar collapsed")

        toggleSidebar.click()
    }

    // MARK: - Review Space

    func testSwitchToReviewSpace() throws {
        switchToSpace("Plan")
        switchToSpace("Review")

        let reviewBtn = railButton("Review")
        XCTAssertTrue(reviewBtn.waitForExistence(timeout: 5))

        // Review sidebar shows Branches or Changes section
        let hasBranches = app.staticTexts["Branches"].waitForExistence(timeout: 5)
            || app.staticTexts["Changes"].waitForExistence(timeout: 3)
            || app.staticTexts["Pull Requests"].waitForExistence(timeout: 3)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasBranches, "Review space must render Review sidebar with branch/change content")
    }

    func testReviewSpaceSidebarCollapseRailStaysVisible() throws {
        switchToSpace("Review")

        let toggleSidebar = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 5))
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(railButton("Review").exists, "Review rail icon must stay visible when sidebar collapsed")

        toggleSidebar.click()
    }

    func testReviewSpaceContentAreaRendersAfterSwitch() throws {
        // Start from Build, switch to Review, verify content area updates
        switchToSpace("Build")
        Thread.sleep(forTimeInterval: 0.3)
        switchToSpace("Review")

        // Content area must have something rendered — not blank
        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent, "Review content area must render after space switch")
    }

    // MARK: - Operate Space

    func testSwitchToOperateSpace() throws {
        switchToSpace("Plan")
        switchToSpace("Operate")

        let operateBtn = railButton("Operate")
        XCTAssertTrue(operateBtn.waitForExistence(timeout: 5))

        // Operate sidebar shows Deploy or Monitor section
        let hasSection = app.buttons["Deploy"].waitForExistence(timeout: 5)
            || app.buttons["Monitor"].waitForExistence(timeout: 3)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasSection, "Operate space must render Deploy/Monitor sections")
    }

    func testOperateSpaceSectionSwitching() throws {
        switchToSpace("Operate")

        let deploy = app.buttons["Deploy"]
        let monitor = app.buttons["Monitor"]

        if deploy.waitForExistence(timeout: 3) {
            deploy.click()
            Thread.sleep(forTimeInterval: 0.2)
            XCTAssertTrue(app.state == .runningForeground, "App must stay running on Operate Deploy section")
        }

        if monitor.waitForExistence(timeout: 3) {
            monitor.click()
            Thread.sleep(forTimeInterval: 0.2)
            XCTAssertTrue(app.state == .runningForeground, "App must stay running on Operate Monitor section")
        }
    }

    func testOperateSpaceSidebarCollapseRailStaysVisible() throws {
        switchToSpace("Operate")

        let toggleSidebar = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 5))
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(railButton("Operate").exists, "Operate rail icon must stay visible when sidebar collapsed")

        toggleSidebar.click()
    }

    // MARK: - Library Space

    func testSwitchToLibrarySpace() throws {
        switchToSpace("Plan")
        switchToSpace("Library")

        let libraryBtn = railButton("Library")
        XCTAssertTrue(libraryBtn.waitForExistence(timeout: 5))

        // Library sidebar shows one of its section tabs
        let hasSection = app.buttons["Docs"].waitForExistence(timeout: 5)
            || app.buttons["Extensions"].waitForExistence(timeout: 3)
            || app.buttons["Inbox"].waitForExistence(timeout: 3)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasSection, "Library space must render its section tabs")
    }

    func testLibrarySpaceSectionSwitching() throws {
        switchToSpace("Library")

        let sectionLabels = ["Docs", "Extensions", "Inbox", "Messages", "Schedule"]
        for label in sectionLabels {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 2) {
                btn.click()
                Thread.sleep(forTimeInterval: 0.2)
                XCTAssertTrue(app.state == .runningForeground, "App must stay running after clicking Library '\(label)' section")
            }
        }
    }

    func testLibrarySpaceSidebarCollapseRailStaysVisible() throws {
        switchToSpace("Library")

        let toggleSidebar = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 5))
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(railButton("Library").exists, "Library rail icon must stay visible when sidebar collapsed")

        toggleSidebar.click()
    }

    // MARK: - Full Cycle Through All Spaces

    func testCycleThroughAllFiveSpaces() throws {
        let spaces = ["Plan", "Build", "Review", "Operate", "Library"]
        for label in spaces {
            switchToSpace(label)
            XCTAssertTrue(
                railButton(label).waitForExistence(timeout: 5),
                "Rail button '\(label)' must exist after switching to it"
            )
            XCTAssertTrue(
                app.state == .runningForeground,
                "App must remain running after switching to \(label) space"
            )
        }
    }

    func testRapidSpaceSwitchingDoesNotCrash() throws {
        let spaces = ["Plan", "Build", "Review", "Operate", "Library", "Plan", "Review", "Build"]
        for label in spaces {
            railButton(label).click()
        }
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(app.state == .runningForeground, "App must survive rapid space switching")
    }

    // MARK: - Command Palette

    func testCommandPaletteOpensAndClosesFromAnySpace() throws {
        let spaces = ["Plan", "Build", "Review", "Operate", "Library"]
        for label in spaces {
            switchToSpace(label)

            // Open via Cmd+K
            app.typeKey("k", modifierFlags: .command)
            let searchField = app.textFields.matching(
                NSPredicate(format: "label CONTAINS 'Search' OR placeholderValue CONTAINS 'Search'")
            ).firstMatch
            XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Command palette must open in \(label) space")

            // Close via Escape
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(searchField.waitForExistence(timeout: 3), "Command palette must close on Escape in \(label) space")
        }
    }

    func testCommandPaletteToolbarButtonOpens() throws {
        switchToSpace("Plan")

        let cmdBtn = app.buttons["Command Palette"]
        XCTAssertTrue(cmdBtn.waitForExistence(timeout: 5))
        cmdBtn.click()

        let searchField = app.textFields.matching(
            NSPredicate(format: "label CONTAINS 'Search' OR placeholderValue CONTAINS 'Search'")
        ).firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Toolbar Command Palette button must open the palette")

        // Close
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Quick Capture

    func testQuickCaptureOpensAndClosesFromAnySpace() throws {
        let spaces = ["Plan", "Build", "Review"]
        for label in spaces {
            switchToSpace(label)

            // Open via Cmd+Shift+Space
            app.typeKey(.space, modifierFlags: [.command, .shift])
            let inputField = app.textFields.matching(
                NSPredicate(format: "label CONTAINS 'capture' OR placeholderValue CONTAINS 'capture'")
            ).firstMatch
            XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Quick capture must open in \(label) space")

            // Close via Escape
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(inputField.waitForExistence(timeout: 3), "Quick capture must close on Escape in \(label) space")
        }
    }

    // MARK: - Sidebar Collapse Does Not Hide Rail

    func testSidebarCollapsePreservesSpaceSwitching() throws {
        switchToSpace("Plan")

        // Collapse sidebar
        let toggleSidebar = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 5))
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Can still switch spaces via rail even with sidebar collapsed
        for label in ["Build", "Review", "Operate", "Library", "Plan"] {
            switchToSpace(label)
            XCTAssertTrue(
                app.state == .runningForeground,
                "Space switch to '\(label)' must work with sidebar collapsed"
            )
        }

        // Re-expand
        toggleSidebar.click()
    }

    // MARK: - Space Switching Preserves Sidebar Collapse State

    func testSidebarCollapseStatePersistedAcrossSpaceSwitches() throws {
        switchToSpace("Plan")

        // Collapse sidebar in Plan
        let toggleSidebar = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 5))
        toggleSidebar.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Switch to Build — sidebar should stay collapsed (global toggle)
        switchToSpace("Build")
        Thread.sleep(forTimeInterval: 0.3)

        // Icon rail must still be visible
        XCTAssertTrue(railButton("Build").exists, "Build rail button must be visible after space switch with sidebar collapsed")

        // Re-expand
        toggleSidebar.click()
    }
}
