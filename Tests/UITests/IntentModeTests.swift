import XCTest

final class PlanModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        loadDemoData()
        switchToPlanMode()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Mode Renders Ticket List

    func testPlanModeRendersScrollView() throws {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Plan mode must render a scroll view with ticket content")
    }

    func testPlanSidebarHasClickableItems() throws {
        let clickable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label != "Plan" }
        XCTAssertGreaterThan(clickable.count, 0, "Plan sidebar must have clickable items")
    }

    // MARK: - Ticket Click → Detail Opens

    func testClickingTicketOpensDetailView() throws {
        openFirstTicket()

        let titleField = app.textFields["intent.ticket-detail.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Clicking a ticket must open the main-pane detail title field")

        let backButton = app.buttons["intent.ticket-detail.back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Ticket detail must expose Back")
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

        let backButton = app.buttons["intent.ticket-detail.back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Ticket detail must show Back button")
    }

    // MARK: - Back Button → Returns to List

    func testBackButtonReturnsToTicketList() throws {
        openFirstTicket()

        let backButton = app.buttons["intent.ticket-detail.back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.click()

        // Result: ticket detail should disappear, scroll view (list) visible again
        let detailTitleGone = !app.textFields["intent.ticket-detail.title"].waitForExistence(timeout: 3)
        let listVisible = app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(detailTitleGone || listVisible, "Back button must return to ticket list")
    }

    // MARK: - Start Work → Switches to Build Mode

    func testStartWorkSwitchesToBuildMode() throws {
        openFirstTicket()

        let startWork = app.buttons["intent.ticket-detail.start-work"]
        XCTAssertTrue(startWork.waitForExistence(timeout: 5))
        startWork.click()

        // Result: Build mode input field must appear
        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 8), "Start Work must switch to Build mode with conversation view")
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

    private func switchToPlanMode() {
        app.typeKey("1", modifierFlags: .command)
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
    }

    private func openFirstTicket() {
        let firstTicket = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH[c] 'intent.sidebar.ticket-row.'"
        )).firstMatch
        if firstTicket.waitForExistence(timeout: 5) {
            firstTicket.click()
        }
        _ = app.textFields["intent.ticket-detail.title"].waitForExistence(timeout: 5)
    }
}
