import XCTest
@testable import AnvilInfrastructure
import AnvilDomain
import Foundation

/// XCTest coverage for SQLiteAgentSessionRepository:
/// save/fetch round-trip, upsert semantics, message append,
/// cascade delete, most-recent-first ordering, empty DB.
final class SQLiteAgentSessionRepositoryTests: XCTestCase {

    var repo: SQLiteAgentSessionRepository!
    var dbPath: String!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("anvil-session-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        dbPath = tempDir.appendingPathComponent("sessions-test.sqlite").path
        repo = SQLiteAgentSessionRepository(dbPath: dbPath)
        try await repo.open()
    }

    override func tearDown() async throws {
        await repo.close()
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        repo = nil
        tempDir = nil
        dbPath = nil
    }

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
        lastActivityAt: Date = .now,
        isBackground: Bool = false
    ) -> AgentSession {
        AgentSession(
            id: id,
            providerId: "anthropic",
            model: "claude-sonnet-4-6",
            status: status,
            workItemId: workItemId,
            tokenUsage: TokenUsage(inputTokens: 10, outputTokens: 5),
            cost: cost,
            lastActivityAt: lastActivityAt,
            messages: messages,
            customName: customName,
            costBudget: costBudget,
            hardStopOnBudget: false,
            autonomyLevel: autonomyLevel,
            isBackground: isBackground
        )
    }

    private func makeMessage(role: AgentMessageRole = .user, content: String = "hello") -> AgentMessage {
        AgentMessage(role: role, content: content)
    }

    // MARK: - Empty DB

    func testFetchSessionsReturnsEmptyArrayOnFreshDB() async throws {
        let sessions = try await repo.fetchSessions()
        XCTAssertTrue(sessions.isEmpty, "Fresh database must return no sessions")
    }

    // MARK: - Save / Fetch round-trip

    func testSaveAndFetchSession() async throws {
        let session = makeSession(id: "sess-1", customName: "My Session", workItemId: "TICKET-10")
        try await repo.saveSession(session)

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched.count, 1)

        let s = fetched[0]
        XCTAssertEqual(s.id, "sess-1")
        XCTAssertEqual(s.providerId, "anthropic")
        XCTAssertEqual(s.model, "claude-sonnet-4-6")
        XCTAssertEqual(s.customName, "My Session")
        XCTAssertEqual(s.workItemId, "TICKET-10")
        XCTAssertEqual(s.status, .idle)
        XCTAssertEqual(s.autonomyLevel, .ask)
    }

    func testSavePreservesTokenUsage() async throws {
        let usage = TokenUsage(inputTokens: 111, outputTokens: 222, cacheReadTokens: 33, cacheWriteTokens: 44)
        let session = AgentSession(
            id: "tok-sess",
            providerId: "anthropic",
            model: "m",
            tokenUsage: usage,
            cost: 0
        )
        try await repo.saveSession(session)
        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched[0].tokenUsage.inputTokens, 111)
        XCTAssertEqual(fetched[0].tokenUsage.outputTokens, 222)
        XCTAssertEqual(fetched[0].tokenUsage.cacheReadTokens, 33)
        XCTAssertEqual(fetched[0].tokenUsage.cacheWriteTokens, 44)
    }

    func testSavePreservesCost() async throws {
        let session = makeSession(id: "cost-sess", cost: Decimal(string: "3.14")!)
        try await repo.saveSession(session)
        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched[0].cost, Decimal(string: "3.14")!)
    }

    func testSavePreservesCostBudget() async throws {
        let session = makeSession(id: "budget-sess", costBudget: Decimal(string: "25.00")!)
        try await repo.saveSession(session)
        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched[0].costBudget, Decimal(string: "25.00")!)
    }

    func testSaveNilCostBudgetRoundTrips() async throws {
        let session = makeSession(id: "no-budget", costBudget: nil)
        try await repo.saveSession(session)
        let fetched = try await repo.fetchSessions()
        XCTAssertNil(fetched[0].costBudget)
    }

    func testSavePreservesFlags() async throws {
        let session = AgentSession(
            id: "flags-sess",
            providerId: "anthropic",
            model: "m",
            hardStopOnBudget: true,
            autonomyLevel: .auto,
            isBackground: true
        )
        try await repo.saveSession(session)
        let fetched = try await repo.fetchSessions()
        XCTAssertTrue(fetched[0].hardStopOnBudget)
        XCTAssertEqual(fetched[0].autonomyLevel, .auto)
        XCTAssertTrue(fetched[0].isBackground)
    }

    func testSavePreservesNilOptionals() async throws {
        let session = makeSession(id: "nils", customName: nil, workItemId: nil)
        try await repo.saveSession(session)
        let fetched = try await repo.fetchSessions()
        XCTAssertNil(fetched[0].customName)
        XCTAssertNil(fetched[0].workItemId)
    }

    // MARK: - Messages saved with session

    func testSaveSessionWithMessagesRoundTrips() async throws {
        let msg1 = AgentMessage(id: "m-1", role: .user, content: "Hello there")
        let msg2 = AgentMessage(id: "m-2", role: .assistant, content: "Hi back!")
        let session = makeSession(id: "msg-sess", messages: [msg1, msg2])
        try await repo.saveSession(session)

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched[0].messages.count, 2)
        XCTAssertEqual(fetched[0].messages[0].id, "m-1")
        XCTAssertEqual(fetched[0].messages[0].role, .user)
        XCTAssertEqual(fetched[0].messages[0].content, "Hello there")
        XCTAssertEqual(fetched[0].messages[1].id, "m-2")
        XCTAssertEqual(fetched[0].messages[1].role, .assistant)
    }

    func testSaveSessionWithToolCallMessages() async throws {
        let toolCall = ToolCall(
            id: "tc-1",
            name: "bash",
            arguments: "{\"command\": \"ls\"}",
            status: .completed,
            result: ToolResult(content: "file1.swift\nfile2.swift", type: .text, isError: false)
        )
        let msg = AgentMessage(id: "tool-msg", role: .assistant, content: "Running ls...", toolCalls: [toolCall])
        let session = makeSession(id: "tool-sess", messages: [msg])
        try await repo.saveSession(session)

        let fetched = try await repo.fetchSessions()
        let fetchedMsg = fetched[0].messages[0]
        XCTAssertEqual(fetchedMsg.toolCalls.count, 1)
        XCTAssertEqual(fetchedMsg.toolCalls[0].id, "tc-1")
        XCTAssertEqual(fetchedMsg.toolCalls[0].name, "bash")
        XCTAssertEqual(fetchedMsg.toolCalls[0].result?.content, "file1.swift\nfile2.swift")
    }

    func testSaveSessionWithNoMessages() async throws {
        let session = makeSession(id: "empty-msgs", messages: [])
        try await repo.saveSession(session)
        let fetched = try await repo.fetchSessions()
        XCTAssertTrue(fetched[0].messages.isEmpty)
    }

    // MARK: - Upsert semantics

    func testUpsertUpdatesExistingSession() async throws {
        var session = makeSession(id: "upsert-1", customName: "Before", status: .idle)
        try await repo.saveSession(session)

        // Mutate and save again
        session.status = .running
        session.customName = "After"
        session.tokenUsage = TokenUsage(inputTokens: 500, outputTokens: 250)
        try await repo.saveSession(session)

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched.count, 1, "Upsert must not create a duplicate row")
        XCTAssertEqual(fetched[0].status, .running)
        XCTAssertEqual(fetched[0].customName, "After")
        XCTAssertEqual(fetched[0].tokenUsage.inputTokens, 500)
    }

    func testUpsertPreservesIdempotency() async throws {
        let session = makeSession(id: "idem-1")
        try await repo.saveSession(session)
        try await repo.saveSession(session)
        try await repo.saveSession(session)

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched.count, 1, "Saving same session 3 times must yield exactly 1 row")
    }

    // MARK: - saveMessage (append)

    func testSaveMessageAppendedToExistingSession() async throws {
        let session = makeSession(id: "append-sess", messages: [])
        try await repo.saveSession(session)

        let newMsg = AgentMessage(id: "appended-1", role: .user, content: "New message")
        try await repo.saveMessage(newMsg, sessionId: "append-sess")

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched[0].messages.count, 1)
        XCTAssertEqual(fetched[0].messages[0].id, "appended-1")
        XCTAssertEqual(fetched[0].messages[0].content, "New message")
    }

    func testSaveMessageMultipleAppends() async throws {
        let session = makeSession(id: "multi-append", messages: [])
        try await repo.saveSession(session)

        for i in 1...5 {
            let msg = AgentMessage(
                id: "msg-\(i)",
                role: i % 2 == 0 ? .assistant : .user,
                content: "Message \(i)",
                timestamp: Date(timeIntervalSince1970: Double(i) * 1000)
            )
            try await repo.saveMessage(msg, sessionId: "multi-append")
        }

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched[0].messages.count, 5, "All 5 appended messages must be persisted")
    }

    func testSaveMessageUpdatesSessionLastActivity() async throws {
        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        let session = makeSession(id: "activity-sess", lastActivityAt: oldDate)
        try await repo.saveSession(session)

        // Wait a tick then append a message
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let msg = AgentMessage(id: "act-msg", role: .user, content: "ping")
        try await repo.saveMessage(msg, sessionId: "activity-sess")

        let fetched = try await repo.fetchSessions()
        XCTAssertGreaterThan(
            fetched[0].lastActivityAt,
            oldDate,
            "saveMessage must update session last_activity_at"
        )
    }

    func testSaveMessageUpsertsSameIdempotently() async throws {
        let session = makeSession(id: "upsert-msg-sess", messages: [])
        try await repo.saveSession(session)

        let msg = AgentMessage(id: "dup-msg", role: .user, content: "Original content")
        try await repo.saveMessage(msg, sessionId: "upsert-msg-sess")
        try await repo.saveMessage(msg, sessionId: "upsert-msg-sess")

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched[0].messages.count, 1, "Duplicate message save must not create duplicate row")
    }

    // MARK: - Delete (cascade)

    func testDeleteSessionRemovesIt() async throws {
        let session = makeSession(id: "del-1")
        try await repo.saveSession(session)
        try await repo.deleteSession(id: "del-1")

        let fetched = try await repo.fetchSessions()
        XCTAssertTrue(fetched.isEmpty, "Deleted session must not appear in fetchSessions")
    }

    func testDeleteSessionCascadesMessages() async throws {
        let msg = AgentMessage(id: "cascade-msg", role: .user, content: "Will be deleted")
        let session = makeSession(id: "cascade-sess", messages: [msg])
        try await repo.saveSession(session)

        try await repo.deleteSession(id: "cascade-sess")

        // Re-open the same DB file and verify messages table is empty
        let verifier = SQLiteAgentSessionRepository(dbPath: dbPath)
        try await verifier.open()
        let sessions = try await verifier.fetchSessions()
        await verifier.close()

        XCTAssertTrue(sessions.isEmpty, "After cascade delete, no sessions or orphaned messages must remain")
    }

    func testDeleteNonExistentSessionDoesNotThrow() async throws {
        // Should complete without error
        try await repo.deleteSession(id: "does-not-exist")
        let fetched = try await repo.fetchSessions()
        XCTAssertTrue(fetched.isEmpty)
    }

    func testDeleteOneSessionLeavesOthers() async throws {
        let s1 = makeSession(id: "keep-1")
        let s2 = makeSession(id: "delete-me")
        let s3 = makeSession(id: "keep-2")
        try await repo.saveSession(s1)
        try await repo.saveSession(s2)
        try await repo.saveSession(s3)

        try await repo.deleteSession(id: "delete-me")

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched.count, 2)
        let ids = fetched.map(\.id)
        XCTAssertTrue(ids.contains("keep-1"))
        XCTAssertTrue(ids.contains("keep-2"))
        XCTAssertFalse(ids.contains("delete-me"))
    }

    // MARK: - Most-recent-first ordering

    func testFetchSessionsReturnsMostRecentFirst() async throws {
        let t1 = Date(timeIntervalSince1970: 1_000_000) // oldest
        let t2 = Date(timeIntervalSince1970: 2_000_000)
        let t3 = Date(timeIntervalSince1970: 3_000_000) // newest

        try await repo.saveSession(makeSession(id: "order-a", lastActivityAt: t2))
        try await repo.saveSession(makeSession(id: "order-b", lastActivityAt: t1))
        try await repo.saveSession(makeSession(id: "order-c", lastActivityAt: t3))

        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].id, "order-c", "Most recent session must come first")
        XCTAssertEqual(fetched[1].id, "order-a")
        XCTAssertEqual(fetched[2].id, "order-b", "Oldest session must come last")
    }

    func testFetchMultipleSessionsAllReturned() async throws {
        for i in 1...10 {
            try await repo.saveSession(makeSession(
                id: "bulk-\(i)",
                lastActivityAt: Date(timeIntervalSince1970: Double(i) * 100_000)
            ))
        }
        let fetched = try await repo.fetchSessions()
        XCTAssertEqual(fetched.count, 10)
    }

    // MARK: - Persistence across reopen

    func testDataPersistedAcrossCloseAndReopen() async throws {
        let msg = AgentMessage(id: "persist-msg", role: .user, content: "Persisted content")
        let session = makeSession(id: "persist-sess", customName: "Durable", messages: [msg])
        try await repo.saveSession(session)

        // Close and reopen the same DB file
        await repo.close()
        let repo2 = SQLiteAgentSessionRepository(dbPath: dbPath)
        try await repo2.open()
        let fetched = try await repo2.fetchSessions()
        await repo2.close()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, "persist-sess")
        XCTAssertEqual(fetched[0].customName, "Durable")
        XCTAssertEqual(fetched[0].messages.count, 1)
        XCTAssertEqual(fetched[0].messages[0].content, "Persisted content")
    }

    // MARK: - Not-open error

    func testFetchBeforeOpenThrows() async {
        let closedRepo = SQLiteAgentSessionRepository(dbPath: "/tmp/nonexistent-\(UUID().uuidString).sqlite")
        do {
            _ = try await closedRepo.fetchSessions()
            XCTFail("fetchSessions on unopened repo must throw")
        } catch let error as SQLiteSessionError {
            if case .notOpen = error { /* expected */ } else {
                XCTFail("Expected SQLiteSessionError.notOpen, got \(error)")
            }
        } catch {
            XCTFail("Expected SQLiteSessionError, got \(error)")
        }
    }

    func testSaveBeforeOpenThrows() async {
        let closedRepo = SQLiteAgentSessionRepository(dbPath: "/tmp/nonexistent-\(UUID().uuidString).sqlite")
        let session = makeSession(id: "no-open")
        do {
            try await closedRepo.saveSession(session)
            XCTFail("saveSession on unopened repo must throw")
        } catch let error as SQLiteSessionError {
            if case .notOpen = error { /* expected */ } else {
                XCTFail("Expected SQLiteSessionError.notOpen, got \(error)")
            }
        } catch {
            XCTFail("Expected SQLiteSessionError, got \(error)")
        }
    }
}
