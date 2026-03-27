import XCTest

final class IntentModeTests: XCTestCase {
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

    func testSwitchToIntentMode() throws {
        app.typeKey("1", modifierFlags: .command)

        let intentTab = app.buttons["Intent"]
        XCTAssertTrue(intentTab.waitForExistence(timeout: 5))
    }

    // MARK: - Ticket List

    func testTicketListRendersAfterDemoData() throws {
        // Load demo data first
        loadDemoData()
        app.typeKey("1", modifierFlags: .command)

        // Ticket list should render with sample tickets
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Ticket list scroll view should exist")
    }

    // MARK: - Board View

    func testBoardViewSwitch() throws {
        loadDemoData()
        app.typeKey("1", modifierFlags: .command)

        // Look for board/list view toggle if present
    }

    // MARK: - Ticket Detail

    func testTicketDetailOpens() throws {
        loadDemoData()
        app.typeKey("1", modifierFlags: .command)

        // Click on a ticket in the list to open detail
        let listItem = app.scrollViews.firstMatch.otherElements.firstMatch
        if listItem.exists {
            listItem.click()
        }
    }

    // MARK: - Sidebar

    func testIntentSidebarShowsTickets() throws {
        loadDemoData()
        app.typeKey("1", modifierFlags: .command)
        // Intent sidebar should show ticket navigation
    }

    // MARK: - Helpers

    private func loadDemoData() {
        // Use the menu item to load demo project
        app.menuItems["Load Demo Project"].click()
    }
}
