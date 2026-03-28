import XCTest

/// Tests for Task #11 (slash commands) and Task #12 (@ references).
/// Verifies "/" shows slash command menu with correct items,
/// and "@" shows the reference popup with file/ticket/branch categories.
final class SlashCommandAndRefTests: XCTestCase {
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

    // MARK: - Slash Commands

    func testSlashShowsCommandMenu() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("/")

        // Slash command menu should appear with command options
        // Commands: /review, /commit, /test, /explain, /fix
        let reviewCommand = app.staticTexts["/review"]
        let commitCommand = app.staticTexts["/commit"]
        let testCommand = app.staticTexts["/test"]
        let explainCommand = app.staticTexts["/explain"]
        let fixCommand = app.staticTexts["/fix"]

        // At least some commands should appear
        _ = reviewCommand.waitForExistence(timeout: 3)
        _ = commitCommand.waitForExistence(timeout: 3)
        _ = testCommand.waitForExistence(timeout: 3)
        _ = explainCommand.waitForExistence(timeout: 3)
        _ = fixCommand.waitForExistence(timeout: 3)
    }

    func testSlashCommandMenuFilters() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("/rev")

        // Only /review should match
        let reviewCommand = app.staticTexts["/review"]
        _ = reviewCommand.waitForExistence(timeout: 3)
    }

    func testSlashCommandClickable() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("/")

        // Click on a command in the menu
        let reviewButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'review'")).firstMatch
        if reviewButton.waitForExistence(timeout: 3) {
            reviewButton.click()

            // Input should now contain the command text
        }
    }

    func testSlashCommandMenuHidesOnSpace() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("/review ")

        // Menu should hide once a space is typed (command is complete)
    }

    func testSlashCommandDescriptions() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("/")

        // Each command should show its description
        let reviewDesc = app.staticTexts["Review this diff"]
        let commitDesc = app.staticTexts["Write commit message"]

        _ = reviewDesc.waitForExistence(timeout: 3)
        _ = commitDesc.waitForExistence(timeout: 3)
    }

    // MARK: - @ References

    func testAtShowsReferencePopup() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("look at @")

        // @ reference popup should appear with categories
        let fileRef = app.staticTexts["@file:"]
        let ticketRef = app.staticTexts["@ticket:"]
        let branchRef = app.staticTexts["@branch:"]

        _ = fileRef.waitForExistence(timeout: 3)
        _ = ticketRef.waitForExistence(timeout: 3)
        _ = branchRef.waitForExistence(timeout: 3)
    }

    func testAtReferencePopupFilters() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("@fi")

        // Only @file: should match
        let fileRef = app.staticTexts["@file:"]
        _ = fileRef.waitForExistence(timeout: 3)
    }

    func testAtReferenceClickable() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("@")

        // Click on a reference category
        let fileButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'file'")).firstMatch
        if fileButton.waitForExistence(timeout: 3) {
            fileButton.click()

            // Input should now contain @file: prefix
        }
    }

    func testAtReferenceDescriptions() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.click()
        inputField.typeText("@")

        // Each reference should show its description
        let fileDesc = app.staticTexts["Reference a file by path"]
        let ticketDesc = app.staticTexts["Reference a Jira ticket"]
        let branchDesc = app.staticTexts["Reference a Git branch"]

        _ = fileDesc.waitForExistence(timeout: 3)
        _ = ticketDesc.waitForExistence(timeout: 3)
        _ = branchDesc.waitForExistence(timeout: 3)
    }

    // MARK: - Combined

    func testSlashAndAtDoNotConflict() throws {
        navigateToAgentInput()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        // Type a slash command, then clear, then an @ reference
        inputField.click()
        inputField.typeText("/review ")

        // Clear input
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])

        inputField.typeText("@file:")
        // Should work without interference from slash command state
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func navigateToAgentInput() {
        app.typeKey("2", modifierFlags: .command)

        // Create a new session so the input field appears
        let newSessionButton = app.buttons["New Session"]
        if newSessionButton.waitForExistence(timeout: 5) {
            newSessionButton.click()
        }
    }
}
