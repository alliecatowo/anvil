import XCTest

final class AppLaunchTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Window

    func testAppLaunches() throws {
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should appear on launch")
    }

    func testMainWindowHasExpectedSize() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        XCTAssertGreaterThan(window.frame.width, 800, "Window should be at least 800pt wide")
        XCTAssertGreaterThan(window.frame.height, 600, "Window should be at least 600pt tall")
    }

    // MARK: - Space Rail

    func testSpaceRailIsVisible() throws {
        // Space rail buttons should be visible
        let planButton = app.buttons["Plan"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 5), "Plan rail button should be visible")

        let buildButton = app.buttons["Build"]
        XCTAssertTrue(buildButton.exists, "Build rail button should be visible")

        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.exists, "Review rail button should be visible")

        let operateButton = app.buttons["Operate"]
        XCTAssertTrue(operateButton.exists, "Operate rail button should be visible")

        let libraryButton = app.buttons["Library"]
        XCTAssertTrue(libraryButton.exists, "Library rail button should be visible")
    }

    func testSearchButtonIsVisible() throws {
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Search'")).firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "Search button should be visible in tab bar")
    }

    // MARK: - Status Bar

    func testStatusBarIsVisible() throws {
        // The settings gear should be visible in the status bar
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings'")).firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should be visible in status bar")
    }

    func testStatusBarShowsBranch() throws {
        // Branch picker button should exist
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5), "Branch button should be visible in status bar")
    }
}

final class DefaultJourneySmokeTests: AnvilUITestCase {
    override var launchEnvironment: [String: String] {
        ["ANVIL_SKIP_SETUP_WIZARD": "1"]
    }

    override var shouldCaptureLaunchScreenshot: Bool { false }
    override var shouldCaptureTearDownScreenshot: Bool { false }

    func testDefaultLaunchExposesCoreSpacesAndUtilities() throws {
        for label in ["Plan", "Build", "Review", "Operate", "Library"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5), "\(label) space must be visible on default launch")
        }

        XCTAssertTrue(app.buttons["Find in Project"].waitForExistence(timeout: 5), "Global project search should stay reachable")
        XCTAssertTrue(app.buttons["Toggle Inspector"].waitForExistence(timeout: 5), "Inspector toggle should stay reachable")
    }

    func testDefaultIntentJourneyCanOpenTicketDetailInMainPane() throws {
        switchToSpace("Plan")

        let newTicket = app.buttons["intent.sidebar.new-ticket"]
        XCTAssertTrue(newTicket.waitForExistence(timeout: 5), "Plan space must expose New Ticket")
        newTicket.click()

        let titleField = app.textFields["intent.sidebar.quick-add-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Ticket quick-add must appear")

        let title = "Smoke ticket \(Int.random(in: 1000...9999))"
        titleField.typeText(title)
        app.typeKey(.return, modifierFlags: [])

        let detailTitle = app.textFields["intent.ticket-detail.title"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 5), "Ticket must open into the main-pane detail view")
        XCTAssertTrue(app.buttons["intent.ticket-detail.back"].waitForExistence(timeout: 5), "Ticket detail must expose a Back action")
    }

    func testDefaultBuildJourneyExposesEditorAndAgentConversation() throws {
        switchToSpace("Build")

        for label in ["Sessions", "Files", "Data", "Tests", "Terminal"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5), "Build space must expose \(label)")
        }

        app.buttons["Files"].click()
        XCTAssertTrue(app.staticTexts["Explorer"].waitForExistence(timeout: 5), "Files must route into the editor surface")

        app.buttons["Sessions"].click()
        let sidebarNewSession = app.buttons["agent.sidebar.new-session"]
        let emptyNewSession = app.buttons["agent.empty.new-session"]
        let newSession = emptyNewSession.waitForExistence(timeout: 2) ? emptyNewSession : sidebarNewSession
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Build sessions must remain discoverable in default launch")
        newSession.click()

        let messageField = app.descendants(matching: .any).matching(identifier: "agent.conversation.input").firstMatch
        XCTAssertTrue(messageField.waitForExistence(timeout: 8), "New Session must open the agent conversation surface")

        let infoButton = app.buttons["agent.conversation.toggle-sidebar"]
        XCTAssertTrue(infoButton.waitForExistence(timeout: 5), "Build conversation must expose the info/secondary-pane control")
    }

    func testDefaultReviewAndRulesJourneysStayReachable() throws {
        switchToSpace("Review")

        let branchesHeader = app.buttons.matching(NSPredicate(format: "label == 'Branches'")).firstMatch
        XCTAssertTrue(branchesHeader.waitForExistence(timeout: 5), "Review space must expose branches")
        branchesHeader.click()
        let reviewAnchor = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'No branches loaded' OR label CONTAINS[c] 'Branch ' OR label CONTAINS[c] 'Pull Requests'")).firstMatch
        XCTAssertTrue(reviewAnchor.waitForExistence(timeout: 5), "Review space must expose branches, pull requests, or a clean empty state")

        switchToSpace("Library")
        let rulesTab = app.buttons["Rules"]
        XCTAssertTrue(rulesTab.waitForExistence(timeout: 5), "Library space must expose Rules")
        rulesTab.click()

        let rulesAnchor = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Project Rules' OR label CONTAINS[c] 'Open a project'")).firstMatch
        XCTAssertTrue(rulesAnchor.waitForExistence(timeout: 5), "Rules panel must remain discoverable without seeded data")
    }

    private func switchToSpace(_ label: String) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Space button \(label) must exist")
        button.click()
        _ = app.windows.firstMatch.waitForExistence(timeout: 2)
    }
}
