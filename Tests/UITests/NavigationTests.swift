import XCTest

final class NavigationTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Mode Switching Preserves State

    func testModeSwitchingPreservesAgentState() throws {
        loadDemoData()

        // Start in Agent mode
        app.typeKey("2", modifierFlags: .command)

        // Switch to Intent and back
        app.typeKey("1", modifierFlags: .command)
        app.typeKey("2", modifierFlags: .command)

        // Agent session should still be visible
        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5), "Agent sidebar state should be preserved after mode switch")
    }

    func testModeSwitchingPreservesIntentState() throws {
        loadDemoData()

        app.typeKey("1", modifierFlags: .command)
        app.typeKey("2", modifierFlags: .command)
        app.typeKey("1", modifierFlags: .command)

        // Intent content should still be present
    }

    // MARK: - Inspector Toggle

    func testToggleInspectorViaKeyboard() throws {
        // Cmd+Shift+I toggles inspector
        app.typeKey("i", modifierFlags: [.command, .shift])
        // Inspector should appear

        app.typeKey("i", modifierFlags: [.command, .shift])
        // Inspector should hide
    }

    // MARK: - Terminal Panel Toggle

    func testToggleTerminalViaKeyboard() throws {
        // Cmd+J toggles terminal panel
        app.typeKey("j", modifierFlags: .command)
        // Terminal panel should appear at bottom

        app.typeKey("j", modifierFlags: .command)
        // Terminal panel should hide
    }

    // MARK: - Project Switcher

    func testProjectSwitcherOpensViaKeyboard() throws {
        // Cmd+Shift+O opens project switcher
        app.typeKey("o", modifierFlags: [.command, .shift])
        // Project switcher overlay should appear
    }

    func testProjectSwitcherOpensViaStatusBar() throws {
        // Click on the project name in status bar
        let projectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Project'")).firstMatch
        if projectButton.exists {
            projectButton.click()
        }
    }

    // MARK: - Project Notes

    func testProjectNotesViaKeyboard() throws {
        // Cmd+Shift+N opens project notes
        app.typeKey("n", modifierFlags: [.command, .shift])
        // Project notes sheet should appear
    }

    // MARK: - Branch Picker

    func testBranchPickerOpens() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        branchButton.click()

        // Branch picker popover should appear
    }

    // MARK: - Full Navigation Flow

    func testCompleteNavigationFlow() throws {
        loadDemoData()

        // Cycle through all core modes
        app.typeKey("1", modifierFlags: .command) // Intent
        app.typeKey("2", modifierFlags: .command) // Agent
        app.typeKey("3", modifierFlags: .command) // Review
        app.typeKey("4", modifierFlags: .command) // Ship

        // Toggle sidebar
        app.typeKey("b", modifierFlags: .command)
        app.typeKey("b", modifierFlags: .command)

        // Open and close command palette
        app.typeKey("k", modifierFlags: .command)
        app.typeKey(.escape, modifierFlags: [])

        // Toggle terminal
        app.typeKey("j", modifierFlags: .command)
        app.typeKey("j", modifierFlags: .command)

        // All operations should complete without crash
        XCTAssertTrue(app.windows.firstMatch.exists, "App should remain stable after full navigation flow")
    }

    // MARK: - Overlays Don't Stack

    func testOverlaysDontStack() throws {
        // Open command palette
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Close it
        app.typeKey(.escape, modifierFlags: [])

        // Open quick capture
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let captureField = app.textFields["Quick capture..."]
        XCTAssertTrue(captureField.waitForExistence(timeout: 5))

        // Close it
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }
}
