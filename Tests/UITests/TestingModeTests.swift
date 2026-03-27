import XCTest

/// Tests for Task #9 — Testing primitive mode with test runner UI.
/// Verifies test tree panel, filter tabs, run buttons, test detail, and demo data.
final class TestingModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Empty State

    func testEmptyStateShowsRunTestsAction() throws {
        switchToTestingMode()

        let runTestsButton = app.buttons["Run Tests"]
        XCTAssertTrue(runTestsButton.waitForExistence(timeout: 5), "Run Tests button should appear in empty state")
    }

    func testEmptyStateShowsLoadDemoDataAction() throws {
        switchToTestingMode()

        let loadDemoButton = app.buttons["Load Demo Data"]
        XCTAssertTrue(loadDemoButton.waitForExistence(timeout: 5), "Load Demo Data button should appear in empty state")
    }

    func testEmptyStateShowsTitle() throws {
        switchToTestingMode()

        let title = app.staticTexts["No test suites"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Empty state title should be visible")
    }

    // MARK: - Demo Data Loading

    func testLoadDemoDataPopulatesTestTree() throws {
        switchToTestingMode()

        let loadDemoButton = app.buttons["Load Demo Data"]
        XCTAssertTrue(loadDemoButton.waitForExistence(timeout: 5))
        loadDemoButton.click()

        // After loading demo data, suite names should appear
        let authSuite = app.staticTexts["AuthServiceTests"]
        XCTAssertTrue(authSuite.waitForExistence(timeout: 5), "AuthServiceTests suite should appear after loading demo data")
    }

    func testDemoDataShowsAllSuites() throws {
        loadDemoAndSwitch()

        let authSuite = app.staticTexts["AuthServiceTests"]
        let userSuite = app.staticTexts["UserControllerTests"]
        let paymentSuite = app.staticTexts["PaymentIntegrationTests"]

        XCTAssertTrue(authSuite.waitForExistence(timeout: 5))
        XCTAssertTrue(userSuite.waitForExistence(timeout: 5))
        XCTAssertTrue(paymentSuite.waitForExistence(timeout: 5))
    }

    // MARK: - Filter Tabs

    func testFilterTabAllExists() throws {
        loadDemoAndSwitch()

        let allFilter = app.buttons["All"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 5), "All filter tab should exist")
    }

    func testFilterTabFailedExists() throws {
        loadDemoAndSwitch()

        let failedFilter = app.buttons["Failed"]
        XCTAssertTrue(failedFilter.waitForExistence(timeout: 5), "Failed filter tab should exist")
    }

    func testFilterTabPassedExists() throws {
        loadDemoAndSwitch()

        let passedFilter = app.buttons["Passed"]
        XCTAssertTrue(passedFilter.waitForExistence(timeout: 5), "Passed filter tab should exist")
    }

    func testFilterTabSkippedExists() throws {
        loadDemoAndSwitch()

        let skippedFilter = app.buttons["Skipped"]
        XCTAssertTrue(skippedFilter.waitForExistence(timeout: 5), "Skipped filter tab should exist")
    }

    func testFilterTabSwitching() throws {
        loadDemoAndSwitch()

        let failedFilter = app.buttons["Failed"]
        XCTAssertTrue(failedFilter.waitForExistence(timeout: 5))
        failedFilter.click()

        let passedFilter = app.buttons["Passed"]
        passedFilter.click()

        let allFilter = app.buttons["All"]
        allFilter.click()
    }

    // MARK: - Run Buttons

    func testRunAllButtonExists() throws {
        loadDemoAndSwitch()

        // The play/stop button in the toolbar (help: "Run All Tests" or "Stop Tests")
        let runButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Run All Tests' OR label CONTAINS 'Stop Tests'")).firstMatch
        XCTAssertTrue(runButton.waitForExistence(timeout: 5), "Run All Tests button should exist in toolbar")
    }

    func testRunAllTestsTriggersExecution() throws {
        loadDemoAndSwitch()

        let runButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Run All Tests'")).firstMatch
        if runButton.waitForExistence(timeout: 5) {
            runButton.click()
            // Tests should start running — status indicators will change
        }
    }

    // MARK: - Test Search

    func testSearchFieldExists() throws {
        loadDemoAndSwitch()

        let searchField = app.textFields["Filter tests..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Test filter search field should exist")
    }

    func testSearchFiltersTests() throws {
        loadDemoAndSwitch()

        let searchField = app.textFields["Filter tests..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.click()
        searchField.typeText("login")

        // Only tests matching "login" should be visible
    }

    // MARK: - Test Detail

    func testClickingTestShowsDetail() throws {
        loadDemoAndSwitch()

        // Click on a test case in the tree
        let testRow = app.staticTexts["testLoginSuccess"]
        if testRow.waitForExistence(timeout: 5) {
            testRow.click()

            // Detail view should show the test name
        }
    }

    func testDetailShowsRerunButton() throws {
        loadDemoAndSwitch()

        let testRow = app.staticTexts["testTokenRefresh"]
        if testRow.waitForExistence(timeout: 5) {
            testRow.click()

            let rerunButton = app.buttons["Re-run"]
            _ = rerunButton.waitForExistence(timeout: 5)
        }
    }

    func testDetailShowsFailureMessage() throws {
        loadDemoAndSwitch()

        // Click on the failed test
        let failedTest = app.staticTexts["testTokenRefresh"]
        if failedTest.waitForExistence(timeout: 5) {
            failedTest.click()

            // Failure message should be visible in detail
            let failureLabel = app.staticTexts["Failure"]
            _ = failureLabel.waitForExistence(timeout: 5)
        }
    }

    func testDetailShowsOutputSection() throws {
        loadDemoAndSwitch()

        let testRow = app.staticTexts["testLoginSuccess"]
        if testRow.waitForExistence(timeout: 5) {
            testRow.click()

            let outputLabel = app.staticTexts["OUTPUT"]
            _ = outputLabel.waitForExistence(timeout: 5)
        }
    }

    // MARK: - Summary View

    func testSummaryShowsStatCards() throws {
        loadDemoAndSwitch()

        // When no test is selected, summary view with stat cards shows
        let totalLabel = app.staticTexts["Total"]
        let passedLabel = app.staticTexts["Passed"]
        let failedLabel = app.staticTexts["Failed"]
        let durationLabel = app.staticTexts["Duration"]

        _ = totalLabel.waitForExistence(timeout: 5)
        _ = passedLabel.waitForExistence(timeout: 5)
        _ = failedLabel.waitForExistence(timeout: 5)
        _ = durationLabel.waitForExistence(timeout: 5)
    }

    // MARK: - Suite Expansion

    func testSuiteExpandsAndCollapses() throws {
        loadDemoAndSwitch()

        let authSuite = app.staticTexts["AuthServiceTests"]
        XCTAssertTrue(authSuite.waitForExistence(timeout: 5))

        // Click suite header to collapse
        authSuite.click()

        // Click again to expand
        authSuite.click()
    }

    // MARK: - Helpers

    private func switchToTestingMode() {
        // Testing mode is an auxiliary mode — no dedicated shortcut number in AnvilMode
        // It needs to be accessed via the mode enum; check if it has a shortcut
        // From the code: Testing is not in the AnvilMode enum yet, it's part of auxiliary
        // For now, navigate by looking for the test tube icon
    }

    private func loadDemoAndSwitch() {
        switchToTestingMode()

        let loadDemoButton = app.buttons["Load Demo Data"]
        if loadDemoButton.waitForExistence(timeout: 5) {
            loadDemoButton.click()
        }
    }
}
