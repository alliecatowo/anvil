import XCTest
@testable import AnvilGit
import AnvilDomain

/// Integration tests for GitSourceControlAdapter.
///
/// Two test groups:
/// 1. Output-parsing tests — replicate private parsing helpers against sample strings,
///    no real Process calls.
/// 2. Live adapter tests — run against the Anvil repo itself (always a git repo), using
///    real git commands through GitShell.
final class GitAdapterOutputParsingTests: XCTestCase {

    // MARK: - Branch format parsing (replicates branches() compactMap)

    private func parseBranchLine(_ line: String) -> Branch? {
        let parts = line.components(separatedBy: "|||")
        guard parts.count >= 4 else { return nil }
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let upstream = parts[1].isEmpty ? nil : parts[1]
        let trackInfo = parts[2]
        let isCurrent = parts[3].trimmingCharacters(in: .whitespaces) == "*"
        let (ahead, behind) = parseTrackInfo(trackInfo)
        return Branch(name: name, upstream: upstream, aheadCount: ahead, behindCount: behind, isCurrent: isCurrent)
    }

    private func parseTrackInfo(_ info: String) -> (ahead: Int, behind: Int) {
        var ahead = 0
        var behind = 0
        if let r = info.range(of: #"ahead (\d+)"#, options: .regularExpression) {
            ahead = Int(info[r].split(separator: " ").last.map(String.init) ?? "0") ?? 0
        }
        if let r = info.range(of: #"behind (\d+)"#, options: .regularExpression) {
            behind = Int(info[r].split(separator: " ").last.map(String.init) ?? "0") ?? 0
        }
        return (ahead, behind)
    }

    func testBranchLineParsesName() {
        let branch = parseBranchLine("main|||origin/main|||[ahead 1]|||*")
        XCTAssertEqual(branch?.name, "main")
    }

    func testBranchLineCurrentFlag() {
        let current = parseBranchLine("main|||origin/main||| |||*")
        XCTAssertTrue(current?.isCurrent ?? false)
        let other = parseBranchLine("feature|||origin/feature||| ||| ")
        XCTAssertFalse(other?.isCurrent ?? true)
    }

    func testBranchLineUpstreamNilWhenEmpty() {
        let branch = parseBranchLine("local||||||| ")
        XCTAssertNil(branch?.upstream)
    }

    func testBranchLineUpstreamSetWhenPresent() {
        let branch = parseBranchLine("main|||origin/main||| ||| ")
        XCTAssertEqual(branch?.upstream, "origin/main")
    }

    func testBranchLineAheadCount() {
        let branch = parseBranchLine("main|||origin/main|||[ahead 3]||| ")
        XCTAssertEqual(branch?.aheadCount, 3)
    }

    func testBranchLineBehindCount() {
        let branch = parseBranchLine("main|||origin/main|||[behind 7]||| ")
        XCTAssertEqual(branch?.behindCount, 7)
    }

    func testBranchLineAheadAndBehind() {
        let branch = parseBranchLine("main|||origin/main|||[ahead 2, behind 5]||| ")
        XCTAssertEqual(branch?.aheadCount, 2)
        XCTAssertEqual(branch?.behindCount, 5)
    }

    func testBranchLineZeroAheadBehindWhenNoTrackInfo() {
        let branch = parseBranchLine("main|||origin/main||| ||| ")
        XCTAssertEqual(branch?.aheadCount, 0)
        XCTAssertEqual(branch?.behindCount, 0)
    }

    func testBranchLineReturnsNilForTooFewParts() {
        XCTAssertNil(parseBranchLine("main|||origin/main"))
        XCTAssertNil(parseBranchLine(""))
    }

    func testBranchLineReturnsNilForEmptyName() {
        XCTAssertNil(parseBranchLine(" |||origin/main|||[ahead 1]|||*"))
    }

    func testMultipleBranchLinesAllParsed() {
        let sep = "|||"
        let lines = [
            "main\(sep)origin/main\(sep)[ahead 1]\(sep)*",
            "feature/auth\(sep)origin/feature/auth\(sep) \(sep) ",
            "hotfix\(sep)\(sep) \(sep) ",
        ]
        let branches = lines.compactMap { parseBranchLine($0) }
        XCTAssertEqual(branches.count, 3)
        XCTAssertEqual(branches[0].name, "main")
        XCTAssertEqual(branches[1].name, "feature/auth")
        XCTAssertEqual(branches[2].name, "hotfix")
    }

    // MARK: - parseTrackInfo edge cases

    func testTrackInfoEmptyStringYieldsZeros() {
        let (a, b) = parseTrackInfo("")
        XCTAssertEqual(a, 0)
        XCTAssertEqual(b, 0)
    }

    func testTrackInfoGonesYieldsZeros() {
        let (a, b) = parseTrackInfo("[gone]")
        XCTAssertEqual(a, 0)
        XCTAssertEqual(b, 0)
    }

    func testTrackInfoLargeNumbers() {
        let (a, b) = parseTrackInfo("[ahead 100, behind 999]")
        XCTAssertEqual(a, 100)
        XCTAssertEqual(b, 999)
    }

    func testTrackInfoOnlyAhead() {
        let (a, b) = parseTrackInfo("[ahead 4]")
        XCTAssertEqual(a, 4)
        XCTAssertEqual(b, 0)
    }

    func testTrackInfoOnlyBehind() {
        let (a, b) = parseTrackInfo("[behind 11]")
        XCTAssertEqual(a, 0)
        XCTAssertEqual(b, 11)
    }

    // MARK: - Porcelain status char parsing (replicates parseStatusChar)

    private func parseStatusChar(_ c: Character) -> GitFileChangeStatus {
        switch c {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "U": return .unmerged
        case "?": return .untracked
        default: return .modified
        }
    }

    func testStatusCharModified() { XCTAssertEqual(parseStatusChar("M"), .modified) }
    func testStatusCharAdded() { XCTAssertEqual(parseStatusChar("A"), .added) }
    func testStatusCharDeleted() { XCTAssertEqual(parseStatusChar("D"), .deleted) }
    func testStatusCharRenamed() { XCTAssertEqual(parseStatusChar("R"), .renamed) }
    func testStatusCharCopied() { XCTAssertEqual(parseStatusChar("C"), .copied) }
    func testStatusCharUnmerged() { XCTAssertEqual(parseStatusChar("U"), .unmerged) }
    func testStatusCharUntracked() { XCTAssertEqual(parseStatusChar("?"), .untracked) }
    func testStatusCharUnknownFallsBackToModified() {
        // The adapter treats unrecognised chars as modified (default case)
        XCTAssertEqual(parseStatusChar("X"), .modified)
    }

    // MARK: - Worktree output parsing (replicates parseWorktreeOutput)

    private func parseWorktreeOutput(_ output: String) -> [Worktree] {
        var worktrees: [Worktree] = []
        for block in output.components(separatedBy: "\n\n") {
            let lines = block.components(separatedBy: "\n")
            var path = ""; var branch: String?; var isMain = false
            for line in lines {
                if line.hasPrefix("worktree ") { path = String(line.dropFirst("worktree ".count)) }
                else if line.hasPrefix("branch ") {
                    let ref = String(line.dropFirst("branch ".count))
                    branch = ref.replacingOccurrences(of: "refs/heads/", with: "")
                    if branch == "main" || branch == "master" { isMain = true }
                }
            }
            guard !path.isEmpty else { continue }
            worktrees.append(Worktree(path: path, branch: branch, isClean: true, isMain: isMain))
        }
        return worktrees
    }

    func testWorktreeOutputSingleMainWorktree() {
        let output = """
        worktree /Users/dev/project
        HEAD abc1234
        branch refs/heads/main

        """
        let worktrees = parseWorktreeOutput(output)
        XCTAssertEqual(worktrees.count, 1)
        XCTAssertEqual(worktrees[0].path, "/Users/dev/project")
        XCTAssertEqual(worktrees[0].branch, "main")
        XCTAssertTrue(worktrees[0].isMain)
    }

    func testWorktreeOutputFeatureBranchNotMain() {
        let output = """
        worktree /Users/dev/worktrees/feature
        HEAD def5678
        branch refs/heads/feature/login

        """
        let worktrees = parseWorktreeOutput(output)
        XCTAssertEqual(worktrees[0].branch, "feature/login")
        XCTAssertFalse(worktrees[0].isMain)
    }

    func testWorktreeOutputMultipleWorktrees() {
        let output = """
        worktree /project
        HEAD aaa
        branch refs/heads/master

        worktree /project/.worktrees/feat
        HEAD bbb
        branch refs/heads/feature/x

        """
        let worktrees = parseWorktreeOutput(output)
        XCTAssertEqual(worktrees.count, 2)
        XCTAssertTrue(worktrees[0].isMain)
        XCTAssertFalse(worktrees[1].isMain)
    }

    func testWorktreeOutputStripsRefsHeadsPrefix() {
        let output = """
        worktree /tmp/wt
        branch refs/heads/develop

        """
        let worktrees = parseWorktreeOutput(output)
        XCTAssertEqual(worktrees[0].branch, "develop")
        XCTAssertFalse(worktrees[0].branch?.contains("refs/heads") ?? false)
    }

    func testWorktreeOutputEmptyStringYieldsEmpty() {
        XCTAssertTrue(parseWorktreeOutput("").isEmpty)
    }

    func testWorktreeOutputDetachedHeadNoBranch() {
        let output = """
        worktree /project
        HEAD abc123
        detached

        """
        let worktrees = parseWorktreeOutput(output)
        XCTAssertEqual(worktrees.count, 1)
        XCTAssertNil(worktrees[0].branch)
    }
}

// MARK: - Live adapter tests against real Anvil repo

/// These tests spawn real git processes against the Anvil project repo.
/// They verify that the adapter integrates correctly with git CLI output.
final class GitAdapterLiveTests: XCTestCase {

    /// The Anvil repo path — always exists in CI and dev machines.
    private let repoPath = "/Users/allie/Develop/anvil"

    var adapter: GitSourceControlAdapter!

    override func setUp() async throws {
        adapter = GitSourceControlAdapter(workingDirectory: repoPath)
    }

    override func tearDown() async throws {
        adapter = nil
    }

    // MARK: - validateConnection

    func testValidateConnectionTrueForValidRepo() async throws {
        let valid = try await adapter.validateConnection()
        XCTAssertTrue(valid, "validateConnection must return true for a valid git repo")
    }

    func testValidateConnectionFalseForNonRepo() async throws {
        let nonRepo = GitSourceControlAdapter(workingDirectory: "/tmp")
        let valid = try await nonRepo.validateConnection()
        XCTAssertFalse(valid, "validateConnection must return false for a non-git directory")
    }

    // MARK: - branches

    func testBranchesReturnsAtLeastOneBranch() async throws {
        let branches = try await adapter.branches()
        XCTAssertFalse(branches.isEmpty, "Anvil repo must have at least one branch")
    }

    func testBranchesContainsMasterOrMain() async throws {
        let branches = try await adapter.branches()
        let names = branches.map(\.name)
        let hasMainline = names.contains("master") || names.contains("main")
        XCTAssertTrue(hasMainline, "Repo must have a master or main branch")
    }

    func testBranchesExactlyOneCurrentBranch() async throws {
        let branches = try await adapter.branches()
        let currentBranches = branches.filter(\.isCurrent)
        XCTAssertEqual(currentBranches.count, 1, "Exactly one branch must be marked as current")
    }

    func testBranchesAheadBehindAreNonNegative() async throws {
        let branches = try await adapter.branches()
        for branch in branches {
            XCTAssertGreaterThanOrEqual(branch.aheadCount, 0, "\(branch.name) aheadCount must be >= 0")
            XCTAssertGreaterThanOrEqual(branch.behindCount, 0, "\(branch.name) behindCount must be >= 0")
        }
    }

    func testBranchNamesAreNonEmpty() async throws {
        let branches = try await adapter.branches()
        for branch in branches {
            XCTAssertFalse(branch.name.isEmpty, "Branch name must not be empty")
        }
    }

    // MARK: - currentBranch

    func testCurrentBranchIsNonNil() async throws {
        let current = try await adapter.currentBranch()
        XCTAssertNotNil(current, "currentBranch must return a value for a repo with a checked-out branch")
    }

    func testCurrentBranchMatchesBranchListCurrentEntry() async throws {
        let current = try await adapter.currentBranch()
        let branches = try await adapter.branches()
        let listedCurrent = branches.first(where: \.isCurrent)
        XCTAssertEqual(current?.name, listedCurrent?.name,
                       "currentBranch name must match the branch marked isCurrent in branches()")
    }

    func testCurrentBranchIsMarkedAsCurrent() async throws {
        let current = try await adapter.currentBranch()
        XCTAssertTrue(current?.isCurrent ?? false, "currentBranch result must have isCurrent = true")
    }

    // MARK: - commits

    func testCommitsReturnsRequestedLimit() async throws {
        let current = try await adapter.currentBranch()
        guard let branchName = current?.name else {
            XCTFail("No current branch")
            return
        }
        let commits = try await adapter.commits(branch: branchName, limit: 5)
        XCTAssertLessThanOrEqual(commits.count, 5, "commits() must not exceed the requested limit")
        XCTAssertGreaterThan(commits.count, 0, "Anvil repo must have commits")
    }

    func testCommitFieldsArePopulated() async throws {
        let current = try await adapter.currentBranch()
        guard let branchName = current?.name else { return }
        let commits = try await adapter.commits(branch: branchName, limit: 1)
        guard let commit = commits.first else {
            XCTFail("Expected at least one commit")
            return
        }
        XCTAssertFalse(commit.id.isEmpty, "Commit hash must not be empty")
        XCTAssertFalse(commit.shortHash.isEmpty, "Short hash must not be empty")
        XCTAssertFalse(commit.author.isEmpty, "Author must not be empty")
        XCTAssertFalse(commit.message.isEmpty, "Commit message must not be empty")
    }

    func testCommitsWithZeroLimitReturnsEmpty() async throws {
        let current = try await adapter.currentBranch()
        guard let branchName = current?.name else { return }
        let commits = try await adapter.commits(branch: branchName, limit: 0)
        XCTAssertTrue(commits.isEmpty, "limit: 0 must return empty commits array")
    }

    // MARK: - workingTreeStatus (no crash, returns typed results)

    func testWorkingTreeStatusDoesNotThrow() async throws {
        let changes = try await adapter.workingTreeStatus()
        // All changes must have non-empty file paths
        for change in changes {
            XCTAssertFalse(change.filePath.isEmpty, "File path must not be empty")
        }
    }

    // MARK: - worktrees

    func testWorktreesReturnsAtLeastOneEntry() async throws {
        let worktrees = try await adapter.worktrees()
        XCTAssertFalse(worktrees.isEmpty, "worktrees() must return at least the main worktree")
    }

    func testWorktreesMainEntryExists() async throws {
        let worktrees = try await adapter.worktrees()
        let hasMain = worktrees.contains(where: { $0.isMain || ($0.branch == "master" || $0.branch == "main") })
        XCTAssertTrue(hasMain, "At least one worktree must be the main/master worktree")
    }

    func testWorktreePathsAreNonEmpty() async throws {
        let worktrees = try await adapter.worktrees()
        for wt in worktrees {
            XCTAssertFalse(wt.path.isEmpty, "Worktree path must not be empty")
        }
    }
}
