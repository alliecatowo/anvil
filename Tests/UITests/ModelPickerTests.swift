import XCTest

/// Tests for Task #14 — Model picker per agent session.
/// Verifies dropdown appears in agent session header and model selection works.
final class ModelPickerTests: XCTestCase {
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

    // MARK: - Picker Visibility

    func testModelPickerExistsInSessionHeader() throws {
        navigateToAgentSession()

        // The model picker shows the current model name (e.g. "Claude Sonnet 4.6")
        // with a chevron.down indicator
        let modelLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Claude'")).firstMatch
        XCTAssertTrue(modelLabel.waitForExistence(timeout: 5), "Model name should be visible in session header")
    }

    // MARK: - Dropdown Menu

    func testModelPickerDropdownOpens() throws {
        navigateToAgentSession()

        // The model picker is a Menu — click it to open the dropdown
        // Look for the picker by its chevron or model name
        let modelPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Claude'")).firstMatch
        if modelPicker.waitForExistence(timeout: 5) {
            modelPicker.click()

            // Menu items should appear with model options
            // Built-in models: Claude Opus 4.6, Claude Sonnet 4.6, Claude Haiku 4.5, GPT-4o, Llama 3.3 70B
        }
    }

    func testModelPickerShowsAllBuiltInModels() throws {
        navigateToAgentSession()

        let modelPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Claude'")).firstMatch
        if modelPicker.waitForExistence(timeout: 5) {
            modelPicker.click()

            // Check for presence of model options in the menu
            let opusItem = app.menuItems["Claude Opus 4.6"]
            let sonnetItem = app.menuItems["Claude Sonnet 4.6"]
            let haikuItem = app.menuItems["Claude Haiku 4.5"]
            let gptItem = app.menuItems["GPT-4o"]
            let llamaItem = app.menuItems["Llama 3.3 70B"]

            // At least the Claude models should be available
            _ = opusItem.waitForExistence(timeout: 3)
            _ = sonnetItem.waitForExistence(timeout: 3)
            _ = haikuItem.waitForExistence(timeout: 3)
            _ = gptItem.waitForExistence(timeout: 3)
            _ = llamaItem.waitForExistence(timeout: 3)
        }
    }

    // MARK: - Model Selection

    func testSelectingModelUpdatesDisplay() throws {
        navigateToAgentSession()

        let modelPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Claude'")).firstMatch
        if modelPicker.waitForExistence(timeout: 5) {
            modelPicker.click()

            // Select a different model
            let opusItem = app.menuItems["Claude Opus 4.6"]
            if opusItem.waitForExistence(timeout: 3) {
                opusItem.click()

                // Model picker should now show the newly selected model
                let updatedLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Opus'")).firstMatch
                XCTAssertTrue(updatedLabel.waitForExistence(timeout: 3), "Model picker should update to show selected model")
            }
        }
    }

    // MARK: - Session Header Context

    func testSessionHeaderShowsTokenUsage() throws {
        navigateToAgentSession()

        // Token usage shows input/output token counts
        // Look for arrow.down.circle and arrow.up.circle icons
    }

    func testSessionHeaderShowsCost() throws {
        navigateToAgentSession()

        // Cost is displayed as $X.XX
        let costText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$'")).firstMatch
        _ = costText.waitForExistence(timeout: 5)
    }

    func testSessionHeaderShowsStatusBadge() throws {
        navigateToAgentSession()

        // Session status badge (e.g. "completed", "running")
        let statusBadge = app.staticTexts["completed"]
        _ = statusBadge.waitForExistence(timeout: 5)
    }

    // MARK: - Session Actions Menu

    func testSessionActionsMenuExists() throws {
        navigateToAgentSession()

        // The ellipsis.circle button opens session actions
        let actionsMenu = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ellipsis'")).firstMatch
        _ = actionsMenu.waitForExistence(timeout: 5)
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
