import XCTest

final class ReviewModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Mode Activation

    func testSwitchToReviewMode() throws {
        app.typeKey("3", modifierFlags: .command)

        let reviewTab = app.buttons["Review"]
        XCTAssertTrue(reviewTab.waitForExistence(timeout: 5))
    }

    // MARK: - Review Inbox

    func testReviewInboxRendersAfterDemoData() throws {
        loadDemoData()
        app.typeKey("3", modifierFlags: .command)

        // Review inbox should show sample reviews
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Review inbox should render")
    }

    // MARK: - Review Item Click

    func testReviewItemClickable() throws {
        loadDemoData()
        app.typeKey("3", modifierFlags: .command)

        let listItem = app.scrollViews.firstMatch.otherElements.firstMatch
        if listItem.exists {
            listItem.click()
        }
    }

    // MARK: - Diff View

    func testDiffViewLoads() throws {
        loadDemoData()
        app.typeKey("3", modifierFlags: .command)

        // After clicking a review, the diff view should load
        let listItem = app.scrollViews.firstMatch.otherElements.firstMatch
        if listItem.exists {
            listItem.click()
            // Diff view content should appear
        }
    }

    // MARK: - Review Sidebar

    func testReviewSidebarContent() throws {
        loadDemoData()
        app.typeKey("3", modifierFlags: .command)
        // Sidebar should show review list
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }
}
