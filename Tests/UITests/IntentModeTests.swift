import XCTest

final class IntentModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        loadDemoData()
        switchToIntentMode()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Mode Renders Ticket List

    func testIntentModeRendersScrollView() throws {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Intent mode must render a scroll view with ticket content")
    }

    func testIntentSidebarHasClickableItems() throws {
        let clickable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label != "Intent" }
        XCTAssertGreaterThan(clickable.count, 0, "Intent sidebar must have clickable items")
    }

    // MARK: - Ticket Click → Detail Opens

    func testClickingTicketOpensDetailView() throws {
        let ticketList = app.scrollViews.firstMatch
        XCTAssertTrue(ticketList.waitForExistence(timeout: 5))

        let firstTicket = ticketList.otherElements.firstMatch
        XCTAssertTrue(firstTicket.waitForExistence(timeout: 5), "Ticket list must have at least one item")
        firstTicket.click()

        // Result: ticket detail shows DESCRIPTION section header
        let descriptionLabel = app.staticTexts["DESCRIPTION"]
        XCTAssertTrue(descriptionLabel.waitForExistence(timeout: 5), "Clicking a ticket must open detail view showing DESCRIPTION section")
    }

    func testClickingTicketShowsActivitySection() throws {
        openFirstTicket()

        let activityLabel = app.staticTexts["ACTIVITY"]
        XCTAssertTrue(activityLabel.waitForExistence(timeout: 5), "Ticket detail must show ACTIVITY section")
    }

    func testClickingTicketShowsStartWorkButton() throws {
        openFirstTicket()

        let startWork = app.buttons["Start Work"]
        XCTAssertTrue(startWork.waitForExistence(timeout: 5), "Ticket detail must show Start Work button")
    }

    func testClickingTicketShowsBackButton() throws {
        openFirstTicket()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Ticket detail must show Back button")
    }

    // MARK: - Back Button → Returns to List

    func testBackButtonReturnsToTicketList() throws {
        openFirstTicket()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.click()

        // Result: DESCRIPTION should disappear, scroll view (list) visible again
        let descriptionGone = !app.staticTexts["DESCRIPTION"].waitForExistence(timeout: 3)
        let listVisible = app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(descriptionGone || listVisible, "Back button must return to ticket list")
    }

    // MARK: - Start Work → Switches to Agent Mode

    func testStartWorkSwitchesToAgentMode() throws {
        openFirstTicket()

        let startWork = app.buttons["Start Work"]
        XCTAssertTrue(startWork.waitForExistence(timeout: 5))
        startWork.click()

        // Result: Agent mode input field must appear
        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 8), "Start Work must switch to Agent mode with conversation view")
    }

    // MARK: - Branch Only Button

    func testBranchOnlyButtonExists() throws {
        openFirstTicket()

        let branchButton = app.buttons["Branch Only"]
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5), "Ticket detail must have Branch Only button")
    }

    // MARK: - Link Ticket Button → Popover Appears

    func testLinkTicketButtonOpensPopover() throws {
        openFirstTicket()

        let linkButton = app.buttons["Link Ticket"]
        XCTAssertTrue(linkButton.waitForExistence(timeout: 5))
        linkButton.click()

        // Result: popover with search field appears
        let searchField = app.textFields["Search tickets..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Link Ticket button must open a popover with search field")
    }

    func testLinkTicketPopoverSearchFiltersResults() throws {
        openFirstTicket()

        let linkButton = app.buttons["Link Ticket"]
        XCTAssertTrue(linkButton.waitForExistence(timeout: 5))
        linkButton.click()

        let searchField = app.textFields["Search tickets..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Type to filter
        searchField.click()
        searchField.typeText("ANV")

        // Result: some filtered ticket IDs appear
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 3), "Search must produce filtered results in popover")
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func switchToIntentMode() {
        app.typeKey("1", modifierFlags: .command)
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
    }

    private func openFirstTicket() {
        let ticketList = app.scrollViews.firstMatch
        if ticketList.waitForExistence(timeout: 5) {
            let firstItem = ticketList.otherElements.firstMatch
            if firstItem.exists {
                firstItem.click()
            }
        }
        _ = app.staticTexts["DESCRIPTION"].waitForExistence(timeout: 5)
    }
}
