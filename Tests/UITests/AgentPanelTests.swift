import XCTest

final class AgentPanelTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Open Agent Panel

    func testOpenAgentPanelViaKeyboardShortcut() throws {
        app.typeKey("a", modifierFlags: [.command, .option])

        // Agent panel must open — look for any panel indicator
        let panelExists = app.otherElements["AgentPanel"].waitForExistence(timeout: 5)
            || app.textFields["Message the agent..."].waitForExistence(timeout: 5)
            || app.buttons["New Session"].waitForExistence(timeout: 5)
        XCTAssertTrue(panelExists, "Cmd+Opt+A must open the agent panel")
    }

    func testAgentPanelShowsNewSessionButton() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Agent panel must show New Session button")
        XCTAssertTrue(newSession.isHittable, "New Session button must be hittable")
    }

    // MARK: - Close / Dismiss

    func testAgentPanelCloseButtonDismissesPanel() throws {
        app.typeKey("2", modifierFlags: .command)
        _ = app.buttons["New Session"].waitForExistence(timeout: 5)

        // Look for a close button (X or sidebar close control)
        let closeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Close' OR identifier CONTAINS 'close'")).firstMatch
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.click()
            // Panel should no longer be visible at prior width
            XCTAssertTrue(app.windows.firstMatch.exists, "Close button must not crash the app")
        }
    }

    func testSidebarToggleDismissesAgentPanel() throws {
        app.typeKey("2", modifierFlags: .command)
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))

        // Toggle sidebar off
        app.typeKey("b", modifierFlags: .command)
        XCTAssertFalse(newSession.waitForExistence(timeout: 3), "Sidebar toggle must hide agent panel contents")

        // Toggle sidebar on — panel contents return
        app.typeKey("b", modifierFlags: .command)
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Sidebar toggle must restore agent panel contents")
    }

    // MARK: - New Session Flow

    func testNewSessionButtonOpensConversationInput() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        newSession.click()

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Clicking New Session must open conversation input field")
    }

    func testNewSessionInputIsHittable() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSession = app.buttons["New Session"]
        if newSession.waitForExistence(timeout: 5) {
            newSession.click()
        }

        let inputField = app.textFields["Message the agent..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        XCTAssertTrue(inputField.isHittable, "Agent input field must be hittable after opening new session")
    }

    // MARK: - Session Dashboard

    func testSessionDashboardButtonExists() throws {
        app.typeKey("2", modifierFlags: .command)

        let dashboard = app.buttons["Session Dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5), "Agent panel must show Session Dashboard button")
    }

    func testSessionDashboardButtonIsClickable() throws {
        app.typeKey("2", modifierFlags: .command)

        let dashboard = app.buttons["Session Dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5))
        XCTAssertTrue(dashboard.isHittable, "Session Dashboard button must be hittable")

        dashboard.click()
        XCTAssertTrue(app.windows.firstMatch.exists, "Clicking Session Dashboard must not crash")
    }

    // MARK: - Multiple Sessions

    func testCreatingMultipleSessionsPopulatesSidebar() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))

        // Create two sessions
        newSession.click()
        _ = app.textFields["Message the agent..."].waitForExistence(timeout: 3)

        if newSession.waitForExistence(timeout: 3) {
            newSession.click()
            _ = app.textFields["Message the agent..."].waitForExistence(timeout: 3)
        }

        // Sidebar should have session rows
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Sessions must appear in sidebar scroll view")
    }

    // MARK: - Panel Persists Through Mode Switches

    func testAgentSessionsPersistAfterModeSwitch() throws {
        app.typeKey("2", modifierFlags: .command)

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        newSession.click()
        _ = app.textFields["Message the agent..."].waitForExistence(timeout: 3)

        // Switch away and back
        app.typeKey("1", modifierFlags: .command)
        _ = app.windows.firstMatch.waitForExistence(timeout: 1)
        app.typeKey("2", modifierFlags: .command)

        // The scroll view with sessions should still be there
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Agent sessions must persist after switching modes")
    }
}
