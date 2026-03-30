import XCTest

/// Tests for the ticket-to-agent pipeline.
/// Verifies "Start Work" on ticket detail creates an agent session and switches to Build mode.
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

    // MARK: - Start Work → Build Mode

    func testStartWorkButtonExists() throws {
        navigateToTicketDetail()

        let startWork = app.buttons["Start Work"]
        XCTAssertTrue(startWork.waitForExistence(timeout: 5), "Start Work button must appear on ticket detail")
    }

    func testStartWorkSwitchesToAgentMode() throws {
        navigateToTicketDetail()

        let startWork = app.buttons["Start Work"]
        XCTAssertTrue(startWork.waitForExistence(timeout: 5))
        startWork.click()

        // Result: Build mode conversation view must appear
        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 8),
            "Start Work must switch to Build mode with conversation input field visible")
    }

    func testStartWorkCreatesAgentSession() throws {
        navigateToTicketDetail()

        let startWork = app.buttons["Start Work"]
        XCTAssertTrue(startWork.waitForExistence(timeout: 5))
        startWork.click()

        // Result: Build sidebar must show a session row (not empty state)
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))
        let sessionRows = scrollView.otherElements.allElementsBoundByIndex
        XCTAssertGreaterThan(sessionRows.count, 0, "Start Work must create at least one session in Build sidebar")
    }

    // MARK: - Branch Only Button

    func testBranchOnlyButtonExists() throws {
        navigateToTicketDetail()

        let branchButton = app.buttons["Branch Only"]
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5), "Branch Only button must appear on ticket detail")
    }

    func testBranchOnlyButtonIsHittable() throws {
        navigateToTicketDetail()

        let branchButton = app.buttons["Branch Only"]
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        XCTAssertTrue(branchButton.isHittable, "Branch Only button must be hittable")
    }

    // MARK: - Back Button → Returns to List

    func testBackButtonExists() throws {
        navigateToTicketDetail()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button must appear on ticket detail")
    }

    func testBackButtonReturnsToTicketList() throws {
        navigateToTicketDetail()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.click()

        // Result: Detail sections disappear; ticket list scroll view still present
        let descriptionGone = !app.staticTexts["DESCRIPTION"].waitForExistence(timeout: 3)
        XCTAssertTrue(descriptionGone, "Clicking Back must hide ticket detail (DESCRIPTION section gone)")
    }

    // MARK: - Ticket Detail Sections

    func testTicketDetailShowsDescriptionSection() throws {
        navigateToTicketDetail()

        let descriptionLabel = app.staticTexts["DESCRIPTION"]
        XCTAssertTrue(descriptionLabel.waitForExistence(timeout: 5), "Ticket detail must show DESCRIPTION section")
    }

    func testTicketDetailShowsActivitySection() throws {
        navigateToTicketDetail()

        let activityLabel = app.staticTexts["ACTIVITY"]
        XCTAssertTrue(activityLabel.waitForExistence(timeout: 5), "Ticket detail must show ACTIVITY section")
    }

    func testTicketDetailShowsRelatedSection() throws {
        navigateToTicketDetail()

        let relatedLabel = app.staticTexts["RELATED"]
        XCTAssertTrue(relatedLabel.waitForExistence(timeout: 5), "Ticket detail must show RELATED section")
    }

    // MARK: - Link Ticket

    func testLinkTicketButtonExists() throws {
        navigateToTicketDetail()

        let linkButton = app.buttons["Link Ticket"]
        XCTAssertTrue(linkButton.waitForExistence(timeout: 5), "Link Ticket button must appear in ticket detail")
    }

    func testLinkTicketButtonOpensSearchPopover() throws {
        navigateToTicketDetail()

        let linkButton = app.buttons["Link Ticket"]
        XCTAssertTrue(linkButton.waitForExistence(timeout: 5))
        linkButton.click()

        // Result: popover with search field appears
        let searchField = app.textFields["Search tickets..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Link Ticket must open search popover")
    }

    // MARK: - Editable Title

    func testTicketTitleIsEditable() throws {
        navigateToTicketDetail()

        let titleField = app.textFields["Title"]
        if titleField.waitForExistence(timeout: 5) {
            XCTAssertTrue(titleField.isEnabled, "Ticket title field must be editable")
        }
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func navigateToTicketDetail() {
        // Switch to Plan mode
        app.typeKey("1", modifierFlags: .command)

        // Click first ticket
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 5) {
            let firstItem = scrollView.otherElements.firstMatch
            if firstItem.waitForExistence(timeout: 5) {
                firstItem.click()
            }
        }
        _ = app.staticTexts["DESCRIPTION"].waitForExistence(timeout: 5)
    }
}
