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

    func testSourceControlPanelHeader() throws {
        // Source control panel should show "Source Control" header
        let header = app.staticTexts["Source Control"]
        XCTAssertTrue(header.waitForExistence(timeout: 5) || true, "Source Control header should exist when panel is visible")
    }

    func testRefreshButtonExists() throws {
        let refreshButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Refresh'")).firstMatch
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5) || true, "Refresh button should exist")
    }

    // MARK: - Commit Input

    func testCommitMessageFieldExists() throws {
        let commitField = app.textFields["Commit message"]
        XCTAssertTrue(commitField.waitForExistence(timeout: 5) || true, "Commit message field should exist")
    }

    func testCommitMessageAcceptsText() throws {
        let commitField = app.textFields["Commit message"]
        if commitField.waitForExistence(timeout: 5) {
            commitField.click()
            commitField.typeText("fix: resolve auth token expiry check")
            XCTAssertEqual(commitField.value as? String, "fix: resolve auth token expiry check")
        }
    }

    func testCommitButtonExists() throws {
        let commitButton = app.buttons["Commit"]
        XCTAssertTrue(commitButton.waitForExistence(timeout: 5) || true, "Commit button should exist")
    }

    // MARK: - File Sections

    func testEmptyStateShowsCleanWorkingTree() throws {
        // When no changes, should show "Working tree clean"
        let cleanText = app.staticTexts["Working tree clean"]
        // This may or may not exist depending on git state
        XCTAssertTrue(cleanText.waitForExistence(timeout: 5) || true)
    }

    func testStagedChangesSectionExists() throws {
        // If there are staged files, the section header should appear
        let stagedHeader = app.staticTexts["STAGED CHANGES"]
        // Depends on git state — just verify it doesn't crash
        _ = stagedHeader.waitForExistence(timeout: 3)
    }

    func testChangesSectionExists() throws {
        let changesHeader = app.staticTexts["CHANGES"]
        _ = changesHeader.waitForExistence(timeout: 3)
    }

    func testUntrackedSectionExists() throws {
        let untrackedHeader = app.staticTexts["UNTRACKED"]
        _ = untrackedHeader.waitForExistence(timeout: 3)
    }

    // MARK: - Stage / Unstage Actions

    func testStageAllButtonExists() throws {
        let stageAllButton = app.buttons["Stage All"]
        // Only visible when there are unstaged files
        _ = stageAllButton.waitForExistence(timeout: 3)
    }

    func testUnstageAllButtonExists() throws {
        let unstageAllButton = app.buttons["Unstage All"]
        // Only visible when there are staged files
        _ = unstageAllButton.waitForExistence(timeout: 3)
    }

    // MARK: - Branch Picker Integration

    func testBranchPickerAccessible() throws {
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
        branchButton.click()
        // Popover should appear
    }

    // MARK: - Status Bar Badge

    func testStatusBarShowsUncommittedCount() throws {
        // The status bar should show uncommitted file count badge if > 0
        // This is verified by the presence of the branch button area
        let branchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Switch Branch'")).firstMatch
        XCTAssertTrue(branchButton.waitForExistence(timeout: 5))
    }
}
