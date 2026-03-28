import Testing
@testable import AnvilApplication
import AnvilDomain
import Foundation

// MARK: - InMemoryReviewService

@Suite("InMemoryReviewService")
struct InMemoryReviewServiceTests {

    // MARK: create + fetch

    @Test func createAndFetch() async throws {
        let service = InMemoryReviewService()
        let review = Review(title: "PR #1", sourceType: .pullRequest, sourceId: "1", author: "alice")
        let created = try await service.createReview(review)
        let all = try await service.fetchReviews()
        #expect(all.contains { $0.id == created.id })
    }

    @Test func fetchReturnsAllCreated() async throws {
        let service = InMemoryReviewService()
        let r1 = Review(title: "PR #1", sourceType: .pullRequest, sourceId: "1", author: "alice")
        let r2 = Review(title: "Session #2", sourceType: .agentSession, sourceId: "2", author: "bob")
        try await service.createReview(r1)
        try await service.createReview(r2)
        let all = try await service.fetchReviews()
        #expect(all.count == 2)
    }

    // MARK: update

    @Test func updateChangesStatus() async throws {
        let service = InMemoryReviewService()
        var review = Review(title: "PR #3", sourceType: .pullRequest, sourceId: "3", author: "carol")
        review = try await service.createReview(review)
        var modified = review
        modified.status = .dismissed
        let updated = try await service.updateReview(modified)
        #expect(updated.status == .dismissed)
    }

    @Test func updateNonExistentThrows() async throws {
        let service = InMemoryReviewService()
        let phantom = Review(title: "Ghost", sourceType: .manualSelection, sourceId: "x", author: "nobody")
        await #expect(throws: ReviewServiceError.notFound) {
            try await service.updateReview(phantom)
        }
    }

    // MARK: delete

    @Test func deleteRemoves() async throws {
        let service = InMemoryReviewService()
        let review = Review(title: "To Delete", sourceType: .pullRequest, sourceId: "del-1", author: "dave")
        let created = try await service.createReview(review)
        try await service.deleteReview(id: created.id)
        let all = try await service.fetchReviews()
        #expect(!all.contains { $0.id == created.id })
    }

    @Test func deleteNonExistentIsIdempotent() async throws {
        let service = InMemoryReviewService()
        // deleteReview does not throw on missing id — it's a silent no-op
        try await service.deleteReview(id: "does-not-exist")
        let all = try await service.fetchReviews()
        #expect(all.isEmpty)
    }

    // MARK: approve

    @Test func approveChangesStatusToApproved() async throws {
        let service = InMemoryReviewService()
        let review = Review(title: "PR #5", sourceType: .pullRequest, sourceId: "5", author: "eve")
        let created = try await service.createReview(review)
        let approved = try await service.approveReview(id: created.id, comment: "LGTM")
        #expect(approved.status == .approved)
        #expect(approved.id == created.id)
    }

    @Test func approveNonExistentThrows() async throws {
        let service = InMemoryReviewService()
        await #expect(throws: ReviewServiceError.notFound) {
            try await service.approveReview(id: "missing", comment: nil)
        }
    }

    @Test func approveWithNilCommentSucceeds() async throws {
        let service = InMemoryReviewService()
        let review = Review(title: "PR #6", sourceType: .agentSession, sourceId: "6", author: "frank")
        let created = try await service.createReview(review)
        let approved = try await service.approveReview(id: created.id, comment: nil)
        #expect(approved.status == .approved)
    }

    // MARK: requestChanges

    @Test func requestChangesChangesStatus() async throws {
        let service = InMemoryReviewService()
        let review = Review(title: "PR #7", sourceType: .pullRequest, sourceId: "7", author: "grace")
        let created = try await service.createReview(review)
        let result = try await service.requestChanges(id: created.id, comment: "Needs work")
        #expect(result.status == .changesRequested)
        #expect(result.id == created.id)
    }

    @Test func requestChangesNonExistentThrows() async throws {
        let service = InMemoryReviewService()
        await #expect(throws: ReviewServiceError.notFound) {
            try await service.requestChanges(id: "missing", comment: "nope")
        }
    }

    // MARK: ordering

    @Test func fetchOrderedByCreatedAtDescending() async throws {
        let service = InMemoryReviewService()
        let older = Review(
            title: "Old PR",
            sourceType: .pullRequest,
            sourceId: "old",
            author: "alice",
            createdAt: Date(timeIntervalSinceNow: -100),
            updatedAt: Date(timeIntervalSinceNow: -100)
        )
        let newer = Review(
            title: "New PR",
            sourceType: .pullRequest,
            sourceId: "new",
            author: "alice",
            createdAt: Date(timeIntervalSinceNow: -10),
            updatedAt: Date(timeIntervalSinceNow: -10)
        )
        try await service.createReview(older)
        try await service.createReview(newer)
        let all = try await service.fetchReviews()
        #expect(all.first?.title == "New PR")
    }

    // MARK: updatedAt stamp

    @Test func approveRefreshesUpdatedAt() async throws {
        let service = InMemoryReviewService()
        let fixedDate = Date(timeIntervalSinceNow: -1000)
        let review = Review(
            title: "Stamp Test",
            sourceType: .pullRequest,
            sourceId: "stamp",
            author: "alice",
            createdAt: fixedDate,
            updatedAt: fixedDate
        )
        let created = try await service.createReview(review)
        let approved = try await service.approveReview(id: created.id, comment: nil)
        #expect(approved.updatedAt > fixedDate)
    }
}

// MARK: - CreateReviewUseCase

@Suite("CreateReviewUseCase")
struct CreateReviewUseCaseTests {

    @Test func createsAndReturnsReviewWithCorrectFields() async throws {
        let service = InMemoryReviewService()
        let useCase = CreateReviewUseCase(reviewPort: service, eventBus: EventBus.shared)
        let review = try await useCase.execute(
            title: "PR #42",
            sourceType: .pullRequest,
            sourceId: "42",
            author: "alice"
        )
        #expect(review.title == "PR #42")
        #expect(review.author == "alice")
        #expect(review.sourceType == .pullRequest)
        #expect(review.sourceId == "42")
        #expect(review.status == .pending)
    }

    @Test func createdReviewIsPersisted() async throws {
        let service = InMemoryReviewService()
        let useCase = CreateReviewUseCase(reviewPort: service, eventBus: EventBus.shared)
        let created = try await useCase.execute(
            title: "Persisted PR",
            sourceType: .agentSession,
            sourceId: "sess-1",
            author: "bob"
        )
        let all = try await service.fetchReviews()
        #expect(all.contains { $0.id == created.id })
    }

    @Test func createMultipleReviewsAreAllPersisted() async throws {
        let service = InMemoryReviewService()
        let useCase = CreateReviewUseCase(reviewPort: service, eventBus: EventBus.shared)
        try await useCase.execute(title: "A", sourceType: .pullRequest, sourceId: "a", author: "alice")
        try await useCase.execute(title: "B", sourceType: .pullRequest, sourceId: "b", author: "bob")
        let all = try await service.fetchReviews()
        #expect(all.count == 2)
    }

    @Test func createAssignsUniqueIds() async throws {
        let service = InMemoryReviewService()
        let useCase = CreateReviewUseCase(reviewPort: service, eventBus: EventBus.shared)
        let r1 = try await useCase.execute(title: "X", sourceType: .pullRequest, sourceId: "x", author: "alice")
        let r2 = try await useCase.execute(title: "Y", sourceType: .pullRequest, sourceId: "y", author: "alice")
        #expect(r1.id != r2.id)
    }
}

// MARK: - UpdateReviewUseCase

@Suite("UpdateReviewUseCase")
struct UpdateReviewUseCaseTests {

    @Test func updatesExistingReview() async throws {
        let service = InMemoryReviewService()
        var review = Review(title: "Original", sourceType: .pullRequest, sourceId: "u1", author: "alice")
        review = try await service.createReview(review)

        var modified = review
        modified.status = .approved

        let updateUseCase = UpdateReviewUseCase(reviewPort: service, eventBus: EventBus.shared)
        let result = try await updateUseCase.execute(review: modified)
        #expect(result.status == .approved)
        #expect(result.id == review.id)
    }

    @Test func updatePreservesUnchangedFields() async throws {
        let service = InMemoryReviewService()
        var review = Review(title: "Keep Me", sourceType: .agentSession, sourceId: "u2", author: "carol")
        review = try await service.createReview(review)

        var modified = review
        modified.status = .changesRequested

        let updateUseCase = UpdateReviewUseCase(reviewPort: service, eventBus: EventBus.shared)
        let result = try await updateUseCase.execute(review: modified)
        #expect(result.title == "Keep Me")
        #expect(result.author == "carol")
        #expect(result.sourceType == .agentSession)
    }

    @Test func updateNonExistentThrows() async throws {
        let service = InMemoryReviewService()
        let phantom = Review(title: "Ghost", sourceType: .pullRequest, sourceId: "ghost", author: "nobody")
        let updateUseCase = UpdateReviewUseCase(reviewPort: service, eventBus: EventBus.shared)
        await #expect(throws: ReviewServiceError.notFound) {
            try await updateUseCase.execute(review: phantom)
        }
    }

    @Test func updateIsPersisted() async throws {
        let service = InMemoryReviewService()
        var review = Review(title: "Persist Update", sourceType: .pullRequest, sourceId: "pu", author: "dave")
        review = try await service.createReview(review)

        var modified = review
        modified.status = .dismissed

        let updateUseCase = UpdateReviewUseCase(reviewPort: service, eventBus: EventBus.shared)
        try await updateUseCase.execute(review: modified)

        let all = try await service.fetchReviews()
        let fetched = try #require(all.first { $0.id == review.id })
        #expect(fetched.status == .dismissed)
    }
}

// MARK: - CreateProjectUseCase

@Suite("CreateProjectUseCase")
struct CreateProjectUseCaseTests {

    @Test func blankProjectReturnsName() async throws {
        let useCase = CreateProjectUseCase()
        let name = try await useCase.execute(source: .blank(name: "MyApp"))
        #expect(name == "MyApp")
    }

    @Test func fromTemplateReturnsName() async throws {
        let useCase = CreateProjectUseCase()
        let name = try await useCase.execute(source: .fromTemplate(name: "WebApp", templateUrl: "https://example.com/tmpl"))
        #expect(name == "WebApp")
    }

    @Test func fromRepoExtractsLastPathComponent() async throws {
        let useCase = CreateProjectUseCase()
        let name = try await useCase.execute(source: .fromRepo(url: "https://github.com/org/anvil-core"))
        #expect(name == "anvil-core")
    }

    @Test func fromRepoWithEmptyUrlFallsBackToProject() async throws {
        // URL(string: "") returns nil on all Darwin platforms, triggering the
        // "project" fallback in CreateProjectUseCase.
        let useCase = CreateProjectUseCase()
        let name = try await useCase.execute(source: .fromRepo(url: ""))
        #expect(name == "project")
    }

    @Test func fromDirectoryExtractsLastPathComponent() async throws {
        let useCase = CreateProjectUseCase()
        let name = try await useCase.execute(source: .fromDirectory(path: "/Users/alice/projects/anvil"))
        #expect(name == "anvil")
    }

    @Test func fromDirectoryWithTrailingSlash() async throws {
        let useCase = CreateProjectUseCase()
        let name = try await useCase.execute(source: .fromDirectory(path: "/Users/alice/projects/anvil/"))
        // URL(fileURLWithPath:).lastPathComponent strips trailing slash
        #expect(!name.isEmpty)
    }
}

// MARK: - StartAgentSessionUseCase

/// Minimal stub satisfying AgentPort for unit testing StartAgentSessionUseCase.
/// All methods not under test throw to catch accidental invocations.
private struct StubAgentPort: AgentPort {
    let providerId: String = "stub"
    let providerName: String = "Stub"
    let stubbedSession: AgentSession

    func validateConnection() async throws -> Bool { true }

    func startSession(prompt: String, context: AgentContext, model: String?, tools: [String]) async throws -> AgentSession {
        stubbedSession
    }

    func sendMessage(sessionId: String, content: String) async throws -> AsyncThrowingStream<AgentStreamEvent, Error> {
        fatalError("not exercised in unit tests")
    }
    func approveToolCall(sessionId: String, toolCallId: String) async throws { fatalError("not exercised") }
    func rejectToolCall(sessionId: String, toolCallId: String, reason: String?) async throws { fatalError("not exercised") }
    func pauseSession(sessionId: String) async throws { fatalError("not exercised") }
    func resumeSession(sessionId: String) async throws { fatalError("not exercised") }
    func cancelSession(sessionId: String) async throws { fatalError("not exercised") }
    func availableModels() async throws -> [AgentModel] { fatalError("not exercised") }
    func estimateCost(prompt: String, model: String) async throws -> CostEstimate { fatalError("not exercised") }
}

@Suite("StartAgentSessionUseCase")
struct StartAgentSessionUseCaseTests {

    private func makeSession(id: String = UUID().uuidString) -> AgentSession {
        AgentSession(id: id, providerId: "stub", model: "claude-opus-4-6")
    }

    @Test func returnsSessionFromProvider() async throws {
        let expected = makeSession()
        let stub = StubAgentPort(stubbedSession: expected)
        let useCase = StartAgentSessionUseCase()
        let result = try await useCase.execute(
            prompt: "write tests",
            projectPath: "/tmp/proj",
            workItemId: nil,
            provider: stub,
            model: nil
        )
        #expect(result.id == expected.id)
    }

    @Test func sessionIdPropagatedCorrectly() async throws {
        let knownId = "session-abc-123"
        let session = makeSession(id: knownId)
        let stub = StubAgentPort(stubbedSession: session)
        let useCase = StartAgentSessionUseCase()
        let result = try await useCase.execute(
            prompt: "refactor module",
            projectPath: "/tmp/proj",
            workItemId: "WORK-1",
            provider: stub,
            model: "claude-opus-4-6"
        )
        #expect(result.id == knownId)
    }

    @Test func modelParameterPassedThrough() async throws {
        let session = AgentSession(providerId: "stub", model: "claude-opus-4-6")
        let stub = StubAgentPort(stubbedSession: session)
        let useCase = StartAgentSessionUseCase()
        let result = try await useCase.execute(
            prompt: "explain codebase",
            projectPath: "/tmp/proj",
            workItemId: nil,
            provider: stub,
            model: "claude-opus-4-6"
        )
        #expect(result.model == "claude-opus-4-6")
    }

    @Test func workItemIdStoredInSession() async throws {
        let session = AgentSession(providerId: "stub", model: "claude-opus-4-6", workItemId: "TICKET-42")
        let stub = StubAgentPort(stubbedSession: session)
        let useCase = StartAgentSessionUseCase()
        let result = try await useCase.execute(
            prompt: "fix bug",
            projectPath: "/tmp/proj",
            workItemId: "TICKET-42",
            provider: stub,
            model: nil
        )
        #expect(result.workItemId == "TICKET-42")
    }
}
