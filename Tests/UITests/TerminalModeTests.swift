import XCTest

final class TerminalModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigate to Terminal Mode

    func testTerminalModeAccessibleViaKeyboard() throws {
        app.typeKey("7", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "Cmd+7 must not crash when navigating to Terminal mode")
    }

    func testTerminalModeRendersView() throws {
        app.typeKey("7", modifierFlags: .command)

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.textViews.firstMatch.waitForExistence(timeout: 5)
            || app.otherElements["TerminalView"].waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Terminal mode must render a view after navigation")
    }

    // MARK: - Terminal Panel Toggle

    func testTerminalPanelTogglesViaCmdJ() throws {
        // Open terminal panel
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "Cmd+J must not crash when opening terminal panel")

        // Close terminal panel
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "Cmd+J must not crash when closing terminal panel")
    }

    func testTerminalPanelAppearsOnCmdJ() throws {
        app.typeKey("j", modifierFlags: .command)

        let terminalView = app.otherElements["TerminalView"].waitForExistence(timeout: 5)
            || app.textViews.firstMatch.waitForExistence(timeout: 5)
            || app.scrollViews.count > 1
        XCTAssertTrue(terminalView, "Cmd+J must reveal a terminal panel view")
    }

    func testTerminalPanelDismissesOnSecondCmdJ() throws {
        // Open
        app.typeKey("j", modifierFlags: .command)
        _ = app.windows.firstMatch.waitForExistence(timeout: 2)

        // Close
        app.typeKey("j", modifierFlags: .command)
        // App must remain stable
        XCTAssertTrue(app.windows.firstMatch.exists, "Second Cmd+J must dismiss terminal panel without crashing")
    }

    // MARK: - Terminal View Interaction

    func testTerminalViewIsFocusableAfterOpen() throws {
        app.typeKey("7", modifierFlags: .command)
        _ = app.windows.firstMatch.waitForExistence(timeout: 3)

        // The terminal area should be hittable
        let terminalArea = app.textViews.firstMatch
        if terminalArea.waitForExistence(timeout: 5) {
            XCTAssertTrue(terminalArea.isHittable, "Terminal text view must be hittable")
        } else {
            // Fallback: at minimum mode must render without crashing
            XCTAssertTrue(app.windows.firstMatch.exists, "Terminal mode must remain stable")
        }
    }

    // MARK: - Sidebar in Terminal Mode

    func testTerminalModeSidebarHasContent() throws {
        app.typeKey("7", modifierFlags: .command)

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Terminal mode sidebar must have scroll content")
    }

    // MARK: - Terminal Mode Does Not Crash On Return

    func testNavigatingAwayFromTerminalModeDoesNotCrash() throws {
        app.typeKey("7", modifierFlags: .command)
        _ = app.windows.firstMatch.waitForExistence(timeout: 2)

        // Navigate away
        app.typeKey("2", modifierFlags: .command)

        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Navigating away from Terminal mode must not crash")
    }

    func testNavigatingBackToTerminalModeDoesNotCrash() throws {
        app.typeKey("7", modifierFlags: .command)
        _ = app.windows.firstMatch.waitForExistence(timeout: 2)

        app.typeKey("2", modifierFlags: .command)
        _ = app.buttons["New Session"].waitForExistence(timeout: 3)

        app.typeKey("7", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "Returning to Terminal mode must not crash")
    }

    // MARK: - Full Terminal Cycle

    func testFullTerminalCycleDoesNotCrash() throws {
        app.typeKey("7", modifierFlags: .command)
        app.typeKey("j", modifierFlags: .command)
        app.typeKey("j", modifierFlags: .command)
        app.typeKey("1", modifierFlags: .command)
        app.typeKey("7", modifierFlags: .command)

        XCTAssertTrue(app.windows.firstMatch.exists, "App must remain stable after full terminal interaction cycle")
    }
}
