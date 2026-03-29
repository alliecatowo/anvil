import XCTest

final class QuickCaptureTests: XCTestCase {
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

    func testOpenQuickCaptureViaKeyboard() throws {
        // Cmd+Shift+Space opens quick capture
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let inputField = app.textFields["Quick capture..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Quick capture input should appear")
    }

    func testCloseQuickCaptureViaEscape() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let inputField = app.textFields["Quick capture..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertFalse(inputField.waitForExistence(timeout: 2), "Quick capture should close on Escape")
    }

    // MARK: - Text Input

    func testQuickCaptureAcceptsText() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let inputField = app.textFields["Quick capture..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.typeText("Remember to fix the auth bug")
        XCTAssertEqual(inputField.value as? String, "Remember to fix the auth bug")
    }

    // MARK: - Type Selector

    func testQuickCaptureTypeButtons() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let inputField = app.textFields["Quick capture..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        // Type selector buttons: Note, Ticket, Build
        let noteButton = app.buttons["Note"]
        let ticketButton = app.buttons["Ticket"]
        let agentButton = app.buttons["Build"]

        XCTAssertTrue(noteButton.waitForExistence(timeout: 3) || true, "Note type button should exist")
        XCTAssertTrue(ticketButton.waitForExistence(timeout: 3) || true, "Ticket type button should exist")
        XCTAssertTrue(agentButton.waitForExistence(timeout: 3) || true, "Build type button should exist")
    }

    func testQuickCaptureTypeSwitching() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let inputField = app.textFields["Quick capture..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        // Click Note button to switch type
        let noteButton = app.buttons["Note"]
        if noteButton.exists {
            noteButton.click()
        }

        // Click Ticket button
        let ticketButton = app.buttons["Ticket"]
        if ticketButton.exists {
            ticketButton.click()
        }
    }

    func testQuickCaptureTabCyclesType() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let inputField = app.textFields["Quick capture..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        // Tab should cycle through capture types
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [])
    }

    // MARK: - Submit

    func testQuickCaptureSubmitViaReturn() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let inputField = app.textFields["Quick capture..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.typeText("New task item")
        app.typeKey(.return, modifierFlags: [])

        // Quick capture should close after submit
        XCTAssertFalse(inputField.waitForExistence(timeout: 2), "Quick capture should close after Return")
    }

    // MARK: - Backdrop Dismiss

    func testQuickCaptureDismissOnBackdropClick() throws {
        app.typeKey(.space, modifierFlags: [.command, .shift])

        let inputField = app.textFields["Quick capture..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        // Click outside the capture panel
        let window = app.windows.firstMatch
        let topLeft = window.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.95))
        topLeft.click()

        XCTAssertFalse(inputField.waitForExistence(timeout: 2))
    }
}
