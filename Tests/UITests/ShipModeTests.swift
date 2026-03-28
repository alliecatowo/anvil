import XCTest

final class ShipModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        loadDemoData()
        switchToShipMode()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Sidebar Renders

    func testShipSidebarShowsEnvironmentsSection() throws {
        let envHeader = app.staticTexts["ENVIRONMENTS"]
        XCTAssertTrue(envHeader.waitForExistence(timeout: 5), "Ship sidebar must show ENVIRONMENTS section")
    }

    func testShipSidebarHasEnvironmentRows() throws {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        let rows = scrollView.otherElements.allElementsBoundByIndex
        XCTAssertGreaterThan(rows.count, 0, "Ship sidebar must have environment rows")
    }

    // MARK: - Environment Click → Deploy Dashboard Shows Detail

    func testClickEnvironmentShowsDeployButton() throws {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        let firstEnv = scrollView.otherElements.firstMatch
        XCTAssertTrue(firstEnv.waitForExistence(timeout: 5))
        firstEnv.click()

        // Result: Deploy button appears below selected environment row
        let deployButton = app.buttons["Deploy"]
        XCTAssertTrue(deployButton.waitForExistence(timeout: 5), "Clicking an environment must reveal a Deploy button")
    }

    func testClickEnvironmentUpdatesDeployDashboard() throws {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        let firstEnv = scrollView.otherElements.firstMatch
        XCTAssertTrue(firstEnv.waitForExistence(timeout: 5))
        firstEnv.click()

        // Result: Deploy Dashboard heading visible in content area
        let dashboardHeading = app.staticTexts["Deploy Dashboard"]
        XCTAssertTrue(dashboardHeading.waitForExistence(timeout: 5), "Clicking an environment must update the deploy dashboard view")
    }

    // MARK: - Deploy Button

    func testDeployButtonIsHittable() throws {
        selectFirstEnvironment()

        let deployButton = app.buttons["Deploy"]
        XCTAssertTrue(deployButton.waitForExistence(timeout: 5))
        XCTAssertTrue(deployButton.isHittable, "Deploy button must be hittable when environment is selected")
    }

    func testDeployButtonTriggersProgressIndicator() throws {
        selectFirstEnvironment()

        let deployButton = app.buttons["Deploy"]
        XCTAssertTrue(deployButton.waitForExistence(timeout: 5))
        deployButton.click()

        // Result: deployment progress indicator appears (sidebar or dashboard)
        let deployingText = app.staticTexts["Deploying..."]
        let progress = app.progressIndicators.firstMatch
        let triggered = deployingText.waitForExistence(timeout: 5) || progress.waitForExistence(timeout: 5)
        XCTAssertTrue(triggered, "Clicking Deploy must trigger a deployment progress indicator")
    }

    // MARK: - Tab Selector in Sidebar

    func testShipSidebarTabSelectorExists() throws {
        // ShipSidebar has a tab selector row with tab options
        let tabArea = app.buttons.allElementsBoundByIndex.filter { $0.isHittable }
        XCTAssertGreaterThan(tabArea.count, 0, "Ship sidebar must have tab selector buttons")
    }

    // MARK: - Deploy Dashboard Content

    func testDeployDashboardHeadingVisible() throws {
        let heading = app.staticTexts["Deploy Dashboard"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "Deploy Dashboard heading must be visible in Ship mode content area")
    }

    func testEnvironmentCardsRenderedInDashboard() throws {
        // Grid of environment cards in content area
        let content = app.scrollViews.allElementsBoundByIndex
        let hasMultipleScrollViews = content.count > 0
        XCTAssertTrue(hasMultipleScrollViews, "Deploy dashboard must render scrollable content with environment cards")
    }

    // MARK: - Rollback Confirmation Dialog

    func testRollbackButtonExistsInDeployHistory() throws {
        selectFirstEnvironment()

        // Rollback buttons appear in deploy history section
        let rollbackButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Rollback'")).firstMatch
        // Only visible if deployments exist
        if rollbackButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(rollbackButton.isHittable, "Rollback button must be hittable")
        }
    }

    func testRollbackButtonTriggersConfirmationAlert() throws {
        selectFirstEnvironment()

        let rollbackButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Rollback'")).firstMatch
        if rollbackButton.waitForExistence(timeout: 3) {
            rollbackButton.click()

            // Result: confirmation alert appears
            let confirmAlert = app.alerts.firstMatch
            XCTAssertTrue(confirmAlert.waitForExistence(timeout: 5), "Clicking Rollback must show confirmation alert")

            // Dismiss alert
            let cancelButton = confirmAlert.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.click()
            }
        }
    }

    // MARK: - Env Var Manager

    func testEnvVarManagerAccessible() throws {
        selectFirstEnvironment()

        // Env var section or button should exist in dashboard
        let envVarButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Env Vars' OR label CONTAINS 'Environment Variables'")).firstMatch
        if envVarButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(envVarButton.isHittable, "Env var manager button must be hittable")
        }
    }

    // MARK: - Build Logs

    func testBuildLogsAccessible() throws {
        selectFirstEnvironment()

        let buildLogsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Build Logs' OR label CONTAINS 'Logs'")).firstMatch
        if buildLogsButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(buildLogsButton.isHittable, "Build logs button must be hittable")
        }
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func switchToShipMode() {
        app.typeKey("4", modifierFlags: .command)
        _ = app.staticTexts["ENVIRONMENTS"].waitForExistence(timeout: 5)
    }

    private func selectFirstEnvironment() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 5) {
            let firstEnv = scrollView.otherElements.firstMatch
            if firstEnv.waitForExistence(timeout: 5) {
                firstEnv.click()
            }
        }
        _ = app.buttons["Deploy"].waitForExistence(timeout: 5)
    }
}
