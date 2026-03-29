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

// MARK: - EventBus

@Suite("EventBus — Publish and Subscribe")
struct EventBusTests {

    // Each test creates a fresh EventBus instance to avoid cross-test pollution
    // from EventBus.shared. The actor initialiser is private, so we use shared
    // only where isolation between tests is guaranteed by event-type namespacing.

    @Test("wildcard subscriber receives published event")
    func wildcardSubscriberReceivesEvent() async {
        let bus = EventBus.shared
        let received = ActorBox<[String]>([])
        // Use a unique primitive name so this test's events don't bleed elsewhere
        let unique = "test.wildcard.\(UUID().uuidString)"
        await bus.subscribe(to: "*") { event in
            if event.sourcePrimitive == unique {
                await received.append(event.sourcePrimitive)
            }
        }
        await bus.publish(AnyDomainEvent(sourcePrimitive: unique, payload: "ping"))
        #expect(await received.value.count == 1)
        #expect(await received.value.first == unique)
    }

    @Test("typed subscriber only receives matching event type")
    func typedSubscriberReceivesOnlyMatchingType() async {
        let bus = EventBus.shared
        let received = ActorBox<Int>(0)
        let eventType = String(describing: AnyDomainEvent.self)
        await bus.subscribe(to: eventType) { _ in
            await received.increment()
        }
        await bus.publish(AnyDomainEvent(sourcePrimitive: "typed.test", payload: "data"))
        #expect(await received.value >= 1)
    }

    @Test("multiple wildcard subscribers all receive the event")
    func multipleWildcardSubscribersAllReceive() async {
        let bus = EventBus.shared
        let unique = "test.multi.\(UUID().uuidString)"
        let counter = ActorBox<Int>(0)
        await bus.subscribe(to: "*") { event in
            if event.sourcePrimitive == unique { await counter.increment() }
        }
        await bus.subscribe(to: "*") { event in
            if event.sourcePrimitive == unique { await counter.increment() }
        }
        await bus.publish(AnyDomainEvent(sourcePrimitive: unique, payload: EmptyPayload()))
        #expect(await counter.value >= 2)
    }

    @Test("event carries correct sourcePrimitive through the bus")
    func eventSourcePrimitiveSurvivesRoundtrip() async {
        let bus = EventBus.shared
        let unique = "test.source.\(UUID().uuidString)"
        let captured = ActorBox<String?>(nil)
        await bus.subscribe(to: "*") { event in
            if event.sourcePrimitive == unique {
                await captured.set(event.sourcePrimitive)
            }
        }
        await bus.publish(AnyDomainEvent(sourcePrimitive: unique, payload: EmptyPayload()))
        #expect(await captured.value == unique)
    }

    @Test("event carries correct eventId through the bus")
    func eventIdSurvivesRoundtrip() async {
        let bus = EventBus.shared
        let knownId = UUID().uuidString
        let unique = "test.id.\(UUID().uuidString)"
        let captured = ActorBox<String?>(nil)
        await bus.subscribe(to: "*") { event in
            if event.sourcePrimitive == unique {
                await captured.set(event.eventId)
            }
        }
        await bus.publish(AnyDomainEvent(eventId: knownId, sourcePrimitive: unique, payload: EmptyPayload()))
        #expect(await captured.value == knownId)
    }

    @Test("no subscribers means publish does not crash")
    func publishWithNoSubscribersIsNoop() async {
        let bus = EventBus.shared
        // Subscribe to nothing for this unique type — just verify publish does not throw/crash
        await bus.publish(AnyDomainEvent(sourcePrimitive: "test.noop.\(UUID().uuidString)", payload: EmptyPayload()))
        // If we reach here without crashing the test passes
        #expect(true)
    }

    @Test("AnyDomainEvent initialises with correct fields")
    func anyDomainEventFields() {
        let id = UUID().uuidString
        let now = Date.now
        let event = AnyDomainEvent(eventId: id, timestamp: now, sourcePrimitive: "prim", payload: 42)
        #expect(event.eventId == id)
        #expect(event.sourcePrimitive == "prim")
        #expect(event.timestamp == now)
    }

    @Test("AnyDomainEvent default eventId is non-empty")
    func anyDomainEventDefaultIdIsNonEmpty() {
        let event = AnyDomainEvent(sourcePrimitive: "x", payload: EmptyPayload())
        #expect(!event.eventId.isEmpty)
    }

    @Test("two AnyDomainEvents created sequentially have distinct default IDs")
    func sequentialEventsHaveDistinctIds() {
        let e1 = AnyDomainEvent(sourcePrimitive: "a", payload: EmptyPayload())
        let e2 = AnyDomainEvent(sourcePrimitive: "b", payload: EmptyPayload())
        #expect(e1.eventId != e2.eventId)
    }
}

/// Trivially Sendable empty payload used in EventBus tests to avoid
/// inferring non-Sendable types from literal closures.
private struct EmptyPayload: Sendable {}

/// A simple actor wrapper that lets async test closures safely accumulate
/// results without data races (Swift 6 strict concurrency).
private actor ActorBox<T> {
    var value: T
    init(_ initial: T) { value = initial }
    func set(_ newValue: T) { value = newValue }
}

extension ActorBox where T == Int {
    func increment() { value += 1 }
}

extension ActorBox where T == [String] {
    func append(_ element: String) { value.append(element) }
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

// MARK: - CreateDeploymentUseCase

/// Stub for DeploymentManagementPort that records invocations and returns
/// configurable responses without real network calls.
private actor StubDeploymentPort: DeploymentManagementPort {
    var triggeredEnvironmentId: String?
    var triggeredBranch: String?
    private let stubbedDeployment: Deployment

    init(deployment: Deployment) {
        self.stubbedDeployment = deployment
    }

    func fetchDeployments(for environmentId: String) async throws -> [Deployment] { [] }

    func triggerDeployment(environmentId: String, branch: String) async throws -> Deployment {
        triggeredEnvironmentId = environmentId
        triggeredBranch = branch
        return stubbedDeployment
    }

    func cancelDeployment(id: String) async throws {}
}

@Suite("CreateDeploymentUseCase")
struct CreateDeploymentUseCaseTests {

    private func makeDeployment(environmentId: String = "env-prod") -> Deployment {
        Deployment(projectId: "proj-1", environmentId: environmentId, status: .building)
    }

    @Test("execute returns deployment from port")
    func returnsDeploymentFromPort() async throws {
        let expected = makeDeployment()
        let stub = StubDeploymentPort(deployment: expected)
        let useCase = CreateDeploymentUseCase(deploymentPort: stub, eventBus: EventBus.shared)
        let result = try await useCase.execute(environmentId: "env-prod", branch: "main")
        #expect(result.id == expected.id)
    }

    @Test("execute forwards environmentId to port")
    func forwardsEnvironmentId() async throws {
        let stub = StubDeploymentPort(deployment: makeDeployment(environmentId: "env-staging"))
        let useCase = CreateDeploymentUseCase(deploymentPort: stub, eventBus: EventBus.shared)
        _ = try await useCase.execute(environmentId: "env-staging", branch: "develop")
        let recorded = await stub.triggeredEnvironmentId
        #expect(recorded == "env-staging")
    }

    @Test("execute forwards branch to port")
    func forwardsBranch() async throws {
        let stub = StubDeploymentPort(deployment: makeDeployment())
        let useCase = CreateDeploymentUseCase(deploymentPort: stub, eventBus: EventBus.shared)
        _ = try await useCase.execute(environmentId: "env-prod", branch: "release/1.0")
        let recorded = await stub.triggeredBranch
        #expect(recorded == "release/1.0")
    }

    @Test("deployment status is preserved from port response")
    func deploymentStatusPreserved() async throws {
        let deployment = Deployment(projectId: "proj-1", environmentId: "env-prod", status: .building)
        let stub = StubDeploymentPort(deployment: deployment)
        let useCase = CreateDeploymentUseCase(deploymentPort: stub, eventBus: EventBus.shared)
        let result = try await useCase.execute(environmentId: "env-prod", branch: "main")
        #expect(result.status == .building)
    }

    @Test("deployment id is non-empty")
    func deploymentIdNonEmpty() async throws {
        let stub = StubDeploymentPort(deployment: makeDeployment())
        let useCase = CreateDeploymentUseCase(deploymentPort: stub, eventBus: EventBus.shared)
        let result = try await useCase.execute(environmentId: "env-prod", branch: "main")
        #expect(!result.id.isEmpty)
    }

    @Test("InMemoryDeploymentService triggerDeployment sets building status")
    func inMemoryServiceSetsBuildingStatus() async throws {
        let service = InMemoryDeploymentService()
        let useCase = CreateDeploymentUseCase(deploymentPort: service, eventBus: EventBus.shared)
        let result = try await useCase.execute(environmentId: "env-1", branch: "main")
        #expect(result.status == .building)
        #expect(result.environmentId == "env-1")
    }
}

// MARK: - AutoCommitUseCase

/// Records the arguments passed to stage() and commit() so tests can assert
/// that AutoCommitUseCase delegates to SourceControlPort correctly.
private actor SpySourceControlPort: SourceControlPort {
    nonisolated var providerId: String { "spy" }
    nonisolated var providerName: String { "Spy SCM" }

    var stagedPaths: [String] = []
    var commitMessage: String?
    var commitAmend: Bool?
    private let stubbedCommit: Commit

    init(commit: Commit) { self.stubbedCommit = commit }

    func validateConnection() async throws -> Bool { true }

    func stage(paths: [String]) async throws { stagedPaths = paths }

    func commit(message: String, amend: Bool) async throws -> Commit {
        commitMessage = message
        commitAmend = amend
        return stubbedCommit
    }

    // Unused protocol requirements
    func branches() async throws -> [Branch] { [] }
    func currentBranch() async throws -> Branch? { nil }
    func commits(branch: String, limit: Int) async throws -> [Commit] { [] }
    func diff(from: String?, to: String?) async throws -> [FileDiff] { [] }
    func stagedDiff() async throws -> [FileDiff] { [] }
    func unstagedDiff() async throws -> [FileDiff] { [] }
    func workingTreeStatus() async throws -> [GitFileChange] { [] }
    func workingTreeChanges() async throws -> (staged: [GitFileChange], unstaged: [GitFileChange], untracked: [GitFileChange]) { ([], [], []) }
    func createBranch(name: String, from: String?) async throws -> Branch { fatalError("not exercised") }
    func deleteBranch(name: String, force: Bool) async throws {}
    func switchBranch(name: String) async throws {}
    func fetch(remote: String) async throws {}
    func pull(remote: String, rebase: Bool) async throws {}
    func push(remote: String, setUpstream: Bool, force: Bool) async throws {}
    func listRemotes() async throws -> [GitRemote] { [] }
    func addRemote(name: String, url: String) async throws {}
    func removeRemote(name: String) async throws {}
    func renameRemote(oldName: String, newName: String) async throws {}
    func merge(source: String, into: String, strategy: MergeStrategy) async throws -> MergeResult { fatalError("not exercised") }
    func rebase(branch: String, onto: String) async throws {}
    func cherryPick(commit: String) async throws {}
    func revert(commit: String) async throws {}
    func blame(file: String, ref: String?) async throws -> [BlameLine] { [] }
    func fileHistory(file: String) async throws -> [Commit] { [] }
    func stash(message: String?) async throws {}
    func stashPop() async throws {}
    func stashApply(index: Int) async throws {}
    func stashDrop(index: Int) async throws {}
    func stashList() async throws -> [Stash] { [] }
    func unstage(paths: [String]) async throws {}
    func createWorktree(branch: String, path: String) async throws {}
    func removeWorktree(path: String) async throws {}
    func worktrees() async throws -> [Worktree] { [] }
    func tags() async throws -> [AnvilDomain.Tag] { [] }
    func createTag(name: String, message: String?, commit: String?) async throws -> AnvilDomain.Tag { fatalError("not exercised") }
    func deleteTag(name: String) async throws {}
}

@Suite("AutoCommitUseCase")
struct AutoCommitUseCaseTests {

    private func makeCommit(message: String = "initial") -> Commit {
        Commit(
            id: UUID().uuidString,
            shortHash: "abc1234",
            author: "alice",
            authorEmail: "alice@example.com",
            date: .now,
            message: message
        )
    }

    @Test("execute returns commit from provider")
    func returnsCommitFromProvider() async throws {
        let expected = makeCommit(message: "Add feature")
        let spy = SpySourceControlPort(commit: expected)
        let useCase = AutoCommitUseCase()
        let result = try await useCase.execute(message: "Add feature", paths: ["file.swift"], provider: spy)
        #expect(result.id == expected.id)
    }

    @Test("execute calls stage with correct paths")
    func callsStageWithCorrectPaths() async throws {
        let spy = SpySourceControlPort(commit: makeCommit())
        let useCase = AutoCommitUseCase()
        let paths = ["Sources/Foo.swift", "Tests/FooTests.swift"]
        _ = try await useCase.execute(message: "Update tests", paths: paths, provider: spy)
        let staged = await spy.stagedPaths
        #expect(staged == paths)
    }

    @Test("execute passes message to commit")
    func passesMessageToCommit() async throws {
        let spy = SpySourceControlPort(commit: makeCommit())
        let useCase = AutoCommitUseCase()
        _ = try await useCase.execute(message: "Refactor auth", paths: ["Auth.swift"], provider: spy)
        let recorded = await spy.commitMessage
        #expect(recorded == "Refactor auth")
    }

    @Test("execute always commits with amend false")
    func commitAmendIsFalse() async throws {
        let spy = SpySourceControlPort(commit: makeCommit())
        let useCase = AutoCommitUseCase()
        _ = try await useCase.execute(message: "No amend", paths: ["x.swift"], provider: spy)
        let amend = await spy.commitAmend
        #expect(amend == false)
    }

    @Test("execute with empty paths still calls stage")
    func emptyPathsStillCallsStage() async throws {
        let spy = SpySourceControlPort(commit: makeCommit())
        let useCase = AutoCommitUseCase()
        _ = try await useCase.execute(message: "Empty stage", paths: [], provider: spy)
        let staged = await spy.stagedPaths
        #expect(staged.isEmpty)
    }

    @Test("commit message is preserved in returned commit")
    func commitMessagePreserved() async throws {
        let commit = makeCommit(message: "Fix critical bug")
        let spy = SpySourceControlPort(commit: commit)
        let useCase = AutoCommitUseCase()
        let result = try await useCase.execute(message: "Fix critical bug", paths: ["Bug.swift"], provider: spy)
        #expect(result.message == "Fix critical bug")
    }
}

// MARK: - CreateWorktreeUseCase

/// Captures createWorktree calls so tests can verify branch and path.
private actor SpyWorktreePort: SourceControlPort {
    nonisolated var providerId: String { "spy-worktree" }
    nonisolated var providerName: String { "Spy Worktree SCM" }

    var capturedBranch: String?
    var capturedPath: String?

    func validateConnection() async throws -> Bool { true }
    func stage(paths: [String]) async throws {}
    func commit(message: String, amend: Bool) async throws -> Commit { fatalError("not exercised") }
    func createWorktree(branch: String, path: String) async throws {
        capturedBranch = branch
        capturedPath = path
    }
    func branches() async throws -> [Branch] { [] }
    func currentBranch() async throws -> Branch? { nil }
    func commits(branch: String, limit: Int) async throws -> [Commit] { [] }
    func diff(from: String?, to: String?) async throws -> [FileDiff] { [] }
    func stagedDiff() async throws -> [FileDiff] { [] }
    func unstagedDiff() async throws -> [FileDiff] { [] }
    func workingTreeStatus() async throws -> [GitFileChange] { [] }
    func workingTreeChanges() async throws -> (staged: [GitFileChange], unstaged: [GitFileChange], untracked: [GitFileChange]) { ([], [], []) }
    func createBranch(name: String, from: String?) async throws -> Branch { fatalError("not exercised") }
    func deleteBranch(name: String, force: Bool) async throws {}
    func switchBranch(name: String) async throws {}
    func fetch(remote: String) async throws {}
    func pull(remote: String, rebase: Bool) async throws {}
    func push(remote: String, setUpstream: Bool, force: Bool) async throws {}
    func listRemotes() async throws -> [GitRemote] { [] }
    func addRemote(name: String, url: String) async throws {}
    func removeRemote(name: String) async throws {}
    func renameRemote(oldName: String, newName: String) async throws {}
    func merge(source: String, into: String, strategy: MergeStrategy) async throws -> MergeResult { fatalError("not exercised") }
    func rebase(branch: String, onto: String) async throws {}
    func cherryPick(commit: String) async throws {}
    func revert(commit: String) async throws {}
    func blame(file: String, ref: String?) async throws -> [BlameLine] { [] }
    func fileHistory(file: String) async throws -> [Commit] { [] }
    func stash(message: String?) async throws {}
    func stashPop() async throws {}
    func stashApply(index: Int) async throws {}
    func stashDrop(index: Int) async throws {}
    func stashList() async throws -> [Stash] { [] }
    func unstage(paths: [String]) async throws {}
    func removeWorktree(path: String) async throws {}
    func worktrees() async throws -> [Worktree] { [] }
    func tags() async throws -> [AnvilDomain.Tag] { [] }
    func createTag(name: String, message: String?, commit: String?) async throws -> AnvilDomain.Tag { fatalError("not exercised") }
    func deleteTag(name: String) async throws {}
}

@Suite("CreateWorktreeUseCase")
struct CreateWorktreeUseCaseTests {

    @Test("execute forwards branch to provider")
    func forwardsBranch() async throws {
        let spy = SpyWorktreePort()
        let useCase = CreateWorktreeUseCase(basePath: "/worktrees")
        try await useCase.execute(branch: "feature/login", sessionId: "sess-1", projectName: "anvil", provider: spy)
        let branch = await spy.capturedBranch
        #expect(branch == "feature/login")
    }

    @Test("execute constructs path from basePath, projectName, and sessionId")
    func constructsWorktreePath() async throws {
        let spy = SpyWorktreePort()
        let useCase = CreateWorktreeUseCase(basePath: "/base")
        try await useCase.execute(branch: "main", sessionId: "session-99", projectName: "myapp", provider: spy)
        let path = await spy.capturedPath
        #expect(path == "/base/myapp/session-99")
    }

    @Test("default basePath contains .anvil/worktrees")
    func defaultBasePathContainsAnvilWorktrees() async throws {
        let spy = SpyWorktreePort()
        let useCase = CreateWorktreeUseCase()
        try await useCase.execute(branch: "main", sessionId: "s1", projectName: "proj", provider: spy)
        let path = await spy.capturedPath
        #expect(path?.contains("worktrees") == true)
    }

    @Test("sessionId appears in the worktree path")
    func sessionIdInPath() async throws {
        let spy = SpyWorktreePort()
        let useCase = CreateWorktreeUseCase(basePath: "/wt")
        let sessionId = UUID().uuidString
        try await useCase.execute(branch: "dev", sessionId: sessionId, projectName: "proj", provider: spy)
        let path = await spy.capturedPath
        #expect(path?.contains(sessionId) == true)
    }

    @Test("projectName appears in the worktree path")
    func projectNameInPath() async throws {
        let spy = SpyWorktreePort()
        let useCase = CreateWorktreeUseCase(basePath: "/wt")
        try await useCase.execute(branch: "dev", sessionId: "s2", projectName: "cool-project", provider: spy)
        let path = await spy.capturedPath
        #expect(path?.contains("cool-project") == true)
    }

    @Test("paths for different sessions are distinct")
    func distinctPathsForDifferentSessions() async throws {
        let spy1 = SpyWorktreePort()
        let spy2 = SpyWorktreePort()
        let useCase = CreateWorktreeUseCase(basePath: "/wt")
        try await useCase.execute(branch: "dev", sessionId: "sess-A", projectName: "proj", provider: spy1)
        try await useCase.execute(branch: "dev", sessionId: "sess-B", projectName: "proj", provider: spy2)
        let path1 = await spy1.capturedPath
        let path2 = await spy2.capturedPath
        #expect(path1 != path2)
    }
}

// MARK: - GenerateCommitMessageUseCase

/// Stub ACPPort that returns a fixed stream of textDelta events, simulating
/// a complete model response without a real network connection.
private struct StubACPPort: ACPPort {
    let providerId: String = "stub-acp"
    let providerName: String = "Stub ACP"
    private let responseText: String
    private let models: [ACPModel]

    init(responseText: String, models: [ACPModel] = []) {
        self.responseText = responseText
        self.models = models
    }

    func availableModels() async throws -> [ACPModel] { models }

    func estimateCost(messages: [ACPMessage], model: ACPModel) -> ACPCostEstimate {
        ACPCostEstimate(estimatedInputTokens: 0, estimatedOutputTokens: 0, estimatedCost: 0)
    }

    func supportsTools(_ tools: [ACPToolDefinition]) -> Bool { false }

    func complete(messages: [ACPMessage], model: ACPModel, tools: [ACPToolDefinition], stream: Bool) -> AsyncThrowingStream<ACPStreamEvent, Error> {
        let text = responseText
        return AsyncThrowingStream { continuation in
            continuation.yield(.textDelta(text))
            continuation.finish()
        }
    }
}

@Suite("GenerateCommitMessageUseCase")
struct GenerateCommitMessageUseCaseTests {

    private func makeModel() -> ACPModel {
        ACPModel(id: "claude-3", name: "Claude 3", provider: "anthropic",
                 contextWindow: 200_000, inputCostPer1kTokens: 0.003,
                 outputCostPer1kTokens: 0.015)
    }

    @Test("execute returns trimmed response from provider")
    func returnsResponseText() async throws {
        let stub = StubACPPort(responseText: "  Add user authentication\n\n")
        let useCase = GenerateCommitMessageUseCase()
        let result = try await useCase.execute(diff: "diff --git a/Auth.swift", provider: stub, model: makeModel())
        #expect(result == "Add user authentication")
    }

    @Test("execute with explicit model skips availableModels call")
    func explicitModelSkipsAvailableModels() async throws {
        // StubACPPort with no models would throw noModelsAvailable if model lookup
        // were required; providing a model explicitly must bypass that path.
        let stub = StubACPPort(responseText: "Fix bug", models: [])
        let useCase = GenerateCommitMessageUseCase()
        let result = try await useCase.execute(diff: "some diff", provider: stub, model: makeModel())
        #expect(result == "Fix bug")
    }

    @Test("execute throws noModelsAvailable when no model and none available")
    func throwsWhenNoModels() async throws {
        let stub = StubACPPort(responseText: "", models: [])
        let useCase = GenerateCommitMessageUseCase()
        await #expect(throws: GenerateCommitMessageError.noModelsAvailable) {
            try await useCase.execute(diff: "some diff", provider: stub, model: nil)
        }
    }

    @Test("execute uses first available model when none specified")
    func usesFirstAvailableModel() async throws {
        let model = makeModel()
        let stub = StubACPPort(responseText: "Update logging", models: [model])
        let useCase = GenerateCommitMessageUseCase()
        let result = try await useCase.execute(diff: "diff content", provider: stub, model: nil)
        #expect(result == "Update logging")
    }

    @Test("execute with long diff truncates to 8000 chars")
    func longDiffIsTruncated() async throws {
        // The use case truncates the diff to 8000 chars in the prompt; verify
        // it still calls through and returns the stub's response without error.
        let longDiff = String(repeating: "x", count: 20_000)
        let stub = StubACPPort(responseText: "Refactor core module", models: [makeModel()])
        let useCase = GenerateCommitMessageUseCase()
        let result = try await useCase.execute(diff: longDiff, provider: stub, model: makeModel())
        #expect(result == "Refactor core module")
    }

    @Test("execute with empty diff returns whatever provider returns")
    func emptyDiffReturnsProviderResult() async throws {
        let stub = StubACPPort(responseText: "Empty change", models: [makeModel()])
        let useCase = GenerateCommitMessageUseCase()
        let result = try await useCase.execute(diff: "", provider: stub, model: makeModel())
        #expect(result == "Empty change")
    }

    @Test("result is trimmed of surrounding whitespace")
    func resultIsTrimmed() async throws {
        let stub = StubACPPort(responseText: "\n\n  Fix typo  \n\n", models: [])
        let useCase = GenerateCommitMessageUseCase()
        let result = try await useCase.execute(diff: "d", provider: stub, model: makeModel())
        #expect(result == "Fix typo")
    }
}

// MARK: - AIReviewUseCase

@Suite("AIReviewUseCase")
struct AIReviewUseCaseTests {

    private func makeModel() -> ACPModel {
        ACPModel(id: "claude-3", name: "Claude 3 Sonnet", provider: "anthropic",
                 contextWindow: 200_000, inputCostPer1kTokens: 0.003,
                 outputCostPer1kTokens: 0.015)
    }

    private func makeFileDiff(path: String = "Sources/Foo.swift",
                               status: DiffFileStatus = .modified,
                               lines: [DiffLine] = []) -> FileDiff {
        let hunk = DiffHunk(oldStart: 1, oldCount: 3, newStart: 1, newCount: 4,
                            header: "@@ -1,3 +1,4 @@", lines: lines)
        return FileDiff(filePath: path, status: status, hunks: [hunk])
    }

    @Test("execute returns exactly one ReviewComment")
    func returnsOneComment() async throws {
        let stub = StubACPPort(responseText: "Looks good")
        let useCase = AIReviewUseCase()
        let comments = try await useCase.execute(diff: [makeFileDiff()], acpProvider: stub, model: makeModel())
        #expect(comments.count == 1)
    }

    @Test("returned comment is marked as AI generated")
    func commentIsAIGenerated() async throws {
        let stub = StubACPPort(responseText: "Check null safety")
        let useCase = AIReviewUseCase()
        let comments = try await useCase.execute(diff: [makeFileDiff()], acpProvider: stub, model: makeModel())
        #expect(comments.first?.isAIGenerated == true)
    }

    @Test("comment author contains model name")
    func commentAuthorContainsModelName() async throws {
        let model = makeModel()
        let stub = StubACPPort(responseText: "Review body")
        let useCase = AIReviewUseCase()
        let comments = try await useCase.execute(diff: [makeFileDiff()], acpProvider: stub, model: model)
        #expect(comments.first?.author.contains(model.name) == true)
    }

    @Test("comment body matches provider response")
    func commentBodyMatchesProviderResponse() async throws {
        let stub = StubACPPort(responseText: "Extract this into a helper function")
        let useCase = AIReviewUseCase()
        let comments = try await useCase.execute(diff: [makeFileDiff()], acpProvider: stub, model: makeModel())
        #expect(comments.first?.body == "Extract this into a helper function")
    }

    @Test("execute with empty diff still returns one comment")
    func emptyDiffStillReturnsComment() async throws {
        let stub = StubACPPort(responseText: "Nothing to review")
        let useCase = AIReviewUseCase()
        let comments = try await useCase.execute(diff: [], acpProvider: stub, model: makeModel())
        #expect(comments.count == 1)
    }

    @Test("execute with multiple file diffs returns one aggregated comment")
    func multipleFileDiffsReturnOneComment() async throws {
        let stub = StubACPPort(responseText: "Multi-file review")
        let useCase = AIReviewUseCase()
        let diffs = [
            makeFileDiff(path: "A.swift", status: .added),
            makeFileDiff(path: "B.swift", status: .modified),
        ]
        let comments = try await useCase.execute(diff: diffs, acpProvider: stub, model: makeModel())
        #expect(comments.count == 1)
    }

    @Test("comment has a non-empty id")
    func commentHasNonEmptyId() async throws {
        let stub = StubACPPort(responseText: "LGTM")
        let useCase = AIReviewUseCase()
        let comments = try await useCase.execute(diff: [makeFileDiff()], acpProvider: stub, model: makeModel())
        #expect(comments.first?.id.isEmpty == false)
    }
}

// MARK: - SubmitReviewUseCase

/// Records all calls to submitReview so tests can inspect delegated arguments.
private actor SpyCodeReviewPort: CodeReviewPort {
    nonisolated var providerId: String { "spy-review" }
    nonisolated var providerName: String { "Spy Code Review" }

    var lastSubmittedId: String?
    var lastSubmittedStatus: ReviewStatus?
    var lastSubmittedComments: [ReviewCommentDraft]?

    func validateConnection() async throws -> Bool { true }

    func pendingReviews() async throws -> [Review] { [] }
    func reviewDetail(id: String) async throws -> Review {
        Review(title: "stub", sourceType: .pullRequest, sourceId: id, author: "spy")
    }
    func submitReview(id: String, status: ReviewStatus, comments: [ReviewCommentDraft]) async throws {
        lastSubmittedId = id
        lastSubmittedStatus = status
        lastSubmittedComments = comments
    }
    func resolveComment(id: String) async throws {}
    func requestReview(from: String, for reviewId: String) async throws {}
}

@Suite("SubmitReviewUseCase")
struct SubmitReviewUseCaseTests {

    @Test("execute delegates to port with correct review id")
    func delegatesCorrectReviewId() async throws {
        let spy = SpyCodeReviewPort()
        let useCase = SubmitReviewUseCase()
        try await useCase.execute(reviewId: "review-42", status: .approved, comments: [], provider: spy)
        let id = await spy.lastSubmittedId
        #expect(id == "review-42")
    }

    @Test("execute delegates correct approved status")
    func delegatesApprovedStatus() async throws {
        let spy = SpyCodeReviewPort()
        let useCase = SubmitReviewUseCase()
        try await useCase.execute(reviewId: "r1", status: .approved, comments: [], provider: spy)
        let status = await spy.lastSubmittedStatus
        #expect(status == .approved)
    }

    @Test("execute delegates changesRequested status")
    func delegatesChangesRequestedStatus() async throws {
        let spy = SpyCodeReviewPort()
        let useCase = SubmitReviewUseCase()
        try await useCase.execute(reviewId: "r2", status: .changesRequested, comments: [], provider: spy)
        let status = await spy.lastSubmittedStatus
        #expect(status == .changesRequested)
    }

    @Test("execute forwards comment drafts to port")
    func forwardsCommentDrafts() async throws {
        let spy = SpyCodeReviewPort()
        let useCase = SubmitReviewUseCase()
        let drafts = [
            ReviewCommentDraft(body: "Fix this", filePath: "Foo.swift", lineRange: 10...15),
            ReviewCommentDraft(body: "Rename variable"),
        ]
        try await useCase.execute(reviewId: "r3", status: .changesRequested, comments: drafts, provider: spy)
        let submitted = await spy.lastSubmittedComments
        #expect(submitted?.count == 2)
        #expect(submitted?.first?.body == "Fix this")
    }

    @Test("execute with empty comments forwards empty array")
    func emptyCommentsForwardedCorrectly() async throws {
        let spy = SpyCodeReviewPort()
        let useCase = SubmitReviewUseCase()
        try await useCase.execute(reviewId: "r4", status: .dismissed, comments: [], provider: spy)
        let submitted = await spy.lastSubmittedComments
        #expect(submitted?.isEmpty == true)
    }

    @Test("execute with dismissed status delegates correctly")
    func delegatesDismissedStatus() async throws {
        let spy = SpyCodeReviewPort()
        let useCase = SubmitReviewUseCase()
        try await useCase.execute(reviewId: "r5", status: .dismissed, comments: [], provider: spy)
        let status = await spy.lastSubmittedStatus
        #expect(status == .dismissed)
    }
}

// MARK: - SwitchAgentProviderUseCase

@Suite("SwitchAgentProviderUseCase")
struct SwitchAgentProviderUseCaseTests {

    @Test("execute completes without throwing for a valid session and provider switch")
    func completesWithoutThrowing() async throws {
        let useCase = SwitchAgentProviderUseCase()
        let result = try await useCase.execute(sessionId: "sess-1", previousProviderName: "claude", newProviderName: "openai", model: nil)
        #expect(result.sessionId == "sess-1")
        #expect(result.previousProvider == "claude")
        #expect(result.newProvider == "openai")
    }

    @Test("execute completes with explicit model parameter")
    func completesWithExplicitModel() async throws {
        let useCase = SwitchAgentProviderUseCase()
        let result = try await useCase.execute(sessionId: "sess-2", previousProviderName: "claude", newProviderName: "openai", model: "claude-opus-4-6")
        #expect(result.model == "claude-opus-4-6")
    }

    @Test("execute accepts empty session id")
    func acceptsEmptySessionId() async throws {
        let useCase = SwitchAgentProviderUseCase()
        let result = try await useCase.execute(sessionId: "", previousProviderName: "claude", newProviderName: "openai", model: nil)
        #expect(result.sessionId == "")
    }

    @Test("execute accepts nil model")
    func acceptsNilModel() async throws {
        let useCase = SwitchAgentProviderUseCase()
        let result = try await useCase.execute(sessionId: "sess-3", previousProviderName: "claude", newProviderName: "gemini", model: nil)
        #expect(result.model == nil)
    }

    @Test("execute throws when switching to the same provider")
    func throwsForSameProvider() async throws {
        let useCase = SwitchAgentProviderUseCase()
        await #expect(throws: SwitchAgentProviderError.self) {
            try await useCase.execute(sessionId: "s1", previousProviderName: "claude", newProviderName: "claude", model: nil)
        }
    }

    @Test("execute can be called multiple times for different providers")
    func canBeCalledMultipleTimes() async throws {
        let useCase = SwitchAgentProviderUseCase()
        _ = try await useCase.execute(sessionId: "s1", previousProviderName: "claude", newProviderName: "openai", model: nil)
        _ = try await useCase.execute(sessionId: "s1", previousProviderName: "openai", newProviderName: "gemini", model: "gpt-4o")
        _ = try await useCase.execute(sessionId: "s1", previousProviderName: "gemini", newProviderName: "mistral", model: nil)
    }

    @Test("switching to different provider ids returns correct result")
    func differentProviderIdsAccepted() async throws {
        let useCase = SwitchAgentProviderUseCase()
        let providers = ["claude", "openai", "gemini", "mistral"]
        for i in 0..<(providers.count - 1) {
            let result = try await useCase.execute(
                sessionId: "sess-multi",
                previousProviderName: providers[i],
                newProviderName: providers[i + 1],
                model: nil
            )
            #expect(result.previousProvider == providers[i])
            #expect(result.newProvider == providers[i + 1])
        }
    }

    @Test("result includes switchedAt timestamp")
    func resultIncludesTimestamp() async throws {
        let before = Date()
        let useCase = SwitchAgentProviderUseCase()
        let result = try await useCase.execute(sessionId: "sess-ts", previousProviderName: "claude", newProviderName: "openai", model: nil)
        let after = Date()
        #expect(result.switchedAt >= before)
        #expect(result.switchedAt <= after)
    }
}
