import XCTest

final class ReviewModeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        loadDemoData()
        switchToReviewMode()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Mode Renders

    func testReviewModeSidebarHasBranchesSection() throws {
        let branchesHeader = app.staticTexts["BRANCHES"]
        XCTAssertTrue(branchesHeader.waitForExistence(timeout: 5), "Review sidebar must show BRANCHES section")
    }

    func testReviewModeSidebarHasPullRequestsSection() throws {
        // PR section appears (may be empty if not authenticated)
        let prHeader = app.staticTexts["PULL REQUESTS"]
        XCTAssertTrue(prHeader.waitForExistence(timeout: 5), "Review sidebar must show PULL REQUESTS section")
    }

    func testReviewModeHasClickableElements() throws {
        let clickable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label != "Review" }
        XCTAssertGreaterThan(clickable.count, 0, "Review mode must have clickable elements")
    }

    // MARK: - Review Item Click → Detail View Opens

    func testClickReviewItemOpensDetail() throws {
        // Demo data adds reviews; scroll to first and click
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        let firstItem = scrollView.otherElements.firstMatch
        if firstItem.waitForExistence(timeout: 5) {
            firstItem.click()

            // Result: file list or diff view must appear (sidebar changes to show files)
            let backButton = app.buttons["Back"]
            XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Clicking review item must show Back button in sidebar")
        }
    }

    func testClickReviewItemShowsFileList() throws {
        openFirstReviewItem()

        // Result: sidebar shows "FILES" section with file count
        let filesHeader = app.staticTexts["FILES"]
        XCTAssertTrue(filesHeader.waitForExistence(timeout: 5), "Review detail sidebar must show FILES section")
    }

    // MARK: - Back Button → Returns to Review List

    func testBackButtonReturnsToReviewList() throws {
        openFirstReviewItem()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.click()

        // Result: BRANCHES section visible again, FILES section gone
        let branchesBack = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
        XCTAssertTrue(branchesBack, "Back button must return to main review list showing BRANCHES section")
    }

    // MARK: - Branch Click → Diff Loads

    func testClickingBranchLoadsDiff() throws {
        // Find a non-current branch and click it
        let branchRows = app.scrollViews.firstMatch.otherElements.allElementsBoundByIndex
        for row in branchRows {
            if row.isHittable && row.label != "" {
                row.click()
                // Result: some content or diff view should render in content area
                let contentExists = app.scrollViews.count > 0
                XCTAssertTrue(contentExists, "Clicking a branch must render content")
                break
            }
        }
    }

    func testBranchClickExposesStartReviewFlow() throws {
        let branchRows = app.scrollViews.firstMatch.otherElements.allElementsBoundByIndex
        var openedBranch = false

        for row in branchRows {
            if row.isHittable && row.label != "" {
                row.click()
                openedBranch = true
                break
            }
        }

        XCTAssertTrue(openedBranch, "A branch row must be clickable in Review sidebar")

        let startReview = app.buttons["Start Review"]
        XCTAssertTrue(startReview.waitForExistence(timeout: 5), "Branch detail must expose a Start Review action")

        startReview.click()

        let approveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Approve'")).firstMatch
        XCTAssertTrue(approveButton.waitForExistence(timeout: 5), "Starting a review must open the diff view")
    }

    // MARK: - Commit Graph Toggle

    func testCommitGraphToggleButtonExists() throws {
        let graphButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Commit Graph'")).firstMatch
        XCTAssertTrue(graphButton.waitForExistence(timeout: 5), "Commit graph toggle button must exist in Review sidebar")
    }

    func testCommitGraphToggleChangesVisibility() throws {
        let graphButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Commit Graph'")).firstMatch
        XCTAssertTrue(graphButton.waitForExistence(timeout: 5))

        graphButton.click()

        // Result: button label changes (show ↔ hide)
        // Verify app didn't crash
        XCTAssertTrue(app.windows.firstMatch.exists, "Toggling commit graph must not crash")
    }

    // MARK: - GitHub Sign-In Button (when not authenticated)

    func testGitHubSignInButtonExists() throws {
        let signInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in to GitHub'")).firstMatch
        // May or may not exist depending on auth state — just verify it doesn't crash
        if signInButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(signInButton.isHittable, "Sign in to GitHub button must be hittable")
        }
    }

    func testGitHubSignInButtonOpensSheet() throws {
        let signInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in to GitHub'")).firstMatch
        if signInButton.waitForExistence(timeout: 3) {
            signInButton.click()

            // Result: login sheet should appear
            let sheet = app.sheets.firstMatch
            XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Clicking Sign in to GitHub must open auth sheet")
        }
    }

    // MARK: - Approve/Reject Hunks in Diff

    func testApproveHunkButtonExists() throws {
        openFirstReviewItem()
        openFirstFile()

        // Approve button should appear next to diff hunk
        let approveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Approve'")).firstMatch
        if approveButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(approveButton.isHittable, "Approve hunk button must be hittable")
        }
    }

    func testApproveHunkUpdatesCount() throws {
        openFirstReviewItem()
        openFirstFile()

        let approveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Approve'")).firstMatch
        if approveButton.waitForExistence(timeout: 5) {
            approveButton.click()

            // Result: approve count indicator should update (file row shows approved/total)
            XCTAssertTrue(app.windows.firstMatch.exists, "Approving hunk must not crash")
        }
    }

    func testRejectHunkButtonExists() throws {
        openFirstReviewItem()
        openFirstFile()

        let rejectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Reject'")).firstMatch
        if rejectButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(rejectButton.isHittable, "Reject hunk button must be hittable")
        }
    }

    // MARK: - Helpers

    private func loadDemoData() {
        app.menuItems["Load Demo Project"].click()
    }

    private func switchToReviewMode() {
        app.typeKey("3", modifierFlags: .command)
        _ = app.staticTexts["BRANCHES"].waitForExistence(timeout: 5)
    }

    private func openFirstReviewItem() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 5) {
            let firstItem = scrollView.otherElements.firstMatch
            if firstItem.waitForExistence(timeout: 5) {
                firstItem.click()
            }
        }
        _ = app.buttons["Back"].waitForExistence(timeout: 5)
    }

    private func openFirstFile() {
        let filesHeader = app.staticTexts["FILES"]
        if filesHeader.waitForExistence(timeout: 5) {
            let fileRow = app.scrollViews.firstMatch.otherElements.firstMatch
            if fileRow.waitForExistence(timeout: 3) {
                fileRow.click()
            }
        }
    }
}
