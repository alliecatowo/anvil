import XCTest
@testable import AnvilApplication
import AnvilDomain

// MARK: - Mock SourceControlCloudPort

private final class MockCloudPort: SourceControlCloudPort, @unchecked Sendable {
    var providerId: String = "mock-cloud"
    var providerName: String = "Mock Cloud"

    func validateConnection() async throws -> Bool { true }

    // Capture the last createPullRequest call
    var lastCreateCall: (repo: String, title: String, body: String, source: String, target: String, isDraft: Bool)?
    var pullRequestToReturn: PullRequest?
    var shouldThrow: Bool = false

    func repositories() async throws -> [RemoteRepo] { [] }
    func pullRequests(repo: String, status: PRStatus?) async throws -> [PullRequest] { [] }
    func pullRequestDetail(repo: String, number: Int) async throws -> PullRequest {
        PullRequest(id: "1", number: 1, title: "", sourceBranch: "", targetBranch: "", author: "")
    }

    func createPullRequest(
        repo: String,
        title: String,
        body: String,
        source: String,
        target: String,
        isDraft: Bool
    ) async throws -> PullRequest {
        lastCreateCall = (repo, title, body, source, target, isDraft)
        if shouldThrow { throw URLError(.badServerResponse) }
        return pullRequestToReturn ?? PullRequest(
            id: UUID().uuidString,
            number: 42,
            title: title,
            body: body,
            sourceBranch: source,
            targetBranch: target,
            author: "agent",
            isDraft: isDraft
        )
    }

    func mergePullRequest(repo: String, number: Int, strategy: MergeStrategy) async throws {}
    func closePullRequest(repo: String, number: Int) async throws {}
    func pullRequestComments(repo: String, number: Int) async throws -> [PRComment] { [] }
    func addComment(repo: String, prNumber: Int, body: String, file: String?, line: Int?) async throws -> PRComment {
        PRComment(id: "1", author: "test", body: body)
    }
    func replyToComment(repo: String, prNumber: Int, commentId: String, body: String) async throws -> PRComment {
        PRComment(id: "2", author: "test", body: body)
    }
    func resolveReviewThread(repo: String, threadId: String) async throws {}
    func ciStatus(repo: String, prNumber: Int) async throws -> [CICheck] { [] }
    func push(remote: String, branch: String, force: Bool) async throws {}
    func pull(remote: String, branch: String) async throws {}
    func fetch(remote: String) async throws {}
}

// MARK: - CreateDraftPRUseCaseTests

final class CreateDraftPRUseCaseTests: XCTestCase {

    private var eventBus: EventBus!
    private var useCase: CreateDraftPRUseCase!
    private var cloudPort: MockCloudPort!

    override func setUp() {
        super.setUp()
        eventBus = EventBus()
        useCase = CreateDraftPRUseCase(eventBus: eventBus)
        cloudPort = MockCloudPort()
    }

    override func tearDown() {
        eventBus = nil
        useCase = nil
        cloudPort = nil
        super.tearDown()
    }

    // MARK: - PR Creation

    func testExecuteReturnsPRWithCorrectNumber() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        cloudPort.pullRequestToReturn = PullRequest(
            id: "pr-1", number: 99, title: "Test", sourceBranch: "feature", targetBranch: "main", author: "agent"
        )

        let result = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feature", cloudPort: cloudPort
        )

        XCTAssertEqual(result.prNumber, 99)
    }

    func testExecuteBuildsCorrectURL() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        cloudPort.pullRequestToReturn = PullRequest(
            id: "pr-1", number: 7, title: "T", sourceBranch: "feat", targetBranch: "main", author: "a"
        )

        let result = try await useCase.execute(
            session: session, repo: "acme/anvil", sourceBranch: "feat", cloudPort: cloudPort
        )

        XCTAssertEqual(result.url, "https://github.com/acme/anvil/pull/7")
    }

    func testExecutePassesDraftFlagTrue() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "branch", cloudPort: cloudPort
        )

        XCTAssertTrue(cloudPort.lastCreateCall?.isDraft == true)
    }

    func testExecuteUsesDefaultTargetBranchMain() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.target, "main")
    }

    func testExecuteUsesCustomTargetBranch() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", targetBranch: "develop", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.target, "develop")
    }

    func testExecuteForwardsSourceBranch() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "agent/session-42", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.source, "agent/session-42")
    }

    func testExecuteForwardsRepo() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "myorg/myrepo", sourceBranch: "feat", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.repo, "myorg/myrepo")
    }

    // MARK: - PR Title Building

    func testPRTitleUsesCustomSessionName() async throws {
        let session = AgentSession(
            id: "s1", providerId: "test", model: "claude",
            customName: "Fix login bug"
        )
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.title, "Fix login bug")
    }

    func testPRTitleUsesWorkItemId() async throws {
        let session = AgentSession(
            id: "s1", providerId: "test", model: "claude",
            workItemId: "TICKET-123"
        )
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.title, "TICKET-123")
    }

    func testPRTitleFallsBackToFirstUserMessagePreview() async throws {
        let msg = AgentMessage(role: .user, content: "Implement the new feature")
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.title, "Implement the new feature")
    }

    func testPRTitleFallsBackToSessionWhenNoMessages() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.title, "Session")
    }

    func testPRTitleTruncatesLongCustomNameAt72Chars() async throws {
        let longName = String(repeating: "a", count: 80)
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", customName: longName)
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let title = cloudPort.lastCreateCall?.title ?? ""
        XCTAssertEqual(title.count, 72)
        XCTAssertTrue(title.hasSuffix("..."))
    }

    func testPRTitleNotTruncatedWhenExactly72Chars() async throws {
        let name = String(repeating: "b", count: 72)
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", customName: name)
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        XCTAssertEqual(cloudPort.lastCreateCall?.title, name)
    }

    // MARK: - PR Body Building

    func testPRBodyContainsSummarySection() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let body = cloudPort.lastCreateCall?.body ?? ""
        XCTAssertTrue(body.contains("## Summary"))
    }

    func testPRBodyContainsSessionId() async throws {
        let session = AgentSession(id: "session-xyz", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let body = cloudPort.lastCreateCall?.body ?? ""
        XCTAssertTrue(body.contains("session-xyz"))
    }

    func testPRBodyIncludesWorkItemWhenPresent() async throws {
        let session = AgentSession(
            id: "s1", providerId: "test", model: "claude", workItemId: "PROJ-99"
        )
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let body = cloudPort.lastCreateCall?.body ?? ""
        XCTAssertTrue(body.contains("PROJ-99"))
    }

    func testPRBodyOmitsWorkItemSectionWhenNil() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let body = cloudPort.lastCreateCall?.body ?? ""
        XCTAssertFalse(body.contains("**Work item:**"))
    }

    func testPRBodyIncludesContextSectionForUserMessages() async throws {
        let msg = AgentMessage(role: .user, content: "Please add dark mode support")
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let body = cloudPort.lastCreateCall?.body ?? ""
        XCTAssertTrue(body.contains("## Context"))
        XCTAssertTrue(body.contains("Please add dark mode support"))
    }

    func testPRBodyIncludesToolsUsedSection() async throws {
        let tool = ToolCall(name: "write_file", arguments: "{\"path\":\"/tmp/x.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "Done", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let body = cloudPort.lastCreateCall?.body ?? ""
        XCTAssertTrue(body.contains("## Tools Used"))
        XCTAssertTrue(body.contains("`write_file`"))
    }

    func testPRBodyToolsListIsSorted() async throws {
        let t1 = ToolCall(name: "write_file", arguments: "{}")
        let t2 = ToolCall(name: "bash_exec", arguments: "{}")
        let msg = AgentMessage(role: .assistant, content: "Done", toolCalls: [t1, t2])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let body = cloudPort.lastCreateCall?.body ?? ""
        let bashIndex = body.range(of: "bash_exec")?.lowerBound
        let writeIndex = body.range(of: "write_file")?.lowerBound
        XCTAssertNotNil(bashIndex)
        XCTAssertNotNil(writeIndex)
        if let b = bashIndex, let w = writeIndex {
            XCTAssertLessThan(b, w, "bash_exec should appear before write_file (sorted)")
        }
    }

    func testPRBodyEndsWithAnvilFooter() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        let body = cloudPort.lastCreateCall?.body ?? ""
        XCTAssertTrue(body.contains("Anvil agent session"))
    }

    // MARK: - Event Bus

    func testExecutePublishesDraftPRCreatedEvent() async throws {
        let session = AgentSession(id: "my-session", providerId: "test", model: "claude")
        cloudPort.pullRequestToReturn = PullRequest(
            id: "pr-1", number: 5, title: "T", sourceBranch: "feat", targetBranch: "main", author: "a"
        )

        let received = expectation(description: "event received")
        received.assertForOverFulfill = false

        await eventBus.subscribe(to: "sourceControl") { event in
            if let action = event.payload["action"], action == "draftPRCreated" {
                received.fulfill()
            }
        }

        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        await fulfillment(of: [received], timeout: 2.0)
    }

    func testExecutePublishesEventWithCorrectSessionId() async throws {
        let session = AgentSession(id: "event-test-session", providerId: "test", model: "claude")
        cloudPort.pullRequestToReturn = PullRequest(
            id: "pr-1", number: 3, title: "T", sourceBranch: "feat", targetBranch: "main", author: "a"
        )

        var capturedSessionId: String?
        let received = expectation(description: "event received")
        received.assertForOverFulfill = false

        await eventBus.subscribe(to: "sourceControl") { event in
            if event.payload["action"] == "draftPRCreated" {
                capturedSessionId = event.payload["sessionId"]
                received.fulfill()
            }
        }

        _ = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )

        await fulfillment(of: [received], timeout: 2.0)
        XCTAssertEqual(capturedSessionId, "event-test-session")
    }

    func testExecuteThrowsWhenCloudPortThrows() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        cloudPort.shouldThrow = true

        do {
            _ = try await useCase.execute(
                session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
            )
            XCTFail("Expected throw")
        } catch {
            // Expected
        }
    }

    // MARK: - Result fields

    func testResultTitleMatchesBuiltTitle() async throws {
        let session = AgentSession(
            id: "s1", providerId: "test", model: "claude", customName: "My PR"
        )
        let result = try await useCase.execute(
            session: session, repo: "owner/repo", sourceBranch: "feat", cloudPort: cloudPort
        )
        XCTAssertEqual(result.title, "My PR")
    }
}
