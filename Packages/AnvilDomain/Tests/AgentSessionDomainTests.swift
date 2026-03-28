import XCTest
@testable import AnvilDomain
import Foundation

/// XCTest coverage for AgentSession domain model: displayName, budgetUsage,
/// Codable round-trips, TokenUsage, AgentMessage, AutonomyLevel.
final class AgentSessionDomainTests: XCTestCase {

    // MARK: - Helpers

    private func makeSession(
        id: String = UUID().uuidString,
        customName: String? = nil,
        workItemId: String? = nil,
        messages: [AgentMessage] = [],
        cost: Decimal = 0,
        costBudget: Decimal? = nil,
        status: AgentSessionStatus = .idle,
        autonomyLevel: AutonomyLevel = .ask,
        tokenUsage: TokenUsage = .zero,
        isBackground: Bool = false
    ) -> AgentSession {
        AgentSession(
            id: id,
            providerId: "anthropic",
            model: "claude-sonnet-4-6",
            status: status,
            workItemId: workItemId,
            tokenUsage: tokenUsage,
            cost: cost,
            messages: messages,
            customName: customName,
            costBudget: costBudget,
            autonomyLevel: autonomyLevel,
            isBackground: isBackground
        )
    }

    private func makeMessage(role: AgentMessageRole, content: String) -> AgentMessage {
        AgentMessage(role: role, content: content)
    }

    // MARK: - displayName: customName wins

    func testDisplayNameUsesCustomNameWhenSet() {
        let session = makeSession(customName: "My Refactor Session")
        XCTAssertEqual(session.displayName, "My Refactor Session")
    }

    func testDisplayNameIgnoresEmptyCustomName() {
        let session = makeSession(customName: "", workItemId: "TICKET-42")
        XCTAssertEqual(session.displayName, "TICKET-42")
    }

    // MARK: - displayName: workItemId fallback

    func testDisplayNameUsesWorkItemIdWhenNoCustomName() {
        let session = makeSession(customName: nil, workItemId: "TICKET-99")
        XCTAssertEqual(session.displayName, "TICKET-99")
    }

    func testDisplayNameWorkItemIdBeatsMessages() {
        let msg = makeMessage(role: .user, content: "This message should not be used")
        let session = makeSession(workItemId: "TICKET-1", messages: [msg])
        XCTAssertEqual(session.displayName, "TICKET-1")
    }

    // MARK: - displayName: first user message preview

    func testDisplayNameUsesFirstUserMessagePreview() {
        let msg = makeMessage(role: .user, content: "Fix the login bug")
        let session = makeSession(messages: [msg])
        XCTAssertEqual(session.displayName, "Fix the login bug")
    }

    func testDisplayNameSkipsNonUserMessages() {
        let system = makeMessage(role: .system, content: "You are a coding assistant")
        let assistant = makeMessage(role: .assistant, content: "Sure, I can help")
        let user = makeMessage(role: .user, content: "Refactor the auth module")
        let session = makeSession(messages: [system, assistant, user])
        XCTAssertEqual(session.displayName, "Refactor the auth module")
    }

    func testDisplayNameTruncatesLongMessageAt40Chars() {
        let longContent = "This is a very long message that exceeds the forty character limit by quite a bit"
        let msg = makeMessage(role: .user, content: longContent)
        let session = makeSession(messages: [msg])
        let name = session.displayName
        XCTAssertTrue(name.hasSuffix("..."), "Long message preview must end with '...'")
        XCTAssertTrue(name.count <= 43, "Truncated name must be at most 43 chars (40 + '...')")
    }

    func testDisplayNameExactly40CharsNoEllipsis() {
        let exact = String(repeating: "x", count: 40)
        let msg = makeMessage(role: .user, content: exact)
        let session = makeSession(messages: [msg])
        XCTAssertEqual(session.displayName, exact)
        XCTAssertFalse(session.displayName.hasSuffix("..."))
    }

    func testDisplayNameFallsBackToSessionWhenNoMessages() {
        let session = makeSession(customName: nil, workItemId: nil, messages: [])
        XCTAssertEqual(session.displayName, "Session")
    }

    func testDisplayNameFallsBackToSessionWhenOnlyNonUserMessages() {
        let system = makeMessage(role: .system, content: "System prompt")
        let session = makeSession(messages: [system])
        XCTAssertEqual(session.displayName, "Session")
    }

    // MARK: - budgetUsage

    func testBudgetUsageNilWhenNoBudgetSet() {
        let session = makeSession(cost: 1.0, costBudget: nil)
        XCTAssertNil(session.budgetUsage)
    }

    func testBudgetUsageNilWhenBudgetIsZero() {
        let session = makeSession(cost: 0.5, costBudget: 0)
        XCTAssertNil(session.budgetUsage)
    }

    func testBudgetUsageZeroWhenCostIsZero() {
        let session = makeSession(cost: 0, costBudget: 10)
        XCTAssertEqual(session.budgetUsage!, 0.0, accuracy: 0.0001)
    }

    func testBudgetUsageHalfWhenCostIsHalfBudget() {
        let session = makeSession(cost: 5, costBudget: 10)
        XCTAssertEqual(session.budgetUsage!, 0.5, accuracy: 0.0001)
    }

    func testBudgetUsageOneWhenCostEqualsBudget() {
        let session = makeSession(cost: 10, costBudget: 10)
        XCTAssertEqual(session.budgetUsage!, 1.0, accuracy: 0.0001)
    }

    func testBudgetUsageExceedsOneWhenOverBudget() {
        let session = makeSession(cost: 15, costBudget: 10)
        XCTAssertGreaterThan(session.budgetUsage!, 1.0)
        XCTAssertEqual(session.budgetUsage!, 1.5, accuracy: 0.0001)
    }

    // MARK: - TokenUsage

    func testTokenUsageZeroSingleton() {
        let usage = TokenUsage.zero
        XCTAssertEqual(usage.inputTokens, 0)
        XCTAssertEqual(usage.outputTokens, 0)
        XCTAssertEqual(usage.cacheReadTokens, 0)
        XCTAssertEqual(usage.cacheWriteTokens, 0)
        XCTAssertEqual(usage.totalTokens, 0)
    }

    func testTokenUsageTotalTokens() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 200)
        XCTAssertEqual(usage.totalTokens, 300)
    }

    func testTokenUsageTotalExcludesCacheTokens() {
        let usage = TokenUsage(inputTokens: 50, outputTokens: 75, cacheReadTokens: 999, cacheWriteTokens: 888)
        XCTAssertEqual(usage.totalTokens, 125, "totalTokens must only sum input + output, not cache tokens")
    }

    func testTokenUsageCodableRoundTrip() throws {
        let usage = TokenUsage(inputTokens: 1234, outputTokens: 5678, cacheReadTokens: 91, cacheWriteTokens: 11)
        let data = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        XCTAssertEqual(decoded.inputTokens, 1234)
        XCTAssertEqual(decoded.outputTokens, 5678)
        XCTAssertEqual(decoded.cacheReadTokens, 91)
        XCTAssertEqual(decoded.cacheWriteTokens, 11)
    }

    // MARK: - AgentSession Codable round-trip

    func testAgentSessionCodableRoundTrip() throws {
        let msg = AgentMessage(
            id: "msg-1",
            role: .user,
            content: "Hello",
            toolCalls: [],
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let original = AgentSession(
            id: "sess-abc",
            providerId: "anthropic",
            model: "claude-opus-4-6",
            status: .running,
            workItemId: "TICKET-7",
            worktreePath: "/tmp/worktree",
            tokenUsage: TokenUsage(inputTokens: 10, outputTokens: 20),
            cost: Decimal(string: "1.23")!,
            startedAt: Date(timeIntervalSince1970: 1_699_000_000),
            lastActivityAt: Date(timeIntervalSince1970: 1_700_000_000),
            messages: [msg],
            customName: "My Session",
            costBudget: Decimal(string: "5.00"),
            hardStopOnBudget: true,
            autonomyLevel: .auto,
            isBackground: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentSession.self, from: data)

        XCTAssertEqual(decoded.id, "sess-abc")
        XCTAssertEqual(decoded.providerId, "anthropic")
        XCTAssertEqual(decoded.model, "claude-opus-4-6")
        XCTAssertEqual(decoded.status, .running)
        XCTAssertEqual(decoded.workItemId, "TICKET-7")
        XCTAssertEqual(decoded.worktreePath, "/tmp/worktree")
        XCTAssertEqual(decoded.tokenUsage.inputTokens, 10)
        XCTAssertEqual(decoded.tokenUsage.outputTokens, 20)
        XCTAssertEqual(decoded.cost, Decimal(string: "1.23")!)
        XCTAssertEqual(decoded.customName, "My Session")
        XCTAssertEqual(decoded.costBudget, Decimal(string: "5.00")!)
        XCTAssertTrue(decoded.hardStopOnBudget)
        XCTAssertEqual(decoded.autonomyLevel, .auto)
        XCTAssertTrue(decoded.isBackground)
        XCTAssertEqual(decoded.messages.count, 1)
        XCTAssertEqual(decoded.messages[0].id, "msg-1")
        XCTAssertEqual(decoded.messages[0].role, .user)
        XCTAssertEqual(decoded.messages[0].content, "Hello")
    }

    func testAgentSessionCodableRoundTripWithNilOptionals() throws {
        let original = makeSession(customName: nil, workItemId: nil, costBudget: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentSession.self, from: data)
        XCTAssertNil(decoded.customName)
        XCTAssertNil(decoded.workItemId)
        XCTAssertNil(decoded.costBudget)
        XCTAssertNil(decoded.worktreePath)
    }

    // MARK: - AgentMessage Codable round-trip

    func testAgentMessageCodableRoundTrip() throws {
        let toolCall = ToolCall(
            id: "tc-1",
            name: "read_file",
            arguments: "{\"path\": \"/tmp/foo\"}",
            status: .completed,
            result: ToolResult(content: "file contents", type: .text, isError: false)
        )
        let msg = AgentMessage(
            id: "m-99",
            role: .assistant,
            content: "Here is the file.",
            toolCalls: [toolCall],
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(AgentMessage.self, from: data)

        XCTAssertEqual(decoded.id, "m-99")
        XCTAssertEqual(decoded.role, .assistant)
        XCTAssertEqual(decoded.content, "Here is the file.")
        XCTAssertEqual(decoded.toolCalls.count, 1)
        XCTAssertEqual(decoded.toolCalls[0].name, "read_file")
        XCTAssertEqual(decoded.toolCalls[0].status, .completed)
        XCTAssertEqual(decoded.toolCalls[0].result?.content, "file contents")
        XCTAssertFalse(decoded.toolCalls[0].result?.isError ?? true)
    }

    // MARK: - AgentSessionStatus

    func testAllStatusCasesRoundTripRawValue() {
        let cases: [AgentSessionStatus] = [.idle, .running, .paused, .completed, .failed, .cancelled]
        for status in cases {
            let recovered = AgentSessionStatus(rawValue: status.rawValue)
            XCTAssertEqual(recovered, status, "AgentSessionStatus '\(status.rawValue)' must round-trip via rawValue")
        }
    }

    // MARK: - AutonomyLevel

    func testAutonomyLevelDisplayNames() {
        XCTAssertEqual(AutonomyLevel.ask.displayName, "Ask")
        XCTAssertEqual(AutonomyLevel.review.displayName, "Review")
        XCTAssertEqual(AutonomyLevel.auto.displayName, "Auto")
    }

    func testAutonomyLevelDescriptions() {
        XCTAssertFalse(AutonomyLevel.ask.description.isEmpty)
        XCTAssertFalse(AutonomyLevel.review.description.isEmpty)
        XCTAssertFalse(AutonomyLevel.auto.description.isEmpty)
    }

    func testAutonomyLevelAllCasesCount() {
        XCTAssertEqual(AutonomyLevel.allCases.count, 3)
    }

    func testAutonomyLevelRawValueRoundTrip() {
        for level in AutonomyLevel.allCases {
            let recovered = AutonomyLevel(rawValue: level.rawValue)
            XCTAssertEqual(recovered, level)
        }
    }

    // MARK: - AgentMessageRole

    func testAgentMessageRoleRawValues() {
        XCTAssertEqual(AgentMessageRole.user.rawValue, "user")
        XCTAssertEqual(AgentMessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(AgentMessageRole.system.rawValue, "system")
        XCTAssertEqual(AgentMessageRole.tool.rawValue, "tool")
    }

    // MARK: - Default values

    func testSessionDefaultsAreReasonable() {
        let session = AgentSession(providerId: "anthropic", model: "claude-haiku-4-5-20251001")
        XCTAssertEqual(session.status, .idle)
        XCTAssertEqual(session.autonomyLevel, .ask)
        XCTAssertFalse(session.hardStopOnBudget)
        XCTAssertFalse(session.isBackground)
        XCTAssertEqual(session.cost, 0)
        XCTAssertEqual(session.tokenUsage.totalTokens, 0)
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertNil(session.customName)
        XCTAssertNil(session.costBudget)
        XCTAssertNil(session.workItemId)
        XCTAssertNil(session.worktreePath)
        XCTAssertNil(session.plan)
    }

    func testSessionIdIsUniqueByDefault() {
        let a = AgentSession(providerId: "anthropic", model: "m")
        let b = AgentSession(providerId: "anthropic", model: "m")
        XCTAssertNotEqual(a.id, b.id)
    }
}
