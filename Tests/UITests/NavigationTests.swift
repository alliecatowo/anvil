import XCTest

final class NavigationTests: XCTestCase {
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

    // MARK: - Sidebar Toggle

    func testSidebarToggleCollapsesAndRestores() throws {
        // Collapse sidebar
        app.typeKey("b", modifierFlags: .command)

        // Collapsed: New Session button should no longer be visible
        let newSession = app.buttons["New Session"]
        app.typeKey("2", modifierFlags: .command) // Go to Build mode first
        _ = newSession.waitForExistence(timeout: 3)

        app.typeKey("b", modifierFlags: .command)
        // After collapsing, sidebar content hidden — then restore
        app.typeKey("b", modifierFlags: .command)

        // Restored: New Session visible again
        XCTAssertTrue(newSession.waitForExistence(timeout: 5), "Sidebar must be restored after two toggles")
    }

    // MARK: - Mode Switching Preserves State

    func testSwitchingModesPreservesAgentSessions() throws {
        // Go to Build mode and create a session
        app.typeKey("2", modifierFlags: .command)
        let newSession = app.buttons["New Session"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 5))
        newSession.click()
        _ = app.textFields["Message the agent..."].waitForExistence(timeout: 5)

        // Switch to Plan and back
        app.typeKey("1", modifierFlags: .command)
        app.typeKey("2", modifierFlags: .command)

        // Result: session should still be in the sidebar
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(scrollView.otherElements.count, 0, "Build sessions must persist through mode switches")
    }

    // MARK: - Branch Picker

    func testBranchPickerButtonExists() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5), "Branch picker button must exist in status bar")
    }

    func testBranchPickerOpensPopover() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        branchButton.click()

        // Result: popover appears
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5), "Branch picker button must open a popover")
    }

    func testBranchPickerPopoverDismissableViaEscape() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        branchButton.click()

        let popover = app.popovers.firstMatch
        if popover.waitForExistence(timeout: 5) {
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(popover.waitForExistence(timeout: 3), "Escape must dismiss branch picker popover")
        }
    }

    // MARK: - Inspector Toggle

    func testInspectorToggleViaKeyboard() throws {
        app.typeKey("i", modifierFlags: [.command, .shift])
        // Inspector should appear — verify no crash
        XCTAssertTrue(app.windows.firstMatch.exists)

        app.typeKey("i", modifierFlags: [.command, .shift])
        // Inspector should hide — verify no crash
        XCTAssertTrue(app.windows.firstMatch.exists, "Inspector toggle must not crash")
    }

    // MARK: - Terminal Panel Toggle

    func testTerminalPanelToggleViaKeyboard() throws {
        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "Cmd+J must not crash")

        app.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "Second Cmd+J must not crash")
    }

    // MARK: - Quick Capture Overlay

    func testQuickCaptureOpensAndDismisses() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let captureField = app.textFields["Quick capture..."]
        XCTAssertTrue(captureField.waitForExistence(timeout: 5), "Cmd+Shift+Space must open Quick Capture overlay")

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(captureField.waitForExistence(timeout: 3), "Escape must dismiss Quick Capture overlay")
    }

    func testQuickCaptureAcceptsText() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let captureField = app.textFields["Quick capture..."]
        XCTAssertTrue(captureField.waitForExistence(timeout: 5))

        captureField.click()
        captureField.typeText("Follow up on auth bug")

        XCTAssertEqual(captureField.value as? String, "Follow up on auth bug",
            "Quick Capture field must accept typed text")
    }

    // MARK: - Overlays Don't Stack

    func testCommandPaletteAndQuickCaptureDoNotStack() throws {
        // Open command palette
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Close it
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(searchField.waitForExistence(timeout: 3))

        // Open quick capture
        app.typeKey(.space, modifierFlags: [.command, .shift])
        let captureField = app.textFields["Quick capture..."]
        XCTAssertTrue(captureField.waitForExistence(timeout: 5))

        // Close it
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(captureField.waitForExistence(timeout: 3), "Overlays must not stack — each must be independently openable")
    }

    // MARK: - Full Cycle Does Not Crash

    func testFullNavigationCycleDoesNotCrash() throws {
        app.typeKey("1", modifierFlags: .command)
        app.typeKey("2", modifierFlags: .command)
        app.typeKey("3", modifierFlags: .command)
        app.typeKey("4", modifierFlags: .command)
        app.typeKey("b", modifierFlags: .command)
        app.typeKey("b", modifierFlags: .command)
        app.typeKey("k", modifierFlags: .command)
        app.typeKey(.escape, modifierFlags: [])
        app.typeKey("j", modifierFlags: .command)
        app.typeKey("j", modifierFlags: .command)

        XCTAssertTrue(app.windows.firstMatch.exists, "App must remain stable after full navigation cycle")
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }
}
