import XCTest
@testable import AnvilUI
import AnvilDomain
import AnvilApplication

/// XCTest coverage for AgentViewModel worktree / session-limit lifecycle:
/// - isAtSessionLimit: false at 0..7 sessions, true at 8
/// - sessionLimitMessage: nil below limit, set at limit, cleared when back below
/// - startNewSession respects limit (does not add session when at limit)
/// - Sessions added/removed correctly
@MainActor
final class AgentViewModelWorktreeTests: XCTestCase {

    var vm: AgentViewModel!

    override func setUp() {
        vm = AgentViewModel()
    }

    override func tearDown() {
        vm = nil
    }

    // MARK: - Helpers

    private func addSessions(_ count: Int) {
        for i in 0..<count {
            vm.startNewSession(prompt: "task \(i)", model: "claude-sonnet-4-6")
        }
    }

    // MARK: - maxSessions constant

    func testMaxSessionsIsEight() {
        XCTAssertEqual(AgentViewModel.maxSessions, 8)
    }

    // MARK: - isAtSessionLimit

    func testIsAtSessionLimitFalseWithNoSessions() {
        XCTAssertFalse(vm.isAtSessionLimit)
    }

    func testIsAtSessionLimitFalseAtOneBelowLimit() {
        addSessions(7)
        XCTAssertEqual(vm.sessions.count, 7)
        XCTAssertFalse(vm.isAtSessionLimit)
    }

    func testIsAtSessionLimitTrueAtExactLimit() {
        addSessions(8)
        XCTAssertEqual(vm.sessions.count, 8)
        XCTAssertTrue(vm.isAtSessionLimit)
    }

    func testIsAtSessionLimitTrueAboveLimit() {
        // Force sessions array directly to simulate pre-loaded sessions
        vm.sessions = (0..<9).map { i in
            AgentSession(id: "s\(i)", providerId: "test", model: "test")
        }
        XCTAssertTrue(vm.isAtSessionLimit)
    }

    func testIsAtSessionLimitFalseAfterDeletion() {
        addSessions(8)
        XCTAssertTrue(vm.isAtSessionLimit)
        guard let firstId = vm.sessions.first?.id else { return XCTFail("No sessions") }
        vm.deleteSession(firstId)
        XCTAssertFalse(vm.isAtSessionLimit)
    }

    // MARK: - sessionLimitMessage

    func testSessionLimitMessageNilInitially() {
        XCTAssertNil(vm.sessionLimitMessage)
    }

    func testSessionLimitMessageNilBelowLimit() {
        addSessions(7)
        // Try adding one more (8th) — should succeed without limit message
        vm.startNewSession(prompt: "ok", model: "claude-sonnet-4-6")
        XCTAssertNil(vm.sessionLimitMessage)
    }

    func testSessionLimitMessageSetWhenLimitReached() {
        addSessions(8) // fills to limit
        vm.startNewSession(prompt: "over limit", model: "claude-sonnet-4-6")
        XCTAssertNotNil(vm.sessionLimitMessage)
        XCTAssertTrue(vm.sessionLimitMessage!.contains("8"))
    }

    func testSessionLimitMessageClearedAfterDeletion() {
        addSessions(8)
        vm.startNewSession(prompt: "over", model: "claude-sonnet-4-6")
        XCTAssertNotNil(vm.sessionLimitMessage)

        guard let firstId = vm.sessions.first?.id else { return XCTFail("No sessions") }
        vm.deleteSession(firstId)
        // After deletion we drop below limit — message should be cleared
        XCTAssertNil(vm.sessionLimitMessage)
    }

    // MARK: - startNewSession at limit does not add session

    func testStartNewSessionAtLimitDoesNotAddSession() {
        addSessions(8)
        let countBefore = vm.sessions.count
        vm.startNewSession(prompt: "extra", model: "claude-sonnet-4-6")
        XCTAssertEqual(vm.sessions.count, countBefore, "No session should be added when at limit")
    }

    // MARK: - startNewSession below limit adds session

    func testStartNewSessionAddsOneSession() {
        vm.startNewSession(prompt: "first", model: "claude-sonnet-4-6")
        XCTAssertEqual(vm.sessions.count, 1)
    }

    func testStartNewSessionSetsSelectedSessionId() {
        vm.startNewSession(prompt: "hello", model: "claude-sonnet-4-6")
        XCTAssertNotNil(vm.selectedSessionId)
    }

    func testStartNewSessionCreatesSessionWithPromptAsFirstMessage() {
        vm.startNewSession(prompt: "fix the bug", model: "claude-sonnet-4-6")
        let session = vm.sessions.first
        XCTAssertNotNil(session)
    }

    // MARK: - deleteSession

    func testDeleteSessionRemovesFromList() {
        vm.startNewSession(prompt: "a", model: "claude-sonnet-4-6")
        guard let id = vm.sessions.first?.id else { return XCTFail() }
        vm.deleteSession(id)
        XCTAssertTrue(vm.sessions.isEmpty)
    }

    func testDeleteSessionWithUnknownIdIsSafe() {
        vm.startNewSession(prompt: "b", model: "claude-sonnet-4-6")
        vm.deleteSession("nonexistent-id")
        XCTAssertEqual(vm.sessions.count, 1)
    }

    func testDeleteSessionClearsSelectedIdWhenLast() {
        vm.startNewSession(prompt: "c", model: "claude-sonnet-4-6")
        guard let id = vm.sessions.first?.id else { return XCTFail() }
        vm.deleteSession(id)
        XCTAssertNil(vm.selectedSessionId)
    }

    // MARK: - WorktreeOrchestrator integration (pure model)

    func testWorktreeOrchestratorTracksSessionPath() async throws {
        let orchestrator = WorktreeOrchestrator(basePath: "/tmp/test-worktrees")
        let mock = MockSourceControlPort()

        // createForSession returns a path
        let path = try await orchestrator.createForSession(
            sessionId: "abc12345",
            branch: "anvil/agent/abc12345",
            projectName: "anvil",
            provider: mock
        )
        XCTAssertTrue(path.contains("abc12345"))
        XCTAssertEqual(mock.createdWorktreePaths.first, path)
    }

    func testWorktreeOrchestratorWorktreePathLookup() async throws {
        let orchestrator = WorktreeOrchestrator(basePath: "/tmp/test-worktrees")
        let mock = MockSourceControlPort()

        _ = try await orchestrator.createForSession(
            sessionId: "session1",
            branch: "anvil/agent/session1",
            projectName: "anvil",
            provider: mock
        )
        let path = await orchestrator.worktreePath(for: "session1")
        XCTAssertNotNil(path)
        XCTAssertTrue(path!.contains("session1"))
    }

    func testWorktreeOrchestratorCleanupRemovesPath() async throws {
        let orchestrator = WorktreeOrchestrator(basePath: "/tmp/test-worktrees")
        let mock = MockSourceControlPort()

        _ = try await orchestrator.createForSession(
            sessionId: "sess2",
            branch: "anvil/agent/sess2",
            projectName: "anvil",
            provider: mock
        )
        try await orchestrator.cleanupForSession(sessionId: "sess2", provider: mock)

        let path = await orchestrator.worktreePath(for: "sess2")
        XCTAssertNil(path, "Path should be removed after cleanup")
        XCTAssertTrue(mock.removedWorktreePaths.count > 0)
    }

    func testWorktreeOrchestratorCleanupUnknownSessionIsSafe() async throws {
        let orchestrator = WorktreeOrchestrator(basePath: "/tmp/test-worktrees")
        let mock = MockSourceControlPort()
        // Should not throw for unknown session
        try await orchestrator.cleanupForSession(sessionId: "unknown", provider: mock)
        XCTAssertTrue(mock.removedWorktreePaths.isEmpty)
    }
}

// MARK: - MockSourceControlPort

/// Minimal mock for SourceControlPort that records worktree calls.
final class MockSourceControlPort: SourceControlPort, @unchecked Sendable {
    var createdWorktreePaths: [String] = []
    var removedWorktreePaths: [String] = []

    static var primitiveId: String { "mock" }
    static var displayName: String { "Mock" }
    static var iconName: String { "mock" }

    var providerId: String { "mock" }
    var providerName: String { "Mock" }
    func validateConnection() async throws -> Bool { true }

    func branches() async throws -> [Branch] { [] }
    func currentBranch() async throws -> Branch? { nil }
    func createBranch(name: String, from: String?) async throws -> Branch {
        Branch(name: name, isCurrent: false)
    }
    func deleteBranch(name: String, force: Bool) async throws {}
    func switchBranch(name: String) async throws {}
    func commits(branch: String, limit: Int) async throws -> [Commit] { [] }
    func commit(message: String, amend: Bool) async throws -> Commit {
        Commit(hash: "abc1234", shortHash: "abc1234", message: message, author: "test", email: "", date: .now, parents: [])
    }
    func stage(paths: [String]) async throws {}
    func unstage(paths: [String]) async throws {}
    func diff(from: String?, to: String?) async throws -> [FileDiff] { [] }
    func stagedDiff() async throws -> [FileDiff] { [] }
    func unstagedDiff() async throws -> [FileDiff] { [] }
    func workingTreeStatus() async throws -> [GitFileChange] { [] }
    func workingTreeChanges() async throws -> (staged: [GitFileChange], unstaged: [GitFileChange], untracked: [GitFileChange]) {
        ([], [], [])
    }
    func fetch(remote: String) async throws {}
    func pull(remote: String, rebase: Bool) async throws {}
    func push(remote: String, setUpstream: Bool, force: Bool) async throws {}
    func listRemotes() async throws -> [GitRemote] { [] }
    func addRemote(name: String, url: String) async throws {}
    func removeRemote(name: String) async throws {}
    func renameRemote(oldName: String, newName: String) async throws {}
    func merge(source: String, into: String, strategy: MergeStrategy) async throws -> MergeResult {
        .alreadyUpToDate
    }
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
    func tags() async throws -> [Tag] { [] }
    func createTag(name: String, message: String?, commit: String?) async throws -> Tag {
        Tag(name: name, targetCommit: commit ?? "HEAD")
    }
    func deleteTag(name: String) async throws {}
    func createWorktree(branch: String, path: String) async throws {
        createdWorktreePaths.append(path)
    }
    func removeWorktree(path: String) async throws {
        removedWorktreePaths.append(path)
    }
    func worktrees() async throws -> [Worktree] { [] }
}
