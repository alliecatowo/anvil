import XCTest
import Testing
@testable import AnvilDomain

// MARK: - Legacy XCTest (kept for CI compatibility with original tests)

final class AnvilDomainLegacyTests: XCTestCase {
    func testEntityIdGeneration() {
        let id1 = EntityID<String>()
        let id2 = EntityID<String>()
        XCTAssertNotEqual(id1, id2)
    }

    func testEntityIdFromStringLiteral() {
        let id: EntityID<String> = "test-id"
        XCTAssertEqual(id.rawValue, "test-id")
    }

    func testTicketPriorityOrdering() {
        XCTAssertTrue(TicketPriority.critical < TicketPriority.high)
        XCTAssertTrue(TicketPriority.high < TicketPriority.medium)
        XCTAssertTrue(TicketPriority.medium < TicketPriority.low)
    }

    func testApprovalPolicyDefaultAsks() {
        let policy = ApprovalPolicy(rules: [
            ApprovalRule(pattern: "read_", action: .autoApprove),
            ApprovalRule(pattern: "write_", action: .ask),
        ])
        XCTAssertFalse(policy.requiresApproval(for: "read_file"))
        XCTAssertTrue(policy.requiresApproval(for: "write_file"))
        XCTAssertTrue(policy.requiresApproval(for: "unknown_tool"))
    }
}

// MARK: - EntityID

@Suite("EntityID")
struct EntityIDTests {

    @Test("Two default-initialised IDs are unique")
    func uniqueByDefault() {
        let a = EntityID<Int>()
        let b = EntityID<Int>()
        #expect(a != b)
    }

    @Test("Explicit raw value is preserved")
    func rawValuePreserved() {
        let id = EntityID<Bool>("abc-123")
        #expect(id.rawValue == "abc-123")
    }

    @Test("String-literal initialisation")
    func stringLiteral() {
        let id: EntityID<Double> = "literal-value"
        #expect(id.rawValue == "literal-value")
    }

    @Test("Description equals rawValue")
    func descriptionMatchesRawValue() {
        let id = EntityID<Float>("desc-test")
        #expect(id.description == "desc-test")
    }

    @Test("Same raw value produces equal IDs")
    func equalityOnSameRaw() {
        let a = EntityID<String>("same")
        let b = EntityID<String>("same")
        #expect(a == b)
    }

    @Test("Different raw values produce unequal IDs")
    func inequalityOnDifferentRaw() {
        let a = EntityID<String>("foo")
        let b = EntityID<String>("bar")
        #expect(a != b)
    }

    @Test("EntityID is usable as Dictionary key (Hashable)")
    func hashable() {
        var dict: [EntityID<String>: Int] = [:]
        let id: EntityID<String> = "key"
        dict[id] = 42
        #expect(dict[id] == 42)
    }

    @Test("EntityID round-trips through Codable")
    func codable() throws {
        let original = EntityID<String>("codable-test")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EntityID<String>.self, from: data)
        #expect(decoded == original)
    }

    @Test("Type phantom prevents cross-type equality")
    func phantomTypeSafety() {
        // Different phantom types should produce different Swift types —
        // the compiler enforces this; we verify the raw value is still correct
        let stringID = EntityID<String>("shared-raw")
        let intID = EntityID<Int>("shared-raw")
        #expect(stringID.rawValue == intID.rawValue)
        // (They cannot be compared with == because the types differ — compile-time safety)
    }
}

// MARK: - DomainError

@Suite("AnvilDomainError")
struct DomainErrorTests {

    @Test("notFound carries entity and id")
    func notFound() {
        let err = AnvilDomainError.notFound(entity: "Ticket", id: "t-1")
        if case .notFound(let entity, let id) = err {
            #expect(entity == "Ticket")
            #expect(id == "t-1")
        } else {
            Issue.record("Wrong case")
        }
    }

    @Test("invalidState carries message")
    func invalidState() {
        let err = AnvilDomainError.invalidState(message: "bad state")
        if case .invalidState(let msg) = err {
            #expect(msg == "bad state")
        } else {
            Issue.record("Wrong case")
        }
    }

    @Test("budgetExceeded carries limit and current")
    func budgetExceeded() {
        let err = AnvilDomainError.budgetExceeded(provider: "anthropic", limit: 10, current: 15)
        if case .budgetExceeded(let provider, let limit, let current) = err {
            #expect(provider == "anthropic")
            #expect(limit == 10)
            #expect(current == 15)
        } else {
            Issue.record("Wrong case")
        }
    }

    @Test("rateLimited with nil retryAfter")
    func rateLimitedNilRetry() {
        let err = AnvilDomainError.rateLimited(provider: "openai", retryAfter: nil)
        if case .rateLimited(let provider, let retry) = err {
            #expect(provider == "openai")
            #expect(retry == nil)
        } else {
            Issue.record("Wrong case")
        }
    }

    @Test("timeout carries operation and duration")
    func timeout() {
        let err = AnvilDomainError.timeout(operation: "embed", duration: 30)
        if case .timeout(let op, let dur) = err {
            #expect(op == "embed")
            #expect(dur == 30)
        } else {
            Issue.record("Wrong case")
        }
    }

    @Test("AnvilDomainError conforms to Error and Sendable")
    func conformances() {
        let err: any Error = AnvilDomainError.conflict(message: "c")
        #expect(err is AnvilDomainError)
    }
}

// MARK: - DomainEvent

@Suite("AnyDomainEvent")
struct DomainEventTests {

    @Test("Default eventId is a UUID string")
    func defaultEventId() {
        let event = AnyDomainEvent(sourcePrimitive: "test", payload: "hello")
        #expect(!event.eventId.isEmpty)
    }

    @Test("Custom eventId is preserved")
    func customEventId() {
        let event = AnyDomainEvent(eventId: "my-id", sourcePrimitive: "x", payload: 1)
        #expect(event.eventId == "my-id")
    }

    @Test("sourcePrimitive is preserved")
    func sourcePrimitive() {
        let event = AnyDomainEvent(sourcePrimitive: "tickets", payload: "payload")
        #expect(event.sourcePrimitive == "tickets")
    }

    @Test("Timestamp is approximately now")
    func timestampApproxNow() {
        let before = Date.now
        let event = AnyDomainEvent(sourcePrimitive: "x", payload: "y")
        let after = Date.now
        #expect(event.timestamp >= before)
        #expect(event.timestamp <= after)
    }

    @Test("Two events have different default eventIds")
    func uniqueEventIds() {
        let a = AnyDomainEvent(sourcePrimitive: "x", payload: "p")
        let b = AnyDomainEvent(sourcePrimitive: "x", payload: "p")
        #expect(a.eventId != b.eventId)
    }
}

// MARK: - Ticket

@Suite("Ticket")
struct TicketTests {

    @Test("Default status is open")
    func defaultStatus() {
        let t = Ticket(title: "Fix login")
        #expect(t.status == "open")
    }

    @Test("Default priority is medium")
    func defaultPriority() {
        let t = Ticket(title: "Fix login")
        #expect(t.priority == .medium)
    }

    @Test("Custom fields are stored correctly")
    func customFields() {
        let t = Ticket(
            id: "t-1",
            title: "Deploy service",
            description: "Deploy the new microservice",
            status: "in-progress",
            priority: .high,
            assignee: "alice",
            labels: ["backend", "infra"],
            storyPoints: 5,
            epicId: "epic-42"
        )
        #expect(t.id == "t-1")
        #expect(t.title == "Deploy service")
        #expect(t.description == "Deploy the new microservice")
        #expect(t.status == "in-progress")
        #expect(t.priority == .high)
        #expect(t.assignee == "alice")
        #expect(t.labels == ["backend", "infra"])
        #expect(t.storyPoints == 5)
        #expect(t.epicId == "epic-42")
    }

    @Test("Ticket round-trips through Codable")
    func codable() throws {
        let original = Ticket(title: "Codable ticket", priority: .critical)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Ticket.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.priority == original.priority)
    }

    @Test("TicketDraft stores all fields")
    func ticketDraft() {
        let draft = TicketDraft(
            title: "Draft ticket",
            description: "desc",
            priority: .low,
            labels: ["qa"],
            assignee: "bob",
            epicId: "epic-1"
        )
        #expect(draft.title == "Draft ticket")
        #expect(draft.description == "desc")
        #expect(draft.priority == .low)
        #expect(draft.labels == ["qa"])
        #expect(draft.assignee == "bob")
        #expect(draft.epicId == "epic-1")
    }

    @Test("TicketUpdate with nil fields")
    func ticketUpdateNilFields() {
        let update = TicketUpdate()
        #expect(update.title == nil)
        #expect(update.status == nil)
        #expect(update.priority == nil)
        #expect(update.assignee == nil)
    }

    @Test("TicketUpdate with values")
    func ticketUpdateWithValues() {
        let update = TicketUpdate(title: "New title", status: "done", priority: .critical, storyPoints: 8)
        #expect(update.title == "New title")
        #expect(update.status == "done")
        #expect(update.priority == .critical)
        #expect(update.storyPoints == 8)
    }

    @Test("TicketFilter stores filter criteria")
    func ticketFilter() {
        let filter = TicketFilter(status: "open", priority: .high, assignee: "alice", labels: ["bug"])
        #expect(filter.status == "open")
        #expect(filter.priority == .high)
        #expect(filter.assignee == "alice")
        #expect(filter.labels == ["bug"])
    }
}

// MARK: - TicketPriority

@Suite("TicketPriority")
struct TicketPriorityTests {

    @Test("Full ordering: critical < high < medium < low < none")
    func fullOrdering() {
        #expect(TicketPriority.critical < .high)
        #expect(TicketPriority.high < .medium)
        #expect(TicketPriority.medium < .low)
        #expect(TicketPriority.low < .none)
    }

    @Test("Raw values are 0 through 4")
    func rawValues() {
        #expect(TicketPriority.critical.rawValue == 0)
        #expect(TicketPriority.high.rawValue == 1)
        #expect(TicketPriority.medium.rawValue == 2)
        #expect(TicketPriority.low.rawValue == 3)
        #expect(TicketPriority.none.rawValue == 4)
    }

    @Test("TicketPriority round-trips through Codable")
    func codable() throws {
        for priority in [TicketPriority.critical, .high, .medium, .low, .none] {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(TicketPriority.self, from: data)
            #expect(decoded == priority)
        }
    }

    @Test("Priority is not less than itself")
    func reflexivity() {
        #expect(!(TicketPriority.medium < .medium))
    }
}

// MARK: - AgentSession

@Suite("AgentSession")
struct AgentSessionTests {

    @Test("Default status is idle")
    func defaultStatus() {
        let session = AgentSession(providerId: "anthropic", model: "claude-opus-4-6")
        #expect(session.status == .idle)
    }

    @Test("Default token usage is zero")
    func defaultTokenUsage() {
        let session = AgentSession(providerId: "anthropic", model: "claude-opus-4-6")
        #expect(session.tokenUsage.inputTokens == 0)
        #expect(session.tokenUsage.outputTokens == 0)
        #expect(session.tokenUsage.totalTokens == 0)
    }

    @Test("Default cost is zero")
    func defaultCost() {
        let session = AgentSession(providerId: "anthropic", model: "claude-opus-4-6")
        #expect(session.cost == 0)
    }

    @Test("budgetUsage is nil when no budget is set")
    func budgetUsageNilWithNoBudget() {
        let session = AgentSession(providerId: "p", model: "m", cost: 5)
        #expect(session.budgetUsage == nil)
    }

    @Test("budgetUsage is nil when budget is zero")
    func budgetUsageNilWithZeroBudget() {
        let session = AgentSession(providerId: "p", model: "m", cost: 5, costBudget: 0)
        #expect(session.budgetUsage == nil)
    }

    @Test("budgetUsage is 0.5 at half budget")
    func budgetUsageHalf() {
        let session = AgentSession(providerId: "p", model: "m", cost: 5, costBudget: 10)
        #expect(abs((session.budgetUsage ?? 0) - 0.5) < 0.001)
    }

    @Test("budgetUsage exceeds 1 when over budget")
    func budgetUsageOverBudget() {
        let session = AgentSession(providerId: "p", model: "m", cost: 15, costBudget: 10)
        #expect((session.budgetUsage ?? 0) > 1.0)
    }

    @Test("displayName uses customName when set")
    func displayNameCustom() {
        let session = AgentSession(providerId: "p", model: "m", customName: "My Session")
        #expect(session.displayName == "My Session")
    }

    @Test("displayName falls back to workItemId")
    func displayNameWorkItem() {
        let session = AgentSession(providerId: "p", model: "m", workItemId: "ANV-42")
        #expect(session.displayName == "ANV-42")
    }

    @Test("displayName falls back to first user message preview")
    func displayNameMessagePreview() {
        let msg = AgentMessage(role: .user, content: "Fix the login bug")
        let session = AgentSession(providerId: "p", model: "m", messages: [msg])
        #expect(session.displayName == "Fix the login bug")
    }

    @Test("displayName truncates long first message")
    func displayNameTruncated() {
        let longContent = String(repeating: "a", count: 50)
        let msg = AgentMessage(role: .user, content: longContent)
        let session = AgentSession(providerId: "p", model: "m", messages: [msg])
        let name = session.displayName
        #expect(name.hasSuffix("..."))
        #expect(name.count <= 43) // 40 chars + "..."
    }

    @Test("displayName defaults to Session when no other data")
    func displayNameDefault() {
        let session = AgentSession(providerId: "p", model: "m")
        #expect(session.displayName == "Session")
    }

    @Test("AgentSession round-trips through Codable")
    func codable() throws {
        let session = AgentSession(
            id: "s-1",
            providerId: "anthropic",
            model: "claude-opus-4-6",
            status: .running,
            cost: Decimal(string: "1.23")!
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(AgentSession.self, from: data)
        #expect(decoded.id == "s-1")
        #expect(decoded.status == .running)
    }

    @Test("All AgentSessionStatus cases have raw string values")
    func statusRawValues() {
        let cases: [AgentSessionStatus] = [.idle, .running, .paused, .completed, .failed, .cancelled]
        for status in cases {
            #expect(!status.rawValue.isEmpty)
        }
    }
}

// MARK: - TokenUsage

@Suite("TokenUsage")
struct TokenUsageTests {

    @Test("totalTokens sums input and output")
    func totalTokens() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        #expect(usage.totalTokens == 150)
    }

    @Test("zero static is all zeros")
    func zeroStatic() {
        let z = TokenUsage.zero
        #expect(z.inputTokens == 0)
        #expect(z.outputTokens == 0)
        #expect(z.cacheReadTokens == 0)
        #expect(z.cacheWriteTokens == 0)
        #expect(z.totalTokens == 0)
    }

    @Test("Cache tokens are independent of total")
    func cacheTokensIndependent() {
        let usage = TokenUsage(inputTokens: 10, outputTokens: 20, cacheReadTokens: 5, cacheWriteTokens: 3)
        // totalTokens only sums input + output
        #expect(usage.totalTokens == 30)
        #expect(usage.cacheReadTokens == 5)
        #expect(usage.cacheWriteTokens == 3)
    }

    @Test("TokenUsage round-trips through Codable")
    func codable() throws {
        let usage = TokenUsage(inputTokens: 200, outputTokens: 80, cacheReadTokens: 10, cacheWriteTokens: 5)
        let data = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        #expect(decoded.inputTokens == 200)
        #expect(decoded.outputTokens == 80)
        #expect(decoded.cacheReadTokens == 10)
        #expect(decoded.cacheWriteTokens == 5)
    }
}

// MARK: - CostEstimate

@Suite("CostEstimate")
struct CostEstimateTests {

    @Test("All fields stored correctly")
    func fieldsStored() {
        let est = CostEstimate(
            estimatedInputTokens: 1000,
            estimatedOutputTokens: 500,
            estimatedCost: Decimal(string: "0.15")!,
            model: "claude-sonnet-4-6"
        )
        #expect(est.estimatedInputTokens == 1000)
        #expect(est.estimatedOutputTokens == 500)
        #expect(est.estimatedCost == Decimal(string: "0.15")!)
        #expect(est.model == "claude-sonnet-4-6")
    }

    @Test("CostEstimate round-trips through Codable")
    func codable() throws {
        let original = CostEstimate(estimatedInputTokens: 50, estimatedOutputTokens: 25, estimatedCost: 0.01, model: "gpt-4o")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CostEstimate.self, from: data)
        #expect(decoded.estimatedInputTokens == 50)
        #expect(decoded.model == "gpt-4o")
    }
}

// MARK: - ACPCostEstimate

@Suite("ACPCostEstimate")
struct ACPCostEstimateTests {

    @Test("All fields stored correctly")
    func fieldsStored() {
        let est = ACPCostEstimate(estimatedInputTokens: 2000, estimatedOutputTokens: 800, estimatedCost: 0.05)
        #expect(est.estimatedInputTokens == 2000)
        #expect(est.estimatedOutputTokens == 800)
        #expect(est.estimatedCost == 0.05)
    }

    @Test("ACPCostEstimate round-trips through Codable")
    func codable() throws {
        let original = ACPCostEstimate(estimatedInputTokens: 100, estimatedOutputTokens: 50, estimatedCost: 0.002)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ACPCostEstimate.self, from: data)
        #expect(decoded.estimatedInputTokens == 100)
        #expect(decoded.estimatedOutputTokens == 50)
    }
}

// MARK: - ACPCostTracker

@Suite("ACPCostTracker")
struct ACPCostTrackerTests {

    @Test("todayCost starts at zero")
    func todayCostStartsZero() async {
        let tracker = ACPCostTracker()
        let cost = await tracker.todayCost()
        #expect(cost == 0)
    }

    @Test("todayCost reflects recorded entries from today")
    func todayCostAccumulates() async {
        let tracker = ACPCostTracker()
        let entry = ACPCostTracker.CostEntry(
            provider: "anthropic",
            model: "claude-sonnet-4-6",
            inputTokens: 100,
            outputTokens: 50,
            cost: 0.05,
            timestamp: .now
        )
        await tracker.record(entry)
        let cost = await tracker.todayCost()
        #expect(cost == 0.05)
    }

    @Test("todayCost filters by provider")
    func todayCostByProvider() async {
        let tracker = ACPCostTracker()
        await tracker.record(ACPCostTracker.CostEntry(provider: "anthropic", model: "m", inputTokens: 0, outputTokens: 0, cost: 0.10, timestamp: .now))
        await tracker.record(ACPCostTracker.CostEntry(provider: "openai", model: "m", inputTokens: 0, outputTokens: 0, cost: 0.20, timestamp: .now))
        let anthropicCost = await tracker.todayCost(provider: "anthropic")
        let openaiCost = await tracker.todayCost(provider: "openai")
        #expect(anthropicCost == 0.10)
        #expect(openaiCost == 0.20)
    }

    @Test("sessionCost filters to entries since the given date")
    func sessionCostFiltering() async {
        let tracker = ACPCostTracker()
        let oldDate = Date(timeIntervalSinceNow: -7200) // 2 hours ago
        let cutoff = Date(timeIntervalSinceNow: -3600)  // 1 hour ago
        await tracker.record(ACPCostTracker.CostEntry(provider: "p", model: "m", inputTokens: 0, outputTokens: 0, cost: 0.50, timestamp: oldDate))
        await tracker.record(ACPCostTracker.CostEntry(provider: "p", model: "m", inputTokens: 0, outputTokens: 0, cost: 0.25, timestamp: .now))
        let sessionCost = await tracker.sessionCost(since: cutoff)
        #expect(sessionCost == 0.25)
    }

    @Test("isWithinBudget is true when no budget set")
    func withinBudgetNoBudget() async {
        let tracker = ACPCostTracker()
        await tracker.record(ACPCostTracker.CostEntry(provider: "p", model: "m", inputTokens: 0, outputTokens: 0, cost: 999, timestamp: .now))
        let within = await tracker.isWithinBudget(provider: "p")
        #expect(within == true)
    }

    @Test("isWithinBudget is true when cost is below budget")
    func withinBudgetBelow() async {
        let tracker = ACPCostTracker()
        await tracker.setBudget(1.00, for: "anthropic")
        await tracker.record(ACPCostTracker.CostEntry(provider: "anthropic", model: "m", inputTokens: 0, outputTokens: 0, cost: 0.50, timestamp: .now))
        let within = await tracker.isWithinBudget(provider: "anthropic")
        #expect(within == true)
    }

    @Test("isWithinBudget is false when cost meets or exceeds budget")
    func withinBudgetExceeded() async {
        let tracker = ACPCostTracker()
        await tracker.setBudget(1.00, for: "anthropic")
        await tracker.record(ACPCostTracker.CostEntry(provider: "anthropic", model: "m", inputTokens: 0, outputTokens: 0, cost: 1.50, timestamp: .now))
        let within = await tracker.isWithinBudget(provider: "anthropic")
        #expect(within == false)
    }

    @Test("Multiple entries accumulate correctly")
    func multipleEntries() async {
        let tracker = ACPCostTracker()
        for _ in 0..<5 {
            await tracker.record(ACPCostTracker.CostEntry(provider: "p", model: "m", inputTokens: 0, outputTokens: 0, cost: 0.10, timestamp: .now))
        }
        let total = await tracker.todayCost()
        #expect(total == 0.50)
    }
}

// MARK: - Review

@Suite("Review")
struct ReviewTests {

    @Test("Default status is pending")
    func defaultPending() {
        let r = Review(title: "PR #1", sourceType: .pullRequest, sourceId: "pr-1", author: "alice")
        #expect(r.status == .pending)
    }

    @Test("Custom status is stored")
    func customStatus() {
        let r = Review(title: "Agent review", sourceType: .agentSession, sourceId: "s-1", status: .approved, author: "alice")
        #expect(r.status == .approved)
    }

    @Test("All ReviewStatus cases have raw string values")
    func statusRawValues() {
        let cases: [ReviewStatus] = [.pending, .approved, .changesRequested, .dismissed]
        for s in cases {
            #expect(!s.rawValue.isEmpty)
        }
    }

    @Test("ReviewSourceType cases have raw string values")
    func sourceTypeRawValues() {
        let cases: [ReviewSourceType] = [.pullRequest, .agentSession, .manualSelection]
        for st in cases {
            #expect(!st.rawValue.isEmpty)
        }
    }

    @Test("Review stores comments")
    func storesComments() {
        let comment = ReviewComment(author: "bob", body: "Looks good")
        let r = Review(title: "T", sourceType: .pullRequest, sourceId: "pr-2", author: "alice", comments: [comment])
        #expect(r.comments.count == 1)
        #expect(r.comments[0].body == "Looks good")
    }

    @Test("Review round-trips through Codable")
    func codable() throws {
        let r = Review(id: "r-1", title: "Test review", sourceType: .manualSelection, sourceId: "sel-1", status: .changesRequested, author: "dev")
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(Review.self, from: data)
        #expect(decoded.id == "r-1")
        #expect(decoded.status == .changesRequested)
        #expect(decoded.author == "dev")
    }
}

// MARK: - ReviewComment

@Suite("ReviewComment")
struct ReviewCommentTests {

    @Test("Default isResolved is false")
    func defaultNotResolved() {
        let c = ReviewComment(author: "alice", body: "Fix this")
        #expect(c.isResolved == false)
    }

    @Test("Default isAIGenerated is false")
    func defaultNotAI() {
        let c = ReviewComment(author: "alice", body: "Body")
        #expect(c.isAIGenerated == false)
    }

    @Test("Line range is stored correctly")
    func lineRange() {
        let c = ReviewComment(author: "alice", body: "See here", filePath: "main.swift", lineRange: 10...20)
        #expect(c.filePath == "main.swift")
        #expect(c.lineRange == 10...20)
    }

    @Test("ReviewComment round-trips through Codable")
    func codable() throws {
        let original = ReviewComment(id: "c-1", author: "bob", body: "LGTM", filePath: "src/main.swift", lineRange: 5...10, isResolved: true, isAIGenerated: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReviewComment.self, from: data)
        #expect(decoded.id == "c-1")
        #expect(decoded.isResolved == true)
        #expect(decoded.isAIGenerated == true)
        #expect(decoded.lineRange == 5...10)
    }
}

// MARK: - ApprovalPolicy

@Suite("ApprovalPolicy")
struct ApprovalPolicyTests {

    @Test("autoApprove rule prevents approval requirement")
    func autoApproveRule() {
        let policy = ApprovalPolicy(rules: [ApprovalRule(pattern: "read_file", action: .autoApprove)])
        #expect(policy.requiresApproval(for: "read_file") == false)
    }

    @Test("ask rule requires approval")
    func askRule() {
        let policy = ApprovalPolicy(rules: [ApprovalRule(pattern: "delete_", action: .ask)])
        #expect(policy.requiresApproval(for: "delete_file") == true)
    }

    @Test("unknown tool defaults to requiring approval")
    func unknownToolRequiresApproval() {
        let policy = ApprovalPolicy(rules: [ApprovalRule(pattern: "read_", action: .autoApprove)])
        #expect(policy.requiresApproval(for: "unknown_tool") == true)
    }

    @Test("First matching rule wins")
    func firstMatchWins() {
        let policy = ApprovalPolicy(rules: [
            ApprovalRule(pattern: "write_", action: .autoApprove),
            ApprovalRule(pattern: "write_production", action: .ask),
        ])
        // "write_production" matches the first rule "write_" prefix, so autoApprove wins
        #expect(policy.requiresApproval(for: "write_production") == false)
    }

    @Test("alwaysDeny rule does NOT require approval (returns false for requiresApproval)")
    func alwaysDenyNotAsk() {
        // alwaysDeny is not .ask, so requiresApproval returns false
        let policy = ApprovalPolicy(rules: [ApprovalRule(pattern: "rm_", action: .alwaysDeny)])
        #expect(policy.requiresApproval(for: "rm_all") == false)
    }

    @Test("Wildcard pattern matches any tool")
    func wildcardPattern() {
        let policy = ApprovalPolicy(rules: [ApprovalRule(pattern: "*", action: .autoApprove)])
        #expect(policy.requiresApproval(for: "any_tool_name") == false)
    }

    @Test("Empty rules list always requires approval")
    func emptyRules() {
        let policy = ApprovalPolicy(rules: [])
        #expect(policy.requiresApproval(for: "read_file") == true)
    }

    @Test("ApprovalPolicy round-trips through Codable")
    func codable() throws {
        let policy = ApprovalPolicy(rules: [
            ApprovalRule(pattern: "read_", action: .autoApprove),
            ApprovalRule(pattern: "write_", action: .ask),
        ])
        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(ApprovalPolicy.self, from: data)
        #expect(decoded.rules.count == 2)
        #expect(decoded.rules[0].action == .autoApprove)
        #expect(decoded.rules[1].action == .ask)
    }
}

// MARK: - ApprovalRule matching

@Suite("ApprovalRule matching")
struct ApprovalRuleMatchingTests {

    @Test("Exact match and prefix match both succeed")
    func exactAndPrefixMatch() {
        let rule = ApprovalRule(pattern: "read_file", action: .autoApprove)
        // Exact match
        #expect(rule.matches("read_file") == true)
        // "read_file" is a prefix of "read_files", so it also matches
        #expect(rule.matches("read_files") == true)
        // Completely unrelated name does not match
        #expect(rule.matches("write_file") == false)
    }

    @Test("Prefix match")
    func prefixMatch() {
        let rule = ApprovalRule(pattern: "write_", action: .ask)
        #expect(rule.matches("write_file") == true)
        #expect(rule.matches("write_db") == true)
        #expect(rule.matches("read_file") == false)
    }

    @Test("Wildcard * matches everything")
    func wildcardMatchesAll() {
        let rule = ApprovalRule(pattern: "*", action: .autoApprove)
        #expect(rule.matches("anything") == true)
        #expect(rule.matches("") == true)
    }
}

// MARK: - AgentGuardrails

@Suite("AgentGuardrails")
struct AgentGuardrailsTests {

    @Test("Protected file is detected by exact match")
    func exactFileMatch() {
        var guardrails = AgentGuardrails()
        guardrails.protectedFiles = [FileGuardrail(pattern: "config/production.yml", reason: "prod config")]
        #expect(guardrails.isFileProtected("config/production.yml") != nil)
        #expect(guardrails.isFileProtected("config/staging.yml") == nil)
    }

    @Test("Protected file detected by extension glob")
    func extensionGlob() {
        var guardrails = AgentGuardrails()
        guardrails.protectedFiles = [FileGuardrail(pattern: "*.lock", reason: "lockfiles")]
        #expect(guardrails.isFileProtected("Package.resolved") == nil) // not .lock
        #expect(guardrails.isFileProtected("Package.lock") != nil)
        #expect(guardrails.isFileProtected("yarn.lock") != nil)
    }

    @Test("Protected directory glob with /*")
    func directoryGlob() {
        var guardrails = AgentGuardrails()
        guardrails.protectedFiles = [FileGuardrail(pattern: "migrations/*", reason: "migrations")]
        #expect(guardrails.isFileProtected("migrations/001_create_users.sql") != nil)
        #expect(guardrails.isFileProtected("src/main.swift") == nil)
    }

    @Test("Blocked command detected by substring")
    func blockedCommand() {
        var guardrails = AgentGuardrails()
        guardrails.blockedCommands = [CommandGuardrail(pattern: "git push --force", reason: "no force push")]
        #expect(guardrails.isCommandBlocked("git push --force origin main") != nil)
        #expect(guardrails.isCommandBlocked("git pull") == nil)
    }

    @Test("Command matching is case-insensitive")
    func caseInsensitiveCommand() {
        var guardrails = AgentGuardrails()
        guardrails.blockedCommands = [CommandGuardrail(pattern: "drop table", reason: "sql safety")]
        #expect(guardrails.isCommandBlocked("DROP TABLE users") != nil)
        #expect(guardrails.isCommandBlocked("Drop Table users") != nil)
    }

    @Test("Empty guardrails allow everything")
    func emptyGuardrails() {
        let guardrails = AgentGuardrails()
        #expect(guardrails.isFileProtected("anything.swift") == nil)
        #expect(guardrails.isCommandBlocked("rm -rf /") == nil)
    }

    @Test("GuardrailAction has block and warn cases")
    func guardrailActionCases() {
        let block = GuardrailAction.block
        let warn = GuardrailAction.warn
        #expect(block.rawValue == "block")
        #expect(warn.rawValue == "warn")
    }
}

// MARK: - ToolPermissionStore

@Suite("ToolPermissionStore")
struct ToolPermissionStoreTests {

    @Test("decision returns nil when no permissions stored")
    func emptyStore() {
        let store = ToolPermissionStore()
        #expect(store.decision(for: "read_file") == nil)
    }

    @Test("stored permission is returned")
    func storedPermission() {
        var store = ToolPermissionStore()
        store.setPermission(toolName: "read_file", action: .autoApprove)
        #expect(store.decision(for: "read_file") == .autoApprove)
    }

    @Test("setPermission replaces existing entry")
    func replacesExisting() {
        var store = ToolPermissionStore()
        store.setPermission(toolName: "write_file", action: .autoApprove)
        store.setPermission(toolName: "write_file", action: .ask)
        // Only one entry remains
        #expect(store.permissions.filter { $0.toolName == "write_file" }.count == 1)
        #expect(store.decision(for: "write_file") == .ask)
    }

    @Test("wildcard * matches any tool name")
    func wildcardPermission() {
        var store = ToolPermissionStore()
        store.setPermission(toolName: "*", action: .autoApprove)
        #expect(store.decision(for: "any_tool") == .autoApprove)
    }

    @Test("ToolPermissionStore round-trips through Codable")
    func codable() throws {
        var store = ToolPermissionStore()
        store.setPermission(toolName: "read_file", action: .autoApprove)
        let data = try JSONEncoder().encode(store)
        let decoded = try JSONDecoder().decode(ToolPermissionStore.self, from: data)
        #expect(decoded.decision(for: "read_file") == .autoApprove)
    }
}

// MARK: - AgentPlan

@Suite("AgentPlan")
struct AgentPlanTests {

    @Test("Empty plan has zero progress")
    func emptyPlanZeroProgress() {
        let plan = AgentPlan(title: "Empty", steps: [])
        #expect(plan.progress == 0)
    }

    @Test("All planned steps give zero progress")
    func allPlannedZeroProgress() {
        let steps = [
            PlanStep(title: "Step 1", status: .planned),
            PlanStep(title: "Step 2", status: .planned),
        ]
        let plan = AgentPlan(steps: steps)
        #expect(plan.progress == 0)
    }

    @Test("Completed steps count toward progress")
    func completedProgress() {
        let steps = [
            PlanStep(title: "Step 1", status: .completed),
            PlanStep(title: "Step 2", status: .planned),
        ]
        let plan = AgentPlan(steps: steps)
        #expect(abs(plan.progress - 0.5) < 0.001)
    }

    @Test("Skipped steps count toward progress")
    func skippedCountsAsProgress() {
        let steps = [
            PlanStep(title: "Step 1", status: .skipped),
            PlanStep(title: "Step 2", status: .planned),
        ]
        let plan = AgentPlan(steps: steps)
        #expect(abs(plan.progress - 0.5) < 0.001)
    }

    @Test("All completed gives progress 1.0")
    func allCompletedFullProgress() {
        let steps = [
            PlanStep(title: "A", status: .completed),
            PlanStep(title: "B", status: .completed),
            PlanStep(title: "C", status: .completed),
        ]
        let plan = AgentPlan(steps: steps)
        #expect(abs(plan.progress - 1.0) < 0.001)
    }

    @Test("activeStep returns first .active step")
    func activeStep() {
        let steps = [
            PlanStep(title: "A", status: .completed),
            PlanStep(title: "B", status: .active),
            PlanStep(title: "C", status: .planned),
        ]
        let plan = AgentPlan(steps: steps)
        #expect(plan.activeStep?.title == "B")
    }

    @Test("activeStep is nil when no active step")
    func activeStepNil() {
        let steps = [PlanStep(title: "A", status: .completed)]
        let plan = AgentPlan(steps: steps)
        #expect(plan.activeStep == nil)
    }

    @Test("Default plan status is draft")
    func defaultDraftStatus() {
        let plan = AgentPlan(title: "Plan")
        #expect(plan.status == .draft)
    }

    @Test("PlanStatus all cases have raw values")
    func planStatusRawValues() {
        let cases: [PlanStatus] = [.draft, .approved, .executing, .completed, .cancelled]
        for s in cases {
            #expect(!s.rawValue.isEmpty)
        }
    }

    @Test("PlanStepStatus all cases have raw values")
    func planStepStatusRawValues() {
        let cases: [PlanStepStatus] = [.planned, .active, .completed, .skipped, .failed]
        for s in cases {
            #expect(!s.rawValue.isEmpty)
        }
    }

    @Test("AgentPlan round-trips through Codable")
    func codable() throws {
        let plan = AgentPlan(
            id: "p-1",
            title: "Refactor auth",
            steps: [PlanStep(title: "Read files", status: .completed)],
            status: .executing
        )
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(AgentPlan.self, from: data)
        #expect(decoded.id == "p-1")
        #expect(decoded.status == .executing)
        #expect(decoded.steps.count == 1)
    }
}

// MARK: - ToolCall

@Suite("ToolCall")
struct ToolCallTests {

    @Test("Default status is pending")
    func defaultPending() {
        let tc = ToolCall(name: "read_file", arguments: "{}")
        #expect(tc.status == .pending)
    }

    @Test("Default result is nil")
    func defaultResultNil() {
        let tc = ToolCall(name: "read_file", arguments: "{}")
        #expect(tc.result == nil)
    }

    @Test("Name and arguments are stored")
    func nameAndArguments() {
        let tc = ToolCall(name: "write_file", arguments: "{\"path\": \"foo.swift\"}")
        #expect(tc.name == "write_file")
        #expect(tc.arguments == "{\"path\": \"foo.swift\"}")
    }

    @Test("ToolResult isError flag is stored")
    func toolResultError() {
        let result = ToolResult(content: "file not found", type: .error, isError: true)
        #expect(result.isError == true)
        #expect(result.type == .error)
    }

    @Test("ToolResult default type is text")
    func toolResultDefaultText() {
        let result = ToolResult(content: "success")
        #expect(result.type == .text)
        #expect(result.isError == false)
    }

    @Test("All ToolCallStatus cases have raw values")
    func statusRawValues() {
        let cases: [ToolCallStatus] = [.pending, .approved, .rejected, .running, .completed, .failed]
        for s in cases {
            #expect(!s.rawValue.isEmpty)
        }
    }

    @Test("ToolCall round-trips through Codable")
    func codable() throws {
        let tc = ToolCall(
            id: "tc-1",
            name: "bash",
            arguments: "{\"cmd\": \"ls\"}",
            status: .completed,
            result: ToolResult(content: "main.swift\n", type: .text)
        )
        let data = try JSONEncoder().encode(tc)
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)
        #expect(decoded.id == "tc-1")
        #expect(decoded.status == .completed)
        #expect(decoded.result?.content == "main.swift\n")
    }
}

// MARK: - AgentMessage

@Suite("AgentMessage")
struct AgentMessageTests {

    @Test("Role is stored correctly")
    func roleStored() {
        let msg = AgentMessage(role: .assistant, content: "Hello")
        #expect(msg.role == .assistant)
    }

    @Test("Content is stored correctly")
    func contentStored() {
        let msg = AgentMessage(role: .user, content: "Fix the bug")
        #expect(msg.content == "Fix the bug")
    }

    @Test("Tool calls default to empty")
    func toolCallsDefault() {
        let msg = AgentMessage(role: .assistant, content: "OK")
        #expect(msg.toolCalls.isEmpty)
    }

    @Test("Tool calls are stored")
    func toolCallsStored() {
        let tc = ToolCall(name: "read_file", arguments: "{}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tc])
        #expect(msg.toolCalls.count == 1)
        #expect(msg.toolCalls[0].name == "read_file")
    }

    @Test("All AgentMessageRole cases have raw values")
    func roleRawValues() {
        let cases: [AgentMessageRole] = [.user, .assistant, .system, .tool]
        for r in cases {
            #expect(!r.rawValue.isEmpty)
        }
    }

    @Test("AgentMessage round-trips through Codable")
    func codable() throws {
        let msg = AgentMessage(id: "m-1", role: .user, content: "Hello world")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(AgentMessage.self, from: data)
        #expect(decoded.id == "m-1")
        #expect(decoded.role == .user)
        #expect(decoded.content == "Hello world")
    }
}

// MARK: - AutonomyLevel

@Suite("AutonomyLevel")
struct AutonomyLevelTests {

    @Test("All cases are CaseIterable")
    func allCases() {
        #expect(AutonomyLevel.allCases.count == 3)
    }

    @Test("displayName is non-empty for all cases")
    func displayNames() {
        for level in AutonomyLevel.allCases {
            #expect(!level.displayName.isEmpty)
        }
    }

    @Test("description is non-empty for all cases")
    func descriptions() {
        for level in AutonomyLevel.allCases {
            #expect(!level.description.isEmpty)
        }
    }

    @Test("Raw values match expected strings")
    func rawValues() {
        #expect(AutonomyLevel.ask.rawValue == "ask")
        #expect(AutonomyLevel.review.rawValue == "review")
        #expect(AutonomyLevel.auto.rawValue == "auto")
    }

    @Test("AutonomyLevel round-trips through Codable")
    func codable() throws {
        for level in AutonomyLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(AutonomyLevel.self, from: data)
            #expect(decoded == level)
        }
    }
}

// MARK: - InterPrimitiveLink

@Suite("InterPrimitiveLink")
struct InterPrimitiveLinkTests {

    @Test("All LinkType cases have raw string values")
    func linkTypeRawValues() {
        let cases: [LinkType] = [.linkedTo, .createdFrom, .triggeredBy, .blocks, .blockedBy, .referencedIn]
        for lt in cases {
            #expect(!lt.rawValue.isEmpty)
        }
    }

    @Test("Link stores source and target correctly")
    func sourceAndTarget() {
        let link = InterPrimitiveLink(
            type: .blocks,
            sourcePrimitive: "tickets",
            sourceEntityId: "t-1",
            targetPrimitive: "agents",
            targetEntityId: "s-1"
        )
        #expect(link.type == .blocks)
        #expect(link.sourcePrimitive == "tickets")
        #expect(link.sourceEntityId == "t-1")
        #expect(link.targetPrimitive == "agents")
        #expect(link.targetEntityId == "s-1")
    }

    @Test("Two links have unique IDs")
    func uniqueIds() {
        let a = InterPrimitiveLink(type: .linkedTo, sourcePrimitive: "p", sourceEntityId: "1", targetPrimitive: "q", targetEntityId: "2")
        let b = InterPrimitiveLink(type: .linkedTo, sourcePrimitive: "p", sourceEntityId: "1", targetPrimitive: "q", targetEntityId: "2")
        #expect(a.id != b.id)
    }

    @Test("InterPrimitiveLink round-trips through Codable")
    func codable() throws {
        let link = InterPrimitiveLink(type: .createdFrom, sourcePrimitive: "a", sourceEntityId: "x", targetPrimitive: "b", targetEntityId: "y")
        let data = try JSONEncoder().encode(link)
        let decoded = try JSONDecoder().decode(InterPrimitiveLink.self, from: data)
        #expect(decoded.type == .createdFrom)
        #expect(decoded.sourceEntityId == "x")
    }
}

// MARK: - ACP Types

@Suite("ACP Types")
struct ACPTypesTests {

    @Test("ACPMessage stores role and content")
    func acpMessageFields() {
        let msg = ACPMessage(role: .user, content: "Hello")
        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
        #expect(msg.toolCallId == nil)
    }

    @Test("ACPMessage with toolCallId")
    func acpMessageWithToolCallId() {
        let msg = ACPMessage(role: .tool, content: "result", toolCallId: "tc-abc")
        #expect(msg.toolCallId == "tc-abc")
    }

    @Test("All ACPMessageRole cases have raw values")
    func acpMessageRoleRawValues() {
        let cases: [ACPMessageRole] = [.system, .user, .assistant, .tool]
        for r in cases {
            #expect(!r.rawValue.isEmpty)
        }
    }

    @Test("ACPResponse stores all fields")
    func acpResponseFields() {
        let msg = ACPMessage(role: .assistant, content: "Done")
        let usage = ACPUsage(inputTokens: 100, outputTokens: 50)
        let response = ACPResponse(message: msg, usage: usage, model: "claude-opus-4-6", stopReason: .endTurn)
        #expect(response.model == "claude-opus-4-6")
        #expect(response.stopReason == .endTurn)
        #expect(response.usage.inputTokens == 100)
    }

    @Test("All ACPStopReason cases have raw values")
    func stopReasonRawValues() {
        let cases: [ACPStopReason] = [.endTurn, .toolUse, .maxTokens, .error]
        for r in cases {
            #expect(!r.rawValue.isEmpty)
        }
    }

    @Test("ACPUsage round-trips through Codable")
    func acpUsageCodable() throws {
        let usage = ACPUsage(inputTokens: 200, outputTokens: 80)
        let data = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(ACPUsage.self, from: data)
        #expect(decoded.inputTokens == 200)
        #expect(decoded.outputTokens == 80)
    }

    @Test("ACPMessage round-trips through Codable")
    func acpMessageCodable() throws {
        let msg = ACPMessage(role: .system, content: "System prompt", toolCallId: nil)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ACPMessage.self, from: data)
        #expect(decoded.role == .system)
        #expect(decoded.content == "System prompt")
    }
}

// MARK: - AnvilSpace (tested through AnvilDomain-visible properties only)
// Note: AnvilSpace is defined in AnvilUI (AppState.swift), not AnvilDomain.
// Full AnvilSpace tests live in Tests/UITests/. The properties are verified
// in the UI test suite via XCUIApplication element queries.
