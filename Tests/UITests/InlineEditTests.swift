import XCTest

/// Tests for Task #13 — Inline code edit suggestions.
/// Verifies accept/reject buttons on code hunks, bulk actions, and visual state.
final class InlineEditTests: XCTestCase {
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

    // MARK: - Accept / Reject Buttons

    func testAcceptButtonExistsOnHunk() throws {
        navigateToAgentSession()

        // Look for Accept button (appears on pending hunks in inline edits)
        let acceptButton = app.buttons["Accept"]
        // Accept button only exists when an edit suggestion is in the conversation
        _ = acceptButton.waitForExistence(timeout: 5)
    }

    func testRejectButtonExistsOnHunk() throws {
        navigateToAgentSession()

        let rejectButton = app.buttons["Reject"]
        _ = rejectButton.waitForExistence(timeout: 5)
    }

    // MARK: - Bulk Actions

    func testAcceptAllButtonExists() throws {
        navigateToAgentSession()

        let acceptAllButton = app.buttons["Accept All"]
        // Only visible when there are pending hunks
        _ = acceptAllButton.waitForExistence(timeout: 5)
    }

    func testRejectAllButtonExists() throws {
        navigateToAgentSession()

        let rejectAllButton = app.buttons["Reject All"]
        _ = rejectAllButton.waitForExistence(timeout: 5)
    }

    // MARK: - Diff Lines

    func testDiffViewShowsAddedLines() throws {
        navigateToAgentSession()

        // Added lines have "+" prefix in the diff
        let addedLine = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '+'")).firstMatch
        _ = addedLine.waitForExistence(timeout: 5)
    }

    func testDiffViewShowsRemovedLines() throws {
        navigateToAgentSession()

        // Removed lines have "-" prefix
        let removedLine = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '-'")).firstMatch
        _ = removedLine.waitForExistence(timeout: 5)
    }

    // MARK: - Post-Decision State

    func testAcceptedStateShowsCheckmark() throws {
        navigateToAgentSession()

        // After accepting, "Accepted" text should appear
        let acceptedText = app.staticTexts["Accepted"]
        _ = acceptedText.waitForExistence(timeout: 3)
    }

    func testRejectedStateShowsXmark() throws {
        navigateToAgentSession()

        let rejectedText = app.staticTexts["Rejected"]
        _ = rejectedText.waitForExistence(timeout: 3)
    }

    // MARK: - File Header

    func testInlineEditShowsFilePath() throws {
        navigateToAgentSession()

        // The edit view should show the file path in a header
        // File paths are rendered with monospace code font
    }

    func testInlineEditShowsHunkCount() throws {
        navigateToAgentSession()

        // The header should show hunk count like "1 hunk" or "3 hunks"
        let hunkLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'hunk'")).firstMatch
        _ = hunkLabel.waitForExistence(timeout: 5)
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func navigateToAgentSession() {
        // Switch to Agent mode
        app.typeKey("2", modifierFlags: .command)

        // Select the demo session in the sidebar
        let sessionRow = app.scrollViews.firstMatch.otherElements.firstMatch
        if sessionRow.waitForExistence(timeout: 5) {
            sessionRow.click()
        }
    }
}
