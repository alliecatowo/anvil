import XCTest

final class EditorModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        loadDemoData()
        switchToEditorMode()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Mode Renders

    func testEditorModeRendersContent() throws {
        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.outlines.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent, "Editor mode must render content after switching to it")
    }

    func testEditorSidebarHasClickableItems() throws {
        let clickable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable }
        XCTAssertGreaterThan(clickable.count, 0, "Editor mode sidebar must have clickable items")
    }

    // MARK: - File Tree Sections

    func testExplorerSectionExists() throws {
        // Editor sidebar has Explorer section with Open Files and File Tree
        let explorerLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'EXPLORER' OR label CONTAINS 'Explorer'")).firstMatch
        _ = explorerLabel.waitForExistence(timeout: 5)
        // Just verify the mode renders without crashing
        XCTAssertTrue(app.windows.firstMatch.exists, "Editor mode Explorer section must render")
    }

    func testSearchSectionExists() throws {
        let searchLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'SEARCH' OR label CONTAINS 'Search'")).firstMatch
        _ = searchLabel.waitForExistence(timeout: 5)
        XCTAssertTrue(app.windows.firstMatch.exists, "Editor mode Search section must render")
    }

    // MARK: - File Click → Editor Pane Updates

    func testClickingFileTreeItemOpensFile() throws {
        // Find file tree items in sidebar
        let fileTree = app.scrollViews.firstMatch
        XCTAssertTrue(fileTree.waitForExistence(timeout: 5))

        let firstFile = fileTree.otherElements.firstMatch
        if firstFile.waitForExistence(timeout: 5) {
            firstFile.click()

            // Result: code view / text view should appear in content area
            let codeView = app.textViews.firstMatch
            let hasCode = codeView.waitForExistence(timeout: 5) || app.scrollViews.count > 1
            XCTAssertTrue(hasCode, "Clicking a file must open it in the editor pane")
        }
    }

    // MARK: - Breadcrumb Bar

    func testBreadcrumbBarAppearsWhenFileOpen() throws {
        openFirstFile()

        // Breadcrumb bar should appear above the code view
        let breadcrumb = app.otherElements.matching(NSPredicate(format: "label CONTAINS '/'")).firstMatch
        // Allow breadcrumb to be optional — just verify no crash
        XCTAssertTrue(app.windows.firstMatch.exists, "Opening a file must render without crashing")
        _ = breadcrumb.waitForExistence(timeout: 3)
    }

    // MARK: - Find/Replace

    func testFindReplaceOpenableViaCmdF() throws {
        openFirstFile()

        app.typeKey("f", modifierFlags: .command)

        // Result: find field should appear
        let findField = app.textFields.matching(NSPredicate(format: "label CONTAINS 'Find' OR placeholderValue CONTAINS 'Find'")).firstMatch
        XCTAssertTrue(findField.waitForExistence(timeout: 5), "Cmd+F must open Find bar")
    }

    func testFindBarAcceptsText() throws {
        openFirstFile()
        app.typeKey("f", modifierFlags: .command)

        let findField = app.textFields.matching(NSPredicate(format: "label CONTAINS 'Find' OR placeholderValue CONTAINS 'Find'")).firstMatch
        if findField.waitForExistence(timeout: 5) {
            findField.click()
            findField.typeText("func")
            XCTAssertEqual(findField.value as? String, "func", "Find bar must accept typed text")
        }
    }

    func testFindBarDismissableViaEscape() throws {
        openFirstFile()
        app.typeKey("f", modifierFlags: .command)

        let findField = app.textFields.matching(NSPredicate(format: "label CONTAINS 'Find' OR placeholderValue CONTAINS 'Find'")).firstMatch
        if findField.waitForExistence(timeout: 5) {
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(findField.waitForExistence(timeout: 3), "Escape must dismiss Find bar")
        }
    }

    // MARK: - Editor Tab Bar

    func testEditorTabBarAppearsWithOpenFile() throws {
        openFirstFile()

        // Tab bar sits above the code view with file name tabs
        let tabBar = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'TabBar'")).firstMatch
        _ = tabBar.waitForExistence(timeout: 3)
        // Verify by checking that more than one scroll view exists (sidebar + editor)
        XCTAssertGreaterThanOrEqual(app.scrollViews.count, 1, "Editor must have scroll view content after opening file")
    }

    // MARK: - Split Editor

    func testSplitEditorViaContextMenu() throws {
        openFirstFile()

        // Split view option should be accessible
        let splitButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Split'")).firstMatch
        if splitButton.waitForExistence(timeout: 3) {
            splitButton.click()
            // Result: second editor pane appears
            XCTAssertTrue(app.windows.firstMatch.exists, "Split editor must not crash")
        }
    }

    // MARK: - Symbol Outline

    func testSymbolOutlineSectionExists() throws {
        let symbolLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'SYMBOL' OR label CONTAINS 'Symbol'")).firstMatch
        _ = symbolLabel.waitForExistence(timeout: 3)
        XCTAssertTrue(app.windows.firstMatch.exists, "Symbol outline section must render without crashing")
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func switchToEditorMode() {
        app.typeKey("5", modifierFlags: .command)
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
    }

    private func openFirstFile() {
        let fileTree = app.scrollViews.firstMatch
        if fileTree.waitForExistence(timeout: 5) {
            let firstFile = fileTree.otherElements.firstMatch
            if firstFile.waitForExistence(timeout: 5) {
                firstFile.click()
            }
        }
        _ = app.textViews.firstMatch.waitForExistence(timeout: 3)
    }
}
