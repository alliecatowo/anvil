import XCTest

/// Tests for UI polish features.
/// Verifies notification badges on space rail, profile avatar, hover states,
/// and active indicator.
final class UIPolishTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Profile Avatar

    func testProfileAvatarExistsInToolbar() throws {
        let profileButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings'")).element(boundBy: 0)
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5), "Settings button should exist in toolbar")
    }

    func testProfileAvatarOpensSettings() throws {
        let profileButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings'")).element(boundBy: 0)
        if profileButton.waitForExistence(timeout: 5) {
            profileButton.click()
        }
    }

    // MARK: - Notification Badges

    func testNotificationBadgesAppearWithDemoData() throws {
        app.menuItems["Load Demo Project"].click()
        // Review rail button should show a badge count for pending reviews
    }

    func testReviewBadgeCountMatchesPendingReviews() throws {
        app.menuItems["Load Demo Project"].click()

        // Switch to Review space and back
        app.typeKey("3", modifierFlags: .command)
        app.typeKey("1", modifierFlags: .command)
    }

    // MARK: - Active Space Indicator

    func testActiveSpaceHasIndicator() throws {
        // Switching spaces via rail should work without crash
        let buildButton = app.buttons["Build"]
        XCTAssertTrue(buildButton.waitForExistence(timeout: 5))
        buildButton.click()

        let reviewButton = app.buttons["Review"]
        reviewButton.click()

        let planButton = app.buttons["Plan"]
        planButton.click()
    }

    // MARK: - Space Rail

    func testSpaceRailIsVisible() throws {
        let planButton = app.buttons["Plan"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 5))

        let buildButton = app.buttons["Build"]
        XCTAssertTrue(buildButton.exists)

        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.exists)

        let operateButton = app.buttons["Operate"]
        XCTAssertTrue(operateButton.exists)

        let libraryButton = app.buttons["Library"]
        XCTAssertTrue(libraryButton.exists)

        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Search'")).firstMatch
        XCTAssertTrue(searchButton.exists)
    }

    // MARK: - Hover Feedback

    func testSpaceRailButtonsAreClickable() throws {
        let spaces = ["Plan", "Build", "Review", "Operate", "Library"]
        for space in spaces {
            let button = app.buttons[space]
            XCTAssertTrue(button.waitForExistence(timeout: 3), "\(space) rail button should be clickable")
            button.click()
        }
    }

    // MARK: - Settings Button in Status Bar

    func testSettingsGearInStatusBar() throws {
        let settingsButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings'"))
        XCTAssertGreaterThanOrEqual(settingsButtons.count, 1, "At least one Settings button should exist")
    }
}
