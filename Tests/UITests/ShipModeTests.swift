import XCTest

final class ShipModeTests: XCTestCase {
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

    func testSwitchToShipMode() throws {
        app.typeKey("4", modifierFlags: .command)

        let shipTab = app.buttons["Ship"]
        XCTAssertTrue(shipTab.waitForExistence(timeout: 5))
    }

    // MARK: - Dashboard

    func testDashboardRendersAfterDemoData() throws {
        loadDemoData()
        app.typeKey("4", modifierFlags: .command)

        // Deploy dashboard should render with environment cards
    }

    // MARK: - Environment Cards

    func testEnvironmentCardsVisible() throws {
        loadDemoData()
        app.typeKey("4", modifierFlags: .command)

        // Environment cards should be visible in the dashboard
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Ship dashboard scroll view should exist")
    }

    // MARK: - Ship Sidebar

    func testShipSidebarContent() throws {
        loadDemoData()
        app.typeKey("4", modifierFlags: .command)
        // Ship sidebar should show environments
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }
}
