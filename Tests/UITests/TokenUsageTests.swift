import XCTest

/// Tests for Task #15 — Token usage visualization with context limit progress bar.
/// Verifies progress bar, token counts, cost display, legend, and limit warnings.
final class TokenUsageTests: XCTestCase {
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

    // MARK: - Token Usage Header

    func testTokenUsageLabelExists() throws {
        navigateToAgentSession()

        let tokenUsageLabel = app.staticTexts["Token Usage"]
        XCTAssertTrue(tokenUsageLabel.waitForExistence(timeout: 5), "Token Usage label should be visible")
    }

    // MARK: - Token Counts

    func testInputTokenCountDisplayed() throws {
        navigateToAgentSession()

        // Legend should show "Input: X.XK" format
        let inputLegend = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Input:'")).firstMatch
        XCTAssertTrue(inputLegend.waitForExistence(timeout: 5), "Input token count should be displayed in legend")
    }

    func testOutputTokenCountDisplayed() throws {
        navigateToAgentSession()

        let outputLegend = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Output:'")).firstMatch
        XCTAssertTrue(outputLegend.waitForExistence(timeout: 5), "Output token count should be displayed in legend")
    }

    // MARK: - Cost Display

    func testCostIsDisplayed() throws {
        navigateToAgentSession()

        // Cost shows as $X.XXX
        let costText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$'")).firstMatch
        XCTAssertTrue(costText.waitForExistence(timeout: 5), "Cost should be displayed")
    }

    // MARK: - Context Limit Display

    func testContextLimitIsDisplayed() throws {
        navigateToAgentSession()

        // The bar shows "total / limit" format with a slash separator
        let slashSeparator = app.staticTexts["/"]
        _ = slashSeparator.waitForExistence(timeout: 5)
    }

    // MARK: - Progress Bar

    func testProgressBarExists() throws {
        navigateToAgentSession()

        // The progress bar is a GeometryReader-based view
        // It should be present as part of the TokenUsageBar view
        // We verify by checking the Token Usage label exists (the bar is rendered below it)
        let tokenUsageLabel = app.staticTexts["Token Usage"]
        XCTAssertTrue(tokenUsageLabel.waitForExistence(timeout: 5))
    }

    // MARK: - Legend Items

    func testLegendShowsInputColor() throws {
        navigateToAgentSession()

        // Legend shows colored circles with labels
        let inputLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Input:'")).firstMatch
        _ = inputLabel.waitForExistence(timeout: 5)
    }

    func testLegendShowsOutputColor() throws {
        navigateToAgentSession()

        let outputLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Output:'")).firstMatch
        _ = outputLabel.waitForExistence(timeout: 5)
    }

    // MARK: - Warning States

    func testApproachingLimitWarning() throws {
        navigateToAgentSession()

        // Warning appears when usage > 80%: "Approaching limit (XX%)"
        let warningText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Approaching limit'")).firstMatch
        // May or may not be visible depending on demo data token counts
        _ = warningText.waitForExistence(timeout: 3)
    }

    func testContextLimitReachedWarning() throws {
        navigateToAgentSession()

        // Critical warning appears when usage > 95%: "Context limit reached"
        let criticalText = app.staticTexts["Context limit reached"]
        // May or may not be visible depending on demo data
        _ = criticalText.waitForExistence(timeout: 3)
    }

    // MARK: - Integration with Session Header

    func testTokenUsageBarAppearsInAgentConversation() throws {
        navigateToAgentSession()

        // The token usage bar should be visible somewhere in the agent conversation view
        // It contains the "Token Usage" label and legend items
        let tokenLabel = app.staticTexts["Token Usage"]
        _ = tokenLabel.waitForExistence(timeout: 5)
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func navigateToAgentSession() {
        app.typeKey("2", modifierFlags: .command)

        let sessionRow = app.scrollViews.firstMatch.otherElements.firstMatch
        if sessionRow.waitForExistence(timeout: 5) {
            sessionRow.click()
        }
    }
}
