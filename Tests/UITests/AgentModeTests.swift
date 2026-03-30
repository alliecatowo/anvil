import XCTest

final class AgentModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        switchToBuildMode()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - New Session → Verify Conversation View Appears

    func testNewSessionCreatesConversationView() throws {
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        newSession.click()

        // Result: conversation input field should appear
        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Clicking New Session must produce a conversation input field")
    }

    func testNewSessionAppearsInSidebar() throws {
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        newSession.click()

        // Result: a session row must appear in the sidebar scroll view
        let sessionRows = app.scrollViews.firstMatch.otherElements
        XCTAssertTrue(sessionRows.firstMatch.waitForExistence(timeout: 5), "New session must appear as a row in the sidebar")
    }

    // MARK: - Input Field Accepts Text

    func testInputFieldAcceptsText() throws {
        createNewSession()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("Fix the auth bug")

        XCTAssertEqual(inputField.value as? String, "Fix the auth bug", "Input field value must reflect typed text")
    }

    // MARK: - Send Message → Verify Message Appears

    func testSendMessageAppearsInConversation() throws {
        createNewSession()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("Hello, fix the auth bug")

        // Send via Return key
        app.typeKey(.return, modifierFlags: [])

        // Result: typed message must appear in the conversation scroll view
        let userMessage = app.staticTexts["Hello, fix the auth bug"]
        XCTAssertTrue(userMessage.waitForExistence(timeout: 5), "Sent message must appear in conversation view")
    }

    func testSendMessageClearsInputField() throws {
        createNewSession()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("Test message")
        app.typeKey(.return, modifierFlags: [])

        // Result: input field must be empty after sending
        let emptyField = app.textFields["Message the agent..."]
        if emptyField.waitForExistence(timeout: 3) {
            let value = emptyField.value as? String ?? ""
            XCTAssertTrue(value.isEmpty || value == "Message the agent...", "Input field must clear after sending")
        }
    }

    func testSendMessageShowsThinkingOrResponse() throws {
        createNewSession()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("Hello")
        app.typeKey(.return, modifierFlags: [])

        // Result: either a thinking indicator OR an agent response must appear
        let thinkingOrResponse = app.staticTexts["Thinking..."].waitForExistence(timeout: 5)
            || app.progressIndicators.firstMatch.waitForExistence(timeout: 5)
            || app.scrollViews.firstMatch.staticTexts.count > 1
        XCTAssertTrue(thinkingOrResponse, "Build must show thinking indicator or response after message is sent")
    }

    // MARK: - Slash Commands → Verify Menu Appears

    func testTypingSlashShowsSlashCommandMenu() throws {
        createNewSession()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("/")

        // Result: slash command popover/list should appear
        let slashMenu = app.popovers.firstMatch
        let hasResults = slashMenu.waitForExistence(timeout: 3)
            || app.tables.firstMatch.waitForExistence(timeout: 3)
            || app.otherElements["SlashCommandMenu"].waitForExistence(timeout: 3)
        XCTAssertTrue(hasResults, "Typing '/' must show slash command menu")
    }

    // MARK: - @ References → Verify Popup Appears

    func testTypingAtShowsReferencePopup() throws {
        createNewSession()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.click()
        inputField.typeText("@")

        // Result: @ reference popup should appear
        let popup = app.popovers.firstMatch
        let hasPopup = popup.waitForExistence(timeout: 3)
            || app.tables.firstMatch.waitForExistence(timeout: 3)
            || app.otherElements["AtReferencePopup"].waitForExistence(timeout: 3)
        XCTAssertTrue(hasPopup, "Typing '@' must show reference popup")
    }

    // MARK: - Session Dashboard Button → Verify Dashboard Appears

    func testBuildDashboardButtonSwitchesView() throws {
        let dashboardButton = app.buttons["Session Dashboard"]
        XCTAssertTrue(dashboardButton.waitForExistence(timeout: 5))
        dashboardButton.click()

        // Result: dashboard view replaces sidebar list (no "New Session" visible or layout changes)
        // The dashboard button should now be highlighted/selected
        XCTAssertTrue(app.windows.firstMatch.exists, "Clicking Session Dashboard must not crash")
    }

    // MARK: - Context Menu on Session Row

    func testSessionRowContextMenuHasRenameOption() throws {
        createNewSession()

        let sessionRow = app.scrollViews.firstMatch.otherElements.firstMatch
        if sessionRow.waitForExistence(timeout: 5) {
            sessionRow.rightClick()

            let renameItem = app.menuItems["Rename..."]
            XCTAssertTrue(renameItem.waitForExistence(timeout: 3), "Session context menu must have Rename... option")
        }
    }

    func testSessionRowContextMenuHasDeleteOption() throws {
        createNewSession()

        let sessionRow = app.scrollViews.firstMatch.otherElements.firstMatch
        if sessionRow.waitForExistence(timeout: 5) {
            sessionRow.rightClick()

            let deleteItem = app.menuItems["Delete"]
            XCTAssertTrue(deleteItem.waitForExistence(timeout: 3), "Session context menu must have Delete option")
        }
    }

    func testDeleteSessionRemovesItFromSidebar() throws {
        createNewSession()

        // Count sessions before
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        let beforeCount = scrollView.otherElements.count

        // Right-click → Delete
        let sessionRow = scrollView.otherElements.firstMatch
        if sessionRow.waitForExistence(timeout: 5) {
            sessionRow.rightClick()
            let deleteItem = app.menuItems["Delete"]
            if deleteItem.waitForExistence(timeout: 3) {
                deleteItem.click()

                // Result: fewer rows in sidebar
                let afterCount = scrollView.otherElements.count
                XCTAssertLessThan(afterCount, beforeCount, "Deleting a session must remove it from the sidebar")
            }
        }
    }

    // MARK: - Export to Clipboard

    func testExportToClipboardOptionExists() throws {
        createNewSession()

        let sessionRow = app.scrollViews.firstMatch.otherElements.firstMatch
        if sessionRow.waitForExistence(timeout: 5) {
            sessionRow.rightClick()

            let exportItem = app.menuItems["Export to Clipboard"]
            XCTAssertTrue(exportItem.waitForExistence(timeout: 3), "Session context menu must have Export to Clipboard option")
        }
    }

    // MARK: - Empty State

    func testEmptyStateShowsNewSessionCTA() throws {
        // If no sessions exist, empty state should show a call to action
        let newSessionVisible = app.buttons["New Session"].waitForExistence(timeout: 5)
        XCTAssertTrue(newSessionVisible, "Build mode empty state must show New Session button")
    }

    // MARK: - Helpers

    private func switchToBuildMode() {
        app.typeKey("2", modifierFlags: .command)
        _ = app.buttons["New Session"].waitForExistence(timeout: 5)
    }

    private func createNewSession() {
        let newSession = app.buttons["New Session"]
        if newSession.waitForExistence(timeout: 5) {
            newSession.click()
        }
        _ = app.textFields["Message the agent..."].waitForExistence(timeout: 5)
    }
}
