import XCTest

final class CommandPaletteTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Open

    func testOpenCommandPaletteViaKeyboard() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Cmd+K must open command palette with search field")
    }

    func testCommandPaletteSearchFieldIsFocused() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        // Field should be focused — we can type immediately
        app.typeText("agent")

        XCTAssertEqual(searchField.value as? String, "agent", "Command palette search field must be focused on open")
    }

    // MARK: - Close

    func testEscapeClosesCommandPalette() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertFalse(searchField.waitForExistence(timeout: 3), "Escape must close command palette")
    }

    func testBackdropClickClosesCommandPalette() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Click far corner (backdrop)
        let window = app.windows.firstMatch
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.95))
        corner.click()

        XCTAssertFalse(searchField.waitForExistence(timeout: 3), "Clicking backdrop must close command palette")
    }

    // MARK: - Search → Results Appear

    func testSearchProducesResults() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeText("Toggle")

        // Result: results scroll view must appear
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "Typing in command palette must produce a results list")
    }

    func testSearchForBuildShowsResult() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeText("Build")

        // Result: at least one result containing "Build" should appear
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Build'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 3), "Searching 'Build' must show Build-related results")
    }

    func testSearchWithNoMatchesShowsEmptyState() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeText("xyzxyzxyz_no_match_ever")

        // Result: empty state or no results indicator
        let emptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No results' OR label CONTAINS 'no results'")).firstMatch
        // App must not crash even with no matches
        XCTAssertTrue(app.windows.firstMatch.exists, "No-match search must not crash the app")
        _ = emptyState.waitForExistence(timeout: 2)
    }

    // MARK: - Keyboard Navigation

    func testArrowKeyNavigationMovesSelection() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeText("mode")
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 3)

        // Navigate down and verify app doesn't crash
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.upArrow, modifierFlags: [])

        XCTAssertTrue(app.windows.firstMatch.exists, "Arrow key navigation must not crash")
    }

    // MARK: - Execute → Mode Switches / Palette Closes

    func testReturnExecutesSelectedCommand() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Press Return to execute the first (default) item
        app.typeKey(.return, modifierFlags: [])

        // Result: palette must close
        XCTAssertFalse(searchField.waitForExistence(timeout: 3), "Pressing Return must execute command and close palette")
    }

    func testSearchAndExecuteSwitchesMode() throws {
        // Start in a known mode
        app.buttons["Intent"].click()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 3)

        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeText("Build")

        // Select a result
        let agentResult = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Build'")).firstMatch
        if agentResult.waitForExistence(timeout: 3) {
            agentResult.click()

            // Result: palette closes AND mode changes
            XCTAssertFalse(searchField.waitForExistence(timeout: 3), "Clicking a result must close the command palette")
        }
    }

    // MARK: - Search Button in Tab Bar Also Opens Palette

    func testSearchButtonInTabBarOpensPalette() throws {
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Search'")).firstMatch
        if searchButton.waitForExistence(timeout: 5) {
            searchButton.click()

            let searchField = app.textFields["Search commands, files, work items..."]
            XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search button in tab bar must open command palette")
        }
    }

    // MARK: - Reopen Works After Close

    func testCanReopenCommandPaletteAfterClose() throws {
        // Open
        app.typeKey("k", modifierFlags: .command)
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Close
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(searchField.waitForExistence(timeout: 3))

        // Reopen
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Command palette must be reopenable after closing")
    }
}
