import XCTest
import AnvilDomain

/// XCTest coverage for agent session display properties:
/// - elapsed time formatting (replicated from AgentSidebar.elapsedTime)
/// - cost formatting
/// - AgentSession.displayName variants (supplement to AgentSessionDomainTests)
/// - budgetUsage boundary values
final class AgentSessionDisplayTests: XCTestCase {

    // MARK: - Elapsed time formatting
    // Replicates AgentSidebar.elapsedTime(from:to:isRunning:)

    private func elapsedTime(interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    func testElapsedTimeUnderOneMinuteShowsSeconds() {
        XCTAssertEqual(elapsedTime(interval: 0), "0s")
        XCTAssertEqual(elapsedTime(interval: 1), "1s")
        XCTAssertEqual(elapsedTime(interval: 45), "45s")
        XCTAssertEqual(elapsedTime(interval: 59), "59s")
    }

    func testElapsedTimeExactlyOneMinuteShowsMinutes() {
        XCTAssertEqual(elapsedTime(interval: 60), "1m")
    }

    func testElapsedTimeUnderOneHourShowsMinutes() {
        XCTAssertEqual(elapsedTime(interval: 61), "1m")
        XCTAssertEqual(elapsedTime(interval: 120), "2m")
        XCTAssertEqual(elapsedTime(interval: 3599), "59m")
    }

    func testElapsedTimeExactlyOneHourShowsHoursAndZeroMinutes() {
        XCTAssertEqual(elapsedTime(interval: 3600), "1h 0m")
    }

    func testElapsedTimeOverOneHourShowsHoursAndMinutes() {
        XCTAssertEqual(elapsedTime(interval: 3660), "1h 1m")
        XCTAssertEqual(elapsedTime(interval: 7200), "2h 0m")
        XCTAssertEqual(elapsedTime(interval: 7260), "2h 1m")
        XCTAssertEqual(elapsedTime(interval: 9000), "2h 30m")
    }

    func testElapsedTimeLargeValue() {
        // 25h 30m = 91800s
        XCTAssertEqual(elapsedTime(interval: 91800), "25h 30m")
    }

    // MARK: - Cost formatting
    // Replicates AgentSidebar.formatCost(_:)

    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 2
        return formatter.string(from: cost as NSDecimalNumber) ?? "$0.00"
    }

    func testFormatCostZero() {
        XCTAssertEqual(formatCost(0), "$0.00")
    }

    func testFormatCostSmallValue() {
        let result = formatCost(Decimal(string: "0.0042")!)
        XCTAssertEqual(result, "$0.0042")
    }

    func testFormatCostRoundsToTwoDecimalsWhenTrailingZeros() {
        let result = formatCost(Decimal(string: "1.50")!)
        XCTAssertEqual(result, "$1.50")
    }

    func testFormatCostOneDollar() {
        let result = formatCost(1)
        XCTAssertEqual(result, "$1.00")
    }

    func testFormatCostLargeValue() {
        let result = formatCost(Decimal(string: "99.9999")!)
        XCTAssertEqual(result, "$99.9999")
    }

    // MARK: - AgentSession displayName (supplemental)

    private func makeSession(
        customName: String? = nil,
        workItemId: String? = nil,
        messages: [AgentMessage] = []
    ) -> AgentSession {
        AgentSession(
            id: UUID().uuidString,
            providerId: "test",
            model: "test-model",
            workItemId: workItemId,
            messages: messages,
            customName: customName
        )
    }

    private func makeUserMessage(_ text: String) -> AgentMessage {
        AgentMessage(role: .user, content: text)
    }

    func testDisplayNameUsesCustomNameWhenPresent() {
        let session = makeSession(customName: "My Important Session")
        XCTAssertEqual(session.displayName, "My Important Session")
    }

    func testDisplayNameIgnoresEmptyCustomName() {
        let session = makeSession(customName: "", workItemId: "TICKET-42")
        XCTAssertEqual(session.displayName, "TICKET-42")
    }

    func testDisplayNameUsesWorkItemIdWhenNoCustomName() {
        let session = makeSession(workItemId: "ANVIL-100")
        XCTAssertEqual(session.displayName, "ANVIL-100")
    }

    func testDisplayNameUsesFirstUserMessagePreview() {
        let session = makeSession(messages: [makeUserMessage("Fix the crash in the editor")])
        XCTAssertEqual(session.displayName, "Fix the crash in the editor")
    }

    func testDisplayNameTruncatesLongUserMessageAt40Chars() {
        let longMsg = String(repeating: "x", count: 50)
        let session = makeSession(messages: [makeUserMessage(longMsg)])
        let name = session.displayName
        XCTAssertTrue(name.hasSuffix("..."), "Expected truncation suffix")
        XCTAssertLessThanOrEqual(name.count, 43) // 40 + "..."
    }

    func testDisplayNameDoesNotTruncateExactly40CharMessage() {
        let msg40 = String(repeating: "a", count: 40)
        let session = makeSession(messages: [makeUserMessage(msg40)])
        XCTAssertEqual(session.displayName, msg40)
        XCTAssertFalse(session.displayName.hasSuffix("..."))
    }

    func testDisplayNameFallsBackToSessionWhenNoInfo() {
        let session = makeSession()
        XCTAssertEqual(session.displayName, "Session")
    }

    // MARK: - budgetUsage boundary values

    func testBudgetUsageNilWhenNoBudget() {
        let session = AgentSession(id: UUID().uuidString, providerId: "test", model: "test-model",
                                   costBudget: nil)
        XCTAssertNil(session.budgetUsage)
    }

    func testBudgetUsageNilWhenBudgetIsZero() {
        let session = AgentSession(id: UUID().uuidString, providerId: "test", model: "test-model",
                                   costBudget: 0)
        XCTAssertNil(session.budgetUsage)
    }

    func testBudgetUsageZeroPointFiveAtHalfSpend() {
        let session = AgentSession(id: UUID().uuidString, providerId: "test", model: "test-model",
                                   cost: Decimal(string: "0.50")!, costBudget: Decimal(string: "1.00"))
        XCTAssertEqual(session.budgetUsage!, 0.5, accuracy: 0.0001)
    }

    func testBudgetUsageOneAtFullSpend() {
        let session = AgentSession(id: UUID().uuidString, providerId: "test", model: "test-model",
                                   cost: Decimal(string: "2.00")!, costBudget: Decimal(string: "2.00"))
        XCTAssertEqual(session.budgetUsage!, 1.0, accuracy: 0.0001)
    }

    func testBudgetUsageCanExceedOne() {
        let session = AgentSession(id: UUID().uuidString, providerId: "test", model: "test-model",
                                   cost: Decimal(string: "1.50")!, costBudget: Decimal(string: "1.00"))
        XCTAssertGreaterThan(session.budgetUsage!, 1.0)
    }
}
