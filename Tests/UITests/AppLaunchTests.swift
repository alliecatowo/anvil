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

    // MARK: - Mode Tab Bar

    func testModeTabBarIsVisible() throws {
        // Core modes should be visible as buttons
        let agentButton = app.buttons["Agent"]
        XCTAssertTrue(agentButton.waitForExistence(timeout: 5), "Agent mode tab should be visible")

        let intentButton = app.buttons["Intent"]
        XCTAssertTrue(intentButton.exists, "Intent mode tab should be visible")

        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.exists, "Review mode tab should be visible")

        let shipButton = app.buttons["Ship"]
        XCTAssertTrue(shipButton.exists, "Ship mode tab should be visible")
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
