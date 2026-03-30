import XCTest

final class VisualRegressionTests: AnvilUITestCase {
    override var shouldAutoLaunchApp: Bool { false }
    override var shouldCaptureLaunchScreenshot: Bool { false }
    override var shouldCaptureTearDownScreenshot: Bool { false }

    func testBuildEmptyStateScreenshot() throws {
        launchScenario("agent-empty")
        XCTAssertTrue(app.buttons["agent.empty.new-session"].waitForExistence(timeout: 5))
        addScreenshot("agent-empty")
    }

    func testBuildConversationScreenshot() throws {
        launchScenario("agent-conversation")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "agent.conversation.input").firstMatch.waitForExistence(timeout: 5))
        addScreenshot("agent-conversation")
    }

    func testPlanListScreenshot() throws {
        launchScenario("intent-list")
        XCTAssertTrue(app.staticTexts["Sprint 14"].waitForExistence(timeout: 5))
        addScreenshot("plan-list")
    }

    func testPlanBoardScreenshot() throws {
        launchScenario("intent-board")
        XCTAssertTrue(app.staticTexts["Sprint 14"].waitForExistence(timeout: 5))
        addScreenshot("plan-board")
    }

    func testReviewInboxScreenshot() throws {
        launchScenario("review-inbox")
        XCTAssertTrue(app.staticTexts["Review Inbox"].waitForExistence(timeout: 5))
        addScreenshot("review-inbox")
    }

    func testReviewDiffScreenshot() throws {
        launchScenario("review-diff")
        XCTAssertTrue(app.staticTexts["Review Inbox"].waitForExistence(timeout: 5))
        addScreenshot("review-diff")
    }

    func testShipDashboardScreenshot() throws {
        launchScenario("ship-dashboard")
        XCTAssertTrue(app.staticTexts["Deploy Dashboard"].waitForExistence(timeout: 5))
        addScreenshot("ship-dashboard")
    }

    func testNotificationsWorkspaceScreenshot() throws {
        launchScenario("workspace-notifications")
        XCTAssertTrue(app.staticTexts["Inbox"].waitForExistence(timeout: 5))
        addScreenshot("workspace-notifications")
    }

    private func launchScenario(_ scenario: String) {
        launchApp(
            additionalEnvironment: ["ANVIL_UITEST_SCENARIO": scenario],
            captureLaunchScreenshot: false
        )
    }
}
