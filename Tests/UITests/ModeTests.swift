import XCTest

final class ModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Core Modes via Click

    func testSwitchToIntentMode() throws {
        let intentTab = app.buttons["Intent"]
        XCTAssertTrue(intentTab.waitForExistence(timeout: 5))
        intentTab.click()

        // Verify mode switched — Intent sidebar or content should appear
        // The sidebar header should reflect the mode
    }

    func testSwitchToAgentMode() throws {
        // First switch away, then back
        let intentTab = app.buttons["Intent"]
        XCTAssertTrue(intentTab.waitForExistence(timeout: 5))
        intentTab.click()

        let agentTab = app.buttons["Agent"]
        XCTAssertTrue(agentTab.exists)
        agentTab.click()
    }

    func testSwitchToReviewMode() throws {
        let reviewTab = app.buttons["Review"]
        XCTAssertTrue(reviewTab.waitForExistence(timeout: 5))
        reviewTab.click()
    }

    func testSwitchToShipMode() throws {
        let shipTab = app.buttons["Ship"]
        XCTAssertTrue(shipTab.waitForExistence(timeout: 5))
        shipTab.click()
    }

    // MARK: - Keyboard Shortcuts (Cmd+1 through Cmd+0)

    func testSwitchToIntentModeViaKeyboard() throws {
        app.typeKey("1", modifierFlags: .command)
        // Intent mode should now be active
    }

    func testSwitchToAgentModeViaKeyboard() throws {
        app.typeKey("2", modifierFlags: .command)
    }

    func testSwitchToReviewModeViaKeyboard() throws {
        app.typeKey("3", modifierFlags: .command)
    }

    func testSwitchToShipModeViaKeyboard() throws {
        app.typeKey("4", modifierFlags: .command)
    }

    func testSwitchToEditorModeViaKeyboard() throws {
        app.typeKey("5", modifierFlags: .command)
    }

    func testSwitchToDatabaseModeViaKeyboard() throws {
        app.typeKey("6", modifierFlags: .command)
    }

    func testSwitchToTerminalModeViaKeyboard() throws {
        app.typeKey("7", modifierFlags: .command)
    }

    func testSwitchToDocsModeViaKeyboard() throws {
        app.typeKey("8", modifierFlags: .command)
    }

    func testSwitchToMessagingModeViaKeyboard() throws {
        app.typeKey("9", modifierFlags: .command)
    }

    func testSwitchToNotificationsModeViaKeyboard() throws {
        app.typeKey("0", modifierFlags: .command)
    }

    // MARK: - Rapid Mode Switching

    func testRapidModeSwitching() throws {
        let modes = ["Intent", "Agent", "Review", "Ship"]
        for mode in modes {
            let tab = app.buttons[mode]
            XCTAssertTrue(tab.waitForExistence(timeout: 3), "\(mode) tab should exist")
            tab.click()
        }
    }

    func testCycleAllModesViaKeyboard() throws {
        for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] {
            app.typeKey(key, modifierFlags: .command)
        }
    }
}
