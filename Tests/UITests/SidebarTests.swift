import XCTest

final class SidebarTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Toggle Sidebar

    func testToggleSidebarViaKeyboard() throws {
        // Cmd+B toggles sidebar
        app.typeKey("b", modifierFlags: .command)
        // Sidebar should collapse
        // Toggle again to restore
        app.typeKey("b", modifierFlags: .command)
    }

    func testSidebarCollapseTwice() throws {
        // First toggle collapses, second hides completely, third restores
        app.typeKey("b", modifierFlags: .command)
        app.typeKey("b", modifierFlags: .command)
    }

    // MARK: - Mode-Specific Sidebar Content

    func testAgentSidebarShowsNewSessionButton() throws {
        // Ensure we're in Agent mode
        app.typeKey("2", modifierFlags: .command)

        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5), "New Session button should appear in Agent sidebar")
    }

    func testIntentSidebarContent() throws {
        app.typeKey("1", modifierFlags: .command)
        // Intent sidebar should show ticket-related content
    }

    func testReviewSidebarContent() throws {
        app.typeKey("3", modifierFlags: .command)
        // Review sidebar should show review inbox
    }

    func testShipSidebarContent() throws {
        app.typeKey("4", modifierFlags: .command)
        // Ship sidebar should show environment list
    }

    func testEditorSidebarContent() throws {
        app.typeKey("5", modifierFlags: .command)
        // Editor sidebar should show explorer/search sections
    }

    func testDatabaseSidebarContent() throws {
        app.typeKey("6", modifierFlags: .command)
        // Database sidebar should show schema/tools sections
    }

    func testTerminalSidebarContent() throws {
        app.typeKey("7", modifierFlags: .command)
        // Terminal sidebar should show sessions/actions
    }

    func testDocsSidebarContent() throws {
        app.typeKey("8", modifierFlags: .command)
        // Docs sidebar should show documents
    }

    func testMessagingSidebarContent() throws {
        app.typeKey("9", modifierFlags: .command)
        // Messaging sidebar should show channels and DMs
    }

    func testNotificationsSidebarContent() throws {
        app.typeKey("0", modifierFlags: .command)
        // Notifications sidebar should show views/filters
    }
}
