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

    // MARK: - Open / Close

    func testOpenCommandPaletteViaKeyboard() throws {
        app.typeKey("k", modifierFlags: .command)

        // The palette search field should appear
        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Command palette search field should appear")
    }

    func testCloseCommandPaletteViaEscape() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Press Escape to close
        app.typeKey(.escape, modifierFlags: [])

        // Search field should disappear
        XCTAssertFalse(searchField.waitForExistence(timeout: 2), "Command palette should close on Escape")
    }

    func testOpenCommandPaletteViaSearchButton() throws {
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Search'")).firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        searchButton.click()

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Command palette should open when clicking search button")
    }

    // MARK: - Search

    func testCommandPaletteAcceptsText() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeText("agent")
        XCTAssertEqual(searchField.value as? String, "agent")
    }

    func testCommandPaletteShowsResults() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Type something that should match command items
        searchField.typeText("Toggle")

        // Results should appear in the scroll view
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "Results scroll view should appear")
    }

    // MARK: - Navigation

    func testCommandPaletteArrowKeyNavigation() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Navigate down then up
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.upArrow, modifierFlags: [])
    }

    func testCommandPaletteReturnExecutes() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Press Return to execute selected item
        app.typeKey(.return, modifierFlags: [])

        // Palette should close after execution
        XCTAssertFalse(searchField.waitForExistence(timeout: 2))
    }

    // MARK: - Backdrop Dismiss

    func testCommandPaletteDismissOnBackdropClick() throws {
        app.typeKey("k", modifierFlags: .command)

        let searchField = app.textFields["Search commands, files, work items..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Click outside the palette (on the backdrop)
        let window = app.windows.firstMatch
        let topLeft = window.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.95))
        topLeft.click()

        // Palette should close
        XCTAssertFalse(searchField.waitForExistence(timeout: 2))
    }
}
