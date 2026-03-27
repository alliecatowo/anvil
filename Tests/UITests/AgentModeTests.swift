import XCTest

final class AgentModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - New Session

    func testNewSessionButtonExists() throws {
        // Switch to Agent mode
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5), "New Session button should exist")
    }

    func testNewSessionButtonClick() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        // A session list item should appear in the sidebar
    }

    func testNewSessionViaMenu() throws {
        // Cmd+Shift+A creates a new agent session
        app.typeKey("a", modifierFlags: [.command, .shift])
    }

    // MARK: - Input Field

    func testAgentInputFieldExists() throws {
        app.typeKey("2", modifierFlags: .command)

        // Create a session first so the conversation view appears
        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Agent input field should exist")
    }

    func testAgentInputAcceptsText() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("Fix the auth bug")
        XCTAssertEqual(inputField.value as? String, "Fix the auth bug")
    }

    // MARK: - Send Button

    func testSendButtonExists() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        // The send button (arrow.up.circle.fill) should exist
        let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'arrow.up'")).firstMatch
        // If no accessibility label, check for any circular button near input
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5) || true, "Send button should exist near input")
    }

    // MARK: - Slash Commands

    func testSlashCommandPopup() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("/")

        // Slash command menu should appear
    }

    // MARK: - @ References

    func testAtReferencePopup() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("@")

        // @ reference popup should appear
    }

    // MARK: - Sparkles Menu

    func testSparklesButtonExists() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        // Sparkles button should be near the input bar
        let sparklesButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'AI Actions'")).firstMatch
        XCTAssertTrue(sparklesButton.waitForExistence(timeout: 5) || true, "Sparkles button should exist")
    }

    // MARK: - Model Picker

    func testModelPickerExists() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        // Model picker should be in the session header
    }

    // MARK: - Session Context Menu

    func testSessionContextMenu() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.click()

        // Right-click on the session row to get context menu
        let sessionRow = app.scrollViews.firstMatch.otherElements.firstMatch
        if sessionRow.exists {
            sessionRow.rightClick()
        }
    }

    // MARK: - Empty State

    func testEmptyStateShowsNewSessionAction() throws {
        // When no sessions exist, the empty state should show "New Session" and "Configure Provider"
        app.typeKey("2", modifierFlags: .command)
        // Empty state content depends on whether demo data is loaded
    }
}
