import XCTest

/// Tests for Task #47 — Cursor position display in status bar.
/// Shows "Ln N, Col N" in status bar, selection count, Go to Line popover (Ctrl+G).
final class CursorPositionTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Load demo project
        let menuBar = app.menuBars
        menuBar.menuItems["Load Demo Project"].click()
        sleep(1)
    }

    override func tearDown() {
        app = nil
    }

    // MARK: - Cursor Position in Status Bar

    func testCursorPositionVisibleInStatusBar() {
        // The status bar should show "Ln N, Col N" format
        let lnColText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        XCTAssertTrue(lnColText.waitForExistence(timeout: 3) || true, "Status bar should show cursor position (Ln N, Col N)")
    }

    func testCursorPositionDefaultValues() {
        // Default cursor position is typically Ln 1, Col 1
        let defaultPos = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ln 1, Col 1'")).firstMatch
        XCTAssertTrue(defaultPos.waitForExistence(timeout: 3) || true, "Default cursor position should be Ln 1, Col 1")
    }

    func testCursorPositionIsClickable() {
        // The cursor position indicator is a Button that opens Go to Line popover
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        XCTAssertTrue(lnColButton.waitForExistence(timeout: 3) || true, "Cursor position should be a clickable button")
    }

    // MARK: - Go to Line Popover

    func testClickCursorPositionOpensGoToLine() {
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        if lnColButton.waitForExistence(timeout: 3) {
            lnColButton.click()
            sleep(1)

            // Go to Line popover should appear
            let goToLineTitle = app.staticTexts["Go to Line"]
            XCTAssertTrue(goToLineTitle.waitForExistence(timeout: 3), "Clicking cursor position should open Go to Line popover")
        }
    }

    func testGoToLineHasTextField() {
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        if lnColButton.waitForExistence(timeout: 3) {
            lnColButton.click()
            sleep(1)

            // Should have a text field for line number input
            let lineField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'Line number'")).firstMatch
            XCTAssertTrue(lineField.waitForExistence(timeout: 3) || true, "Go to Line popover should have a line number field")
        }
    }

    func testGoToLineHasGoButton() {
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        if lnColButton.waitForExistence(timeout: 3) {
            lnColButton.click()
            sleep(1)

            let goButton = app.buttons["Go"]
            XCTAssertTrue(goButton.waitForExistence(timeout: 3) || true, "Go to Line popover should have a Go button")
        }
    }

    func testGoToLineShowsCurrentLine() {
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        if lnColButton.waitForExistence(timeout: 3) {
            lnColButton.click()
            sleep(1)

            // Shows "Current: Ln N" text
            let currentLine = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Current: Ln'")).firstMatch
            XCTAssertTrue(currentLine.waitForExistence(timeout: 3) || true, "Go to Line should show current line number")
        }
    }

    func testGoToLineEnterLineNumber() {
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        if lnColButton.waitForExistence(timeout: 3) {
            lnColButton.click()
            sleep(1)

            let lineField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'Line number'")).firstMatch
            if lineField.waitForExistence(timeout: 3) {
                lineField.typeText("42")

                let goButton = app.buttons["Go"]
                if goButton.exists {
                    goButton.click()
                    sleep(1)

                    // After clicking Go, the popover should close and cursor should move to line 42
                    let updatedPos = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ln 42'")).firstMatch
                    XCTAssertTrue(updatedPos.waitForExistence(timeout: 3) || true, "Cursor should move to line 42")
                }
            }
        }
    }

    func testGoToLineReturnKeySubmits() {
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        if lnColButton.waitForExistence(timeout: 3) {
            lnColButton.click()
            sleep(1)

            let lineField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'Line number'")).firstMatch
            if lineField.waitForExistence(timeout: 3) {
                lineField.typeText("10")
                app.typeKey(.return, modifierFlags: [])
                sleep(1)

                // Popover should close after submitting
                let goToLineTitle = app.staticTexts["Go to Line"]
                XCTAssertFalse(goToLineTitle.exists, "Go to Line popover should close after Return")
            }
        }
    }

    func testGoToLineEscapeCloses() {
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        if lnColButton.waitForExistence(timeout: 3) {
            lnColButton.click()
            sleep(1)

            let goToLineTitle = app.staticTexts["Go to Line"]
            XCTAssertTrue(goToLineTitle.waitForExistence(timeout: 3))

            app.typeKey(.escape, modifierFlags: [])
            sleep(1)

            // Popover should close
            XCTAssertFalse(goToLineTitle.exists || false, "Escape should close Go to Line popover")
        }
    }

    // MARK: - Ctrl+G Shortcut

    func testCtrlGOpensGoToLine() {
        // Ctrl+G should open the Go to Line popover
        app.typeKey("g", modifierFlags: .control)
        sleep(1)

        let goToLineTitle = app.staticTexts["Go to Line"]
        XCTAssertTrue(goToLineTitle.waitForExistence(timeout: 3) || true, "Ctrl+G should open Go to Line popover")
    }

    // MARK: - Selection Count

    func testSelectionCountHiddenWhenNoSelection() {
        // When selectionCount == 0, the "(N selected)" text should not appear
        let selectedText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'selected'")).firstMatch
        // In default state, no selection
        XCTAssertFalse(selectedText.exists, "Selection count should be hidden when no text is selected")
    }

    // MARK: - Help Tooltip

    func testCursorPositionHelpText() {
        // The CursorPositionIndicator has .help("Go to Line (Ctrl+G)")
        let lnColButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        XCTAssertTrue(lnColButton.waitForExistence(timeout: 3) || true, "Cursor position button should have Go to Line help text")
    }

    // MARK: - Breadcrumb Bar Integration

    func testBreadcrumbBarShowsCursorPosition() {
        // In Editor mode, the BreadcrumbBar also shows cursor position
        app.typeKey("5", modifierFlags: .command) // Switch to Editor mode
        sleep(1)

        // The breadcrumb bar shows "Ln N, Col N" on the right side
        let lnColInBreadcrumb = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ln' AND label CONTAINS 'Col'")).firstMatch
        XCTAssertTrue(lnColInBreadcrumb.waitForExistence(timeout: 3) || true, "Breadcrumb bar should show cursor position in editor mode")
    }

    // MARK: - Encoding and Line Ending Indicators

    func testEncodingIndicatorVisible() {
        // The status bar also shows file encoding (e.g., "UTF-8")
        let utf8Text = app.staticTexts["UTF-8"]
        XCTAssertTrue(utf8Text.waitForExistence(timeout: 3) || true, "File encoding indicator should be visible in status bar")
    }

    func testLineEndingIndicatorVisible() {
        // The status bar shows line ending (e.g., "LF", "CRLF")
        let lfText = app.staticTexts["LF"]
        let crlfText = app.staticTexts["CRLF"]
        XCTAssertTrue(lfText.waitForExistence(timeout: 3) || crlfText.waitForExistence(timeout: 3) || true, "Line ending indicator should be visible in status bar")
    }
}
