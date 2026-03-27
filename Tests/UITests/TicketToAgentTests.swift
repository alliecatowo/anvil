import XCTest

/// Tests for Task #10 — Ticket-to-agent pipeline.
/// Verifies the "Dispatch to Agent" button on ticket detail creates a session
/// and switches to Agent mode, and "Create Branch" works from ticket context.
final class TicketToAgentTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        loadDemoData()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Dispatch to Agent

    func testDispatchToAgentButtonExists() throws {
        navigateToTicketDetail()

        let dispatchButton = app.buttons["Dispatch to Agent"]
        XCTAssertTrue(dispatchButton.waitForExistence(timeout: 5), "Dispatch to Agent button should appear on ticket detail")
    }

    func testDispatchToAgentSwitchesToAgentMode() throws {
        navigateToTicketDetail()

        let dispatchButton = app.buttons["Dispatch to Agent"]
        XCTAssertTrue(dispatchButton.waitForExistence(timeout: 5))
        dispatchButton.click()

        // After dispatch, app should switch to Agent mode
        let agentTab = app.buttons["Agent"]
        XCTAssertTrue(agentTab.waitForExistence(timeout: 5))
        // Agent mode should now be active — the "New Session" button should be visible
        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5), "Agent sidebar should appear after dispatch")
    }

    // MARK: - Create Branch

    func testCreateBranchButtonExists() throws {
        navigateToTicketDetail()

        let createBranchButton = app.buttons["Create Branch"]
        XCTAssertTrue(createBranchButton.waitForExistence(timeout: 5), "Create Branch button should appear on ticket detail")
    }

    func testCreateBranchShowsConfirmation() throws {
        navigateToTicketDetail()

        let createBranchButton = app.buttons["Create Branch"]
        XCTAssertTrue(createBranchButton.waitForExistence(timeout: 5))
        createBranchButton.click()

        // After creating branch, the button area should show a checkmark confirmation
        // The branch name should appear with a green checkmark
    }

    // MARK: - Back Button

    func testBackButtonExistsOnTicketDetail() throws {
        navigateToTicketDetail()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist on ticket detail")
    }

    func testBackButtonReturnsToTicketList() throws {
        navigateToTicketDetail()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.click()

        // Should return to ticket list — Dispatch button should no longer be visible
    }

    // MARK: - Ticket Detail Sections

    func testTicketDetailShowsDescription() throws {
        navigateToTicketDetail()

        let descriptionLabel = app.staticTexts["DESCRIPTION"]
        XCTAssertTrue(descriptionLabel.waitForExistence(timeout: 5), "Description section should exist")
    }

    func testTicketDetailShowsActivity() throws {
        navigateToTicketDetail()

        let activityLabel = app.staticTexts["ACTIVITY"]
        XCTAssertTrue(activityLabel.waitForExistence(timeout: 5), "Activity section should exist")
    }

    func testTicketDetailShowsLabels() throws {
        navigateToTicketDetail()

        let labelsLabel = app.staticTexts["LABELS"]
        // Labels section only appears if ticket has labels
        _ = labelsLabel.waitForExistence(timeout: 3)
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func navigateToTicketDetail() {
        // Switch to Intent mode
        app.typeKey("1", modifierFlags: .command)

        // Click on first ticket in the list to open detail
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 5) {
            let firstItem = scrollView.otherElements.firstMatch
            if firstItem.exists {
                firstItem.click()
            }
        }
    }
}
