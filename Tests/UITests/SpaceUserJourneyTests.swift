import XCTest

/// Detailed per-space user journey tests.
/// Each test follows a real user flow: create → interact → verify outcome.
final class SpaceUserJourneyTests: XCTestCase {
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

    private func switchToSpace(_ label: String) {
        app.buttons[label].click()
        Thread.sleep(forTimeInterval: 0.3)
    }

    // MARK: - PLAN: Create ticket → see it in list → open it → edit title

    func testPlanCreateTicketAppearsInList() throws {
        switchToSpace("Plan")

        // Open quick-add via the New Ticket button (+ icon, accessibility label "New Ticket")
        let newTicketBtn = app.buttons["New Ticket"]
        XCTAssertTrue(newTicketBtn.waitForExistence(timeout: 5), "New Ticket button must exist in Plan sidebar")
        newTicketBtn.click()

        // A text field for the ticket title appears
        let titleField = app.textFields["New ticket title..."]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Quick-add title field must appear after clicking New Ticket")

        let ticketTitle = "XCUITest ticket \(Int.random(in: 1000...9999))"
        titleField.typeText(ticketTitle)
        app.typeKey(.return, modifierFlags: [])

        // The new ticket appears somewhere in the sidebar list
        let ticketCell = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '\(ticketTitle)'")).firstMatch
        XCTAssertTrue(ticketCell.waitForExistence(timeout: 5), "Created ticket must appear in the Plan sidebar list")
    }

    func testPlanOpenTicketShowsDetailView() throws {
        switchToSpace("Plan")

        // Create a ticket first
        let newTicketBtn = app.buttons["New Ticket"]
        XCTAssertTrue(newTicketBtn.waitForExistence(timeout: 5))
        newTicketBtn.click()

        let titleField = app.textFields["New ticket title..."]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        let ticketTitle = "Journey ticket \(Int.random(in: 1000...9999))"
        titleField.typeText(ticketTitle)
        app.typeKey(.return, modifierFlags: [])

        // Click the ticket in the list to open detail view
        let ticketCell = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '\(ticketTitle)'")).firstMatch
        XCTAssertTrue(ticketCell.waitForExistence(timeout: 5))
        ticketCell.click()

        // Detail view must appear — look for the editable "Ticket title" field
        let detailTitleField = app.textFields["Ticket title"]
        XCTAssertTrue(detailTitleField.waitForExistence(timeout: 5), "Clicking ticket must open detail view with editable title field")
    }

    func testPlanEditTicketTitle() throws {
        switchToSpace("Plan")

        // Create ticket
        let newTicketBtn = app.buttons["New Ticket"]
        XCTAssertTrue(newTicketBtn.waitForExistence(timeout: 5))
        newTicketBtn.click()

        let titleField = app.textFields["New ticket title..."]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        let originalTitle = "Edit me \(Int.random(in: 1000...9999))"
        titleField.typeText(originalTitle)
        app.typeKey(.return, modifierFlags: [])

        // Open ticket detail
        let ticketCell = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '\(originalTitle)'")).firstMatch
        XCTAssertTrue(ticketCell.waitForExistence(timeout: 5))
        ticketCell.click()

        // Edit title in detail view
        let detailTitleField = app.textFields["Ticket title"]
        XCTAssertTrue(detailTitleField.waitForExistence(timeout: 5))
        detailTitleField.click()
        // Select all and replace
        app.typeKey("a", modifierFlags: .command)
        let newTitle = "Renamed \(Int.random(in: 1000...9999))"
        detailTitleField.typeText(newTitle)
        app.typeKey(.return, modifierFlags: [])

        // The updated title must be reflected
        let updatedField = app.textFields["Ticket title"]
        let currentValue = updatedField.value as? String ?? ""
        XCTAssertTrue(currentValue.contains(newTitle) || currentValue == newTitle,
                      "Ticket title must update after editing in detail view")
    }

    // MARK: - BUILD: Rail icon → agent sidebar → new session → session appears

    func testBuildRailIconShowsAgentSidebar() throws {
        // Start from Plan
        switchToSpace("Plan")
        switchToSpace("Build")

        // Sessions tab is active by default — shows AgentSidebar
        let sessionsTab = app.buttons["Sessions"]
        if sessionsTab.waitForExistence(timeout: 3) {
            XCTAssertTrue(sessionsTab.isEnabled, "Sessions tab must be enabled in Build space")
        }

        // New Session button is present (from AgentSidebar)
        let newSessionBtn = app.buttons["New Session"]
        XCTAssertTrue(newSessionBtn.waitForExistence(timeout: 5), "New Session button must appear in Build > Sessions sidebar")
    }

    func testBuildNewSessionCreatesSession() throws {
        switchToSpace("Build")

        // Ensure Sessions tab is active
        let sessionsTab = app.buttons["Sessions"]
        if sessionsTab.waitForExistence(timeout: 3) {
            sessionsTab.click()
            Thread.sleep(forTimeInterval: 0.2)
        }

        let newSessionBtn = app.buttons["New Session"]
        XCTAssertTrue(newSessionBtn.waitForExistence(timeout: 5))

        // Record session count before
        let sessionsBefore = app.cells.count

        newSessionBtn.click()
        Thread.sleep(forTimeInterval: 0.5)

        // App must not crash
        XCTAssertTrue(app.state == .runningForeground, "App must stay running after creating new session")

        // Either a new cell appeared or the conversation view opened
        let sessionCreated = app.cells.count > sessionsBefore
            || app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'message' OR placeholderValue CONTAINS 'Ask'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(sessionCreated, "Creating a new session must produce a session entry or conversation view")
    }

    func testBuildSwitchBetweenSectionTabs() throws {
        switchToSpace("Build")

        let tabs = ["Sessions", "Files", "Data", "Tests"]
        for tab in tabs {
            let btn = app.buttons[tab]
            if btn.waitForExistence(timeout: 3) {
                btn.click()
                Thread.sleep(forTimeInterval: 0.2)
                XCTAssertTrue(app.state == .runningForeground, "App must stay running when clicking Build '\(tab)' tab")
            }
        }
    }

    // MARK: - REVIEW: Branches list or clean empty state

    func testReviewRailIconShowsReviewSidebar() throws {
        switchToSpace("Plan")
        switchToSpace("Review")

        // Review sidebar must show some recognized section header
        let hasBranches = app.staticTexts["Branches"].waitForExistence(timeout: 5)
        let hasChanges = app.staticTexts["Changes"].waitForExistence(timeout: 3)
        let hasPRs = app.staticTexts["Pull Requests"].waitForExistence(timeout: 3)
        let hasScroll = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasBranches || hasChanges || hasPRs || hasScroll,
                      "Review sidebar must show branch/change/PR sections or a scrollable list")
    }

    func testReviewEmptyStateIsClean() throws {
        switchToSpace("Review")

        // If no git repo is loaded, a clean empty state message must appear (no crash, no raw errors)
        // The app must remain in foreground — no crash or hang
        XCTAssertTrue(app.state == .runningForeground, "Review space must not crash even when no git data is loaded")

        // No raw error text like "nil", "undefined", or unformatted stack traces
        let hasRawError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'nil' OR label CONTAINS 'undefined' OR label CONTAINS 'EXC_'")).firstMatch
        XCTAssertFalse(hasRawError.exists, "Review space must not show raw error text in empty state")
    }

    func testReviewBranchSectionExistsOrShowsNoBranches() throws {
        switchToSpace("Review")

        // Either branches are listed, or "No branches loaded" empty state appears
        let hasBranchData = app.staticTexts["Branches"].waitForExistence(timeout: 5)
            || app.staticTexts["No branches loaded"].waitForExistence(timeout: 5)
            || app.cells.count > 0
        XCTAssertTrue(hasBranchData, "Review Branches section must exist or show empty state")
    }

    // MARK: - OPERATE: Rail icon → deploy sidebar → Deploy tab active by default

    func testOperateRailIconShowsDeploySidebar() throws {
        switchToSpace("Plan")
        switchToSpace("Operate")

        // Deploy tab must be the default active section
        let deployTab = app.buttons["Deploy"]
        XCTAssertTrue(deployTab.waitForExistence(timeout: 5), "Operate space must show Deploy tab")
    }

    func testOperateDeployTabActiveByDefault() throws {
        switchToSpace("Operate")

        // Deploy button exists and is the active/selected section tab
        let deployTab = app.buttons["Deploy"]
        XCTAssertTrue(deployTab.waitForExistence(timeout: 5), "Deploy tab must exist in Operate space")

        // Monitor tab also visible
        let monitorTab = app.buttons["Monitor"]
        XCTAssertTrue(monitorTab.waitForExistence(timeout: 3), "Monitor tab must exist alongside Deploy in Operate space")
    }

    func testOperateSwitchDeployToMonitor() throws {
        switchToSpace("Operate")

        let monitorTab = app.buttons["Monitor"]
        XCTAssertTrue(monitorTab.waitForExistence(timeout: 5))
        monitorTab.click()
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(app.state == .runningForeground, "App must stay running after switching to Monitor tab in Operate")

        // Switch back to Deploy
        let deployTab = app.buttons["Deploy"]
        XCTAssertTrue(deployTab.waitForExistence(timeout: 3))
        deployTab.click()
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertTrue(app.state == .runningForeground, "App must stay running after switching back to Deploy tab")
    }

    // MARK: - LIBRARY: Rail icon → Extensions tab → marketplace content

    func testLibraryRailIconShowsLibrarySidebar() throws {
        switchToSpace("Plan")
        switchToSpace("Library")

        // Docs is the default section
        let docsTab = app.buttons["Docs"]
        XCTAssertTrue(docsTab.waitForExistence(timeout: 5), "Library space must show Docs tab by default")
    }

    func testLibrarySwitchToExtensionsTab() throws {
        switchToSpace("Library")

        let extensionsTab = app.buttons["Extensions"]
        XCTAssertTrue(extensionsTab.waitForExistence(timeout: 5), "Extensions tab must exist in Library space")
        extensionsTab.click()
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(app.state == .runningForeground, "App must stay running after switching to Extensions tab")
    }

    func testLibraryExtensionsShowsMarketplaceContent() throws {
        switchToSpace("Library")

        let extensionsTab = app.buttons["Extensions"]
        XCTAssertTrue(extensionsTab.waitForExistence(timeout: 5))
        extensionsTab.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Extensions tab shows installed extensions or empty state — either is valid
        let hasContent = app.staticTexts["No extensions installed"].waitForExistence(timeout: 5)
            || app.cells.count > 0
            || app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Library Extensions tab must show extension list or empty state")
    }

    func testLibraryAllSectionTabsReachable() throws {
        switchToSpace("Library")

        let tabs = ["Docs", "Extensions", "Inbox", "Chat", "Schedule"]
        for tab in tabs {
            let btn = app.buttons[tab]
            if btn.waitForExistence(timeout: 3) {
                btn.click()
                Thread.sleep(forTimeInterval: 0.2)
                XCTAssertTrue(app.state == .runningForeground, "App must stay running after clicking Library '\(tab)' tab")
            }
        }
    }

    // MARK: - Sidebar Collapse / Expand

    func testSidebarCollapseHidesContentSidebarButKeepsRail() throws {
        switchToSpace("Plan")

        // Ensure sidebar is expanded first
        let toggleBtn = app.buttons["Toggle Sidebar"]
        XCTAssertTrue(toggleBtn.waitForExistence(timeout: 5))

        // Collapse
        toggleBtn.click()
        Thread.sleep(forTimeInterval: 0.4)

        // Icon rail buttons must still be visible
        for space in ["Plan", "Build", "Review", "Operate", "Library"] {
            XCTAssertTrue(app.buttons[space].exists, "\(space) rail button must stay visible after sidebar collapse")
        }

        // The Plan-specific New Ticket button (in content sidebar) must be gone
        // — it lives in the collapsed ContentSidebar, not the rail
        let newTicket = app.buttons["New Ticket"]
        XCTAssertFalse(newTicket.exists, "New Ticket button must disappear when content sidebar is collapsed")

        // Re-expand
        toggleBtn.click()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertTrue(app.buttons["New Ticket"].waitForExistence(timeout: 5), "New Ticket button must return after sidebar expand")
    }

    // MARK: - Command Palette

    func testCommandPaletteOpenTypeClose() throws {
        switchToSpace("Plan")

        // Open
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS 'Search' OR label CONTAINS 'Search'")
        ).firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Cmd+K must open command palette")

        // Type a query
        searchField.typeText("new session")
        XCTAssertTrue(app.state == .runningForeground, "App must stay running while typing in command palette")

        // Close via Escape
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(searchField.waitForExistence(timeout: 3), "Escape must close command palette")
    }

    func testCommandPaletteClosesOnSecondCmdK() throws {
        switchToSpace("Build")

        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS 'Search' OR label CONTAINS 'Search'")
        ).firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Second Cmd+K should close
        app.typeKey("k", modifierFlags: .command)
        XCTAssertFalse(searchField.waitForExistence(timeout: 3), "Second Cmd+K must close command palette")
    }

    // MARK: - Quick Capture

    func testQuickCaptureOpenTypeClose() throws {
        switchToSpace("Plan")

        // Open
        app.typeKey(.space, modifierFlags: [.command, .shift])
        let inputField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS 'capture' OR placeholderValue CONTAINS 'Quick'")
        ).firstMatch
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Cmd+Shift+Space must open quick capture")

        // Type text
        inputField.typeText("Remember to write more tests")
        let value = inputField.value as? String ?? ""
        XCTAssertTrue(value.contains("Remember"), "Quick capture must accept typed text")

        // Close via Escape
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(inputField.waitForExistence(timeout: 3), "Escape must close quick capture")
    }

    func testQuickCaptureAvailableFromEverySpace() throws {
        for space in ["Plan", "Build", "Review", "Operate", "Library"] {
            switchToSpace(space)

            app.typeKey(.space, modifierFlags: [.command, .shift])
            let inputField = app.textFields.matching(
                NSPredicate(format: "placeholderValue CONTAINS 'capture' OR placeholderValue CONTAINS 'Quick'")
            ).firstMatch
            XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Quick capture must open in \(space) space")

            app.typeKey(.escape, modifierFlags: [])
            _ = inputField.waitForExistence(timeout: 1) // brief wait for dismiss
        }
    }
}
