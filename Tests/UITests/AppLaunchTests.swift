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
