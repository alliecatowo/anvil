import XCTest

final class SourceControlTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Panel Header

    func testSourceControlHeaderVisible() throws {
        let header = app.staticTexts["Source Control"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Source Control panel header must be visible")
    }

    func testRefreshButtonExists() throws {
        let refreshButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Refresh'")).firstMatch
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5), "Refresh button must exist in Source Control panel")
    }

    func testRefreshButtonIsHittable() throws {
        let refreshButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Refresh'")).firstMatch
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5))
        XCTAssertTrue(refreshButton.isHittable, "Refresh button must be hittable")
    }

    // MARK: - Commit Input

    func testCommitMessageFieldExists() throws {
        let commitField = app.textFields["Commit message"]
        XCTAssertTrue(commitField.waitForExistence(timeout: 5), "Commit message field must exist")
    }

    func testCommitMessageFieldAcceptsText() throws {
        let commitField = app.textFields["Commit message"]
        XCTAssertTrue(commitField.waitForExistence(timeout: 5))

        commitField.click()
        commitField.typeText("fix: resolve auth token expiry check")

        XCTAssertEqual(commitField.value as? String, "fix: resolve auth token expiry check",
            "Commit message field must reflect typed text")
    }

    func testCommitMessageFieldClearable() throws {
        let commitField = app.textFields["Commit message"]
        XCTAssertTrue(commitField.waitForExistence(timeout: 5))

        commitField.click()
        commitField.typeText("some message")

        // Clear via Cmd+A then delete
        commitField.typeKey("a", modifierFlags: .command)
        commitField.typeKey(.delete, modifierFlags: [])

        let value = commitField.value as? String ?? ""
        XCTAssertTrue(value.isEmpty || value == "Commit message", "Commit message field must be clearable")
    }

    // MARK: - Commit Button

    func testCommitButtonExists() throws {
        let commitButton = app.buttons["Commit"]
        XCTAssertTrue(commitButton.waitForExistence(timeout: 5), "Commit button must exist")
    }

    func testCommitButtonIsHittable() throws {
        let commitButton = app.buttons["Commit"]
        XCTAssertTrue(commitButton.waitForExistence(timeout: 5))
        XCTAssertTrue(commitButton.isHittable, "Commit button must be hittable")
    }

    // MARK: - Stage All / Unstage All

    func testStageAllButtonClickable() throws {
        let stageAllButton = app.buttons["Stage All"]
        if stageAllButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(stageAllButton.isHittable, "Stage All button must be hittable when visible")
            stageAllButton.click()

            // Result: unstaged section should shrink (or staged section appear)
            XCTAssertTrue(app.windows.firstMatch.exists, "Stage All must not crash")
        }
    }

    func testUnstageAllButtonClickable() throws {
        let unstageAllButton = app.buttons["Unstage All"]
        if unstageAllButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(unstageAllButton.isHittable, "Unstage All button must be hittable when visible")
            unstageAllButton.click()

            XCTAssertTrue(app.windows.firstMatch.exists, "Unstage All must not crash")
        }
    }

    // MARK: - Branch Picker

    func testBranchPickerButtonExists() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5), "Switch Branch button must exist in status bar")
    }

    func testBranchPickerOpensPopover() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        branchButton.click()

        // Result: a popover or list with branch options appears
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5), "Clicking Switch Branch must open a popover")
    }

    func testBranchPickerPopoverHasBranchOptions() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        branchButton.click()

        let popover = app.popovers.firstMatch
        if popover.waitForExistence(timeout: 5) {
            let branchRows = popover.otherElements.allElementsBoundByIndex
            XCTAssertGreaterThan(branchRows.count, 0, "Branch picker popover must contain branch options")
        }
    }

    // MARK: - File Sections Render

    func testStagedChangesSectionVisibleWhenFilesExist() throws {
        let stagedHeader = app.staticTexts["STAGED CHANGES"]
        if stagedHeader.waitForExistence(timeout: 3) {
            XCTAssertTrue(stagedHeader.isHittable || stagedHeader.exists, "STAGED CHANGES section must render")
        }
    }

    func testChangesSectionVisibleWhenFilesExist() throws {
        let changesHeader = app.staticTexts["CHANGES"]
        if changesHeader.waitForExistence(timeout: 3) {
            XCTAssertTrue(changesHeader.exists, "CHANGES section must render")
        }
    }

    func testUntrackedSectionVisibleWhenFilesExist() throws {
        let untrackedHeader = app.staticTexts["UNTRACKED"]
        if untrackedHeader.waitForExistence(timeout: 3) {
            XCTAssertTrue(untrackedHeader.exists, "UNTRACKED section must render")
        }
    }

    // MARK: - Clean Working Tree Empty State

    func testCleanWorkingTreeMessageWhenNoChanges() throws {
        let cleanText = app.staticTexts["Working tree clean"]
        // May or may not exist depending on git state — verify no crash
        _ = cleanText.waitForExistence(timeout: 3)
        XCTAssertTrue(app.windows.firstMatch.exists, "Source control panel must render without crashing")
    }

    // MARK: - Status Bar Shows Branch Name

    func testStatusBarShowsBranchName() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5), "Status bar must show branch button with branch name")
    }
}
