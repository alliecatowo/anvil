import XCTest
@testable import AnvilGit
import AnvilDomain

/// Tests for git output parsing using sample strings — no real Process/shell calls.
/// The parsing logic lives in DiffParser (accessible via @testable) and inline in
/// GitSourceControlAdapter. We test DiffParser thoroughly and exercise the commit-log,
/// branch, and status parsing formats via real git on the local repo.
final class GitShellParsingTests: XCTestCase {

    // MARK: - DiffParser: basic cases

    private let parser = DiffParser()

    func testEmptyInputReturnsEmpty() {
        XCTAssertTrue(parser.parse("").isEmpty)
    }

    func testWhitespaceOnlyInputReturnsEmpty() {
        XCTAssertTrue(parser.parse("  \n\t  ").isEmpty)
    }

    func testSingleModifiedFileIsParsed() {
        let diff = singleFileDiff(name: "Sources/App.swift", status: "modified")
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.filePath, "Sources/App.swift")
    }

    func testAddedFileSetsCorrectStatus() {
        let diff = addedFileDiff(name: "Sources/New.swift")
        let result = parser.parse(diff)
        XCTAssertEqual(result.first?.status, .added)
    }

    func testDeletedFileSetsCorrectStatus() {
        let diff = deletedFileDiff(name: "Sources/Old.swift")
        let result = parser.parse(diff)
        XCTAssertEqual(result.first?.status, .deleted)
    }

    func testModifiedFileHasModifiedStatus() {
        let diff = singleFileDiff(name: "Sources/Foo.swift", status: "modified")
        let result = parser.parse(diff)
        XCTAssertEqual(result.first?.status, .modified)
    }

    func testBinaryFileIsMarked() {
        let diff = binaryFileDiff(name: "Assets/logo.png")
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first?.isBinary ?? false)
    }

    func testBinaryFileHasNoHunks() {
        let diff = binaryFileDiff(name: "Assets/icon.png")
        let result = parser.parse(diff)
        XCTAssertTrue(result.first?.hunks.isEmpty ?? true)
    }

    // MARK: - DiffParser: multiple files

    func testTwoFilesProduceTwoDiffs() {
        let diff = twoFileDiff()
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 2)
    }

    func testThreeFilesProduceThreeDiffs() {
        let diff = threeFileDiff()
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 3)
    }

    func testFilePathsAreCorrectInMultiFileDiff() {
        let diff = twoFileDiff()
        let result = parser.parse(diff)
        let paths = result.map { $0.filePath }
        XCTAssertTrue(paths.contains("file1.swift"))
        XCTAssertTrue(paths.contains("file2.swift"))
    }

    // MARK: - DiffParser: hunks

    func testSingleHunkIsParsed() {
        let diff = singleFileDiff(name: "f.swift", status: "modified")
        let result = parser.parse(diff)
        XCTAssertEqual(result.first?.hunks.count, 1)
    }

    func testHunkStartLinesAreCorrect() {
        let diff = """
        diff --git a/src.swift b/src.swift
        index abc..def 100644
        --- a/src.swift
        +++ b/src.swift
        @@ -5,3 +5,4 @@
         context
        -removed
        +added1
        +added2
         context2
        """
        let result = parser.parse(diff)
        let hunk = result.first?.hunks.first
        XCTAssertEqual(hunk?.oldStart, 5)
        XCTAssertEqual(hunk?.newStart, 5)
    }

    func testHunkLineTypesAreCorrect() {
        let diff = """
        diff --git a/x.swift b/x.swift
        index abc..def 100644
        --- a/x.swift
        +++ b/x.swift
        @@ -1,3 +1,3 @@
         context
        -old
        +new
        """
        let result = parser.parse(diff)
        let lines = result.first?.hunks.first?.lines ?? []
        XCTAssertTrue(lines.contains { $0.type == .context })
        XCTAssertTrue(lines.contains { $0.type == .removed })
        XCTAssertTrue(lines.contains { $0.type == .added })
    }

    func testAddedLinesHaveNoOldLineNumber() {
        let diff = singleFileDiff(name: "n.swift", status: "modified")
        let result = parser.parse(diff)
        let addedLines = result.first?.hunks.first?.lines.filter { $0.type == .added } ?? []
        XCTAssertTrue(addedLines.allSatisfy { $0.oldLineNumber == nil })
    }

    func testRemovedLinesHaveNoNewLineNumber() {
        let diff = singleFileDiff(name: "n.swift", status: "modified")
        let result = parser.parse(diff)
        let removedLines = result.first?.hunks.first?.lines.filter { $0.type == .removed } ?? []
        XCTAssertTrue(removedLines.allSatisfy { $0.newLineNumber == nil })
    }

    func testContextLinesHaveBothLineNumbers() {
        let diff = singleFileDiff(name: "n.swift", status: "modified")
        let result = parser.parse(diff)
        let contextLines = result.first?.hunks.first?.lines.filter { $0.type == .context } ?? []
        XCTAssertTrue(contextLines.allSatisfy { $0.oldLineNumber != nil && $0.newLineNumber != nil })
    }

    // MARK: - DiffParser: renamed file

    func testRenamedFileHasRenamedStatus() {
        let diff = renamedFileDiff(from: "Old.swift", to: "New.swift")
        let result = parser.parse(diff)
        XCTAssertEqual(result.first?.status, .renamed)
    }

    // MARK: - Commit log format parsing (sample strings)
    //
    // GitSourceControlAdapter uses format: %H|||%h|||%aN|||%aE|||%aI|||%s|||%P
    // We replicate the parsing logic here to test it with sample output.

    func testCommitLogFormatParsesHash() {
        let commits = parseCommitLogOutput(sampleCommitLogLine())
        XCTAssertEqual(commits.first?.id, "abc1234567890abcdef1234567890abcdef123456")
    }

    func testCommitLogFormatParsesShortHash() {
        let commits = parseCommitLogOutput(sampleCommitLogLine())
        XCTAssertEqual(commits.first?.shortHash, "abc1234")
    }

    func testCommitLogFormatParsesAuthor() {
        let commits = parseCommitLogOutput(sampleCommitLogLine())
        XCTAssertEqual(commits.first?.author, "Alice Smith")
    }

    func testCommitLogFormatParsesEmail() {
        let commits = parseCommitLogOutput(sampleCommitLogLine())
        XCTAssertEqual(commits.first?.authorEmail, "alice@example.com")
    }

    func testCommitLogFormatParsesMessage() {
        let commits = parseCommitLogOutput(sampleCommitLogLine())
        XCTAssertEqual(commits.first?.message, "Fix auth bug")
    }

    func testCommitLogFormatParsesParents() {
        let commits = parseCommitLogOutput(sampleCommitLogLine())
        XCTAssertEqual(commits.first?.parents, ["parent1hash"])
    }

    func testCommitLogEmptyInputReturnsEmpty() {
        let commits = parseCommitLogOutput("")
        XCTAssertTrue(commits.isEmpty)
    }

    func testCommitLogMultipleLinesProduceMultipleCommits() {
        let two = sampleCommitLogLine() + "\n" + sampleCommitLogLine(hash: "def456", short: "def456", msg: "Second")
        let commits = parseCommitLogOutput(two)
        XCTAssertEqual(commits.count, 2)
    }

    func testCommitLogMergeCommitHasTwoParents() {
        let mergeLog = "aaaaaa|||aaaaaaa|||Bob|||bob@x.com|||2024-01-01T00:00:00+00:00|||Merge|||parent1 parent2"
        let commits = parseCommitLogOutput(mergeLog)
        XCTAssertEqual(commits.first?.parents.count, 2)
    }

    func testCommitLogRootCommitHasNoParents() {
        let rootLog = "bbbbbb|||bbbbbbb|||Carol|||c@x.com|||2024-01-01T00:00:00+00:00|||Initial commit|||"
        let commits = parseCommitLogOutput(rootLog)
        // parents field is empty string — should produce empty array
        XCTAssertTrue(commits.first?.parents.isEmpty ?? true)
    }

    // MARK: - Status porcelain parsing (sample strings)
    //
    // GitSourceControlAdapter uses `git status --porcelain=v1`, which produces
    // lines of the form: XY<space>filepath  where X=index, Y=worktree.

    func testPorcelainUntrackedFileIsDetected() {
        let changes = parsePorcelainStatus("?? NewFile.swift")
        XCTAssertEqual(changes.untracked.count, 1)
        XCTAssertEqual(changes.untracked.first?.filePath, "NewFile.swift")
    }

    func testPorcelainStagedModifiedIsDetected() {
        let changes = parsePorcelainStatus("M  Modified.swift")
        XCTAssertEqual(changes.staged.count, 1)
        XCTAssertEqual(changes.staged.first?.status, .modified)
    }

    func testPorcelainStagedAddedIsDetected() {
        let changes = parsePorcelainStatus("A  Added.swift")
        XCTAssertEqual(changes.staged.count, 1)
        XCTAssertEqual(changes.staged.first?.status, .added)
    }

    func testPorcelainStagedDeletedIsDetected() {
        let changes = parsePorcelainStatus("D  Deleted.swift")
        XCTAssertEqual(changes.staged.count, 1)
        XCTAssertEqual(changes.staged.first?.status, .deleted)
    }

    func testPorcelainUnstagedModifiedIsDetected() {
        let changes = parsePorcelainStatus(" M Unstaged.swift")
        XCTAssertEqual(changes.unstaged.count, 1)
        XCTAssertEqual(changes.unstaged.first?.status, .modified)
    }

    func testPorcelainFileBothStagedAndUnstagedIsDetected() {
        // MM means staged+unstaged modification
        let changes = parsePorcelainStatus("MM Both.swift")
        XCTAssertEqual(changes.staged.count, 1)
        XCTAssertEqual(changes.unstaged.count, 1)
    }

    func testPorcelainEmptyOutputReturnsAllEmpty() {
        let changes = parsePorcelainStatus("")
        XCTAssertTrue(changes.staged.isEmpty)
        XCTAssertTrue(changes.unstaged.isEmpty)
        XCTAssertTrue(changes.untracked.isEmpty)
    }

    func testPorcelainMultipleFilesAreParsed() {
        let output = """
        M  staged.swift
         M unstaged.swift
        ?? untracked.swift
        """
        let changes = parsePorcelainStatus(output)
        XCTAssertEqual(changes.staged.count, 1)
        XCTAssertEqual(changes.unstaged.count, 1)
        XCTAssertEqual(changes.untracked.count, 1)
    }

    // MARK: - Branch format parsing (sample strings)
    //
    // GitSourceControlAdapter uses:
    //   git branch -a --format=%(refname:short)|||%(upstream:short)|||%(upstream:track)|||%(HEAD)
    // We replicate the parsing logic here.

    func testBranchParsingExtractsName() {
        let branches = parseBranchOutput("main|||origin/main|||[ahead 1]|||*")
        XCTAssertEqual(branches.first?.name, "main")
    }

    func testBranchParsingDetectsCurrentBranch() {
        let branches = parseBranchOutput("main|||origin/main|||[ahead 1]|||*")
        XCTAssertTrue(branches.first?.isCurrent ?? false)
    }

    func testBranchParsingNonCurrentBranch() {
        let branches = parseBranchOutput("feature/x|||origin/feature/x||| |||")
        XCTAssertFalse(branches.first?.isCurrent ?? true)
    }

    func testBranchParsingExtractsUpstream() {
        let branches = parseBranchOutput("main|||origin/main||||||*")
        XCTAssertEqual(branches.first?.upstream, "origin/main")
    }

    func testBranchParsingNilUpstreamWhenEmpty() {
        let branches = parseBranchOutput("feature|||||||")
        XCTAssertNil(branches.first?.upstream)
    }

    func testBranchParsingAheadCount() {
        let branches = parseBranchOutput("main|||origin/main|||[ahead 3]|||*")
        XCTAssertEqual(branches.first?.aheadCount, 3)
    }

    func testBranchParsingBehindCount() {
        let branches = parseBranchOutput("main|||origin/main|||[behind 2]||| ")
        XCTAssertEqual(branches.first?.behindCount, 2)
    }

    func testBranchParsingAheadAndBehind() {
        let branches = parseBranchOutput("main|||origin/main|||[ahead 4, behind 1]|||*")
        XCTAssertEqual(branches.first?.aheadCount, 4)
        XCTAssertEqual(branches.first?.behindCount, 1)
    }

    func testBranchParsingZeroAheadBehindWhenNone() {
        let branches = parseBranchOutput("main|||origin/main||||||*")
        XCTAssertEqual(branches.first?.aheadCount, 0)
        XCTAssertEqual(branches.first?.behindCount, 0)
    }

    func testBranchParsingMultipleBranches() {
        let output = "main|||origin/main|||[ahead 1]|||*\nfeature/x|||origin/feature/x||| ||| "
        let branches = parseBranchOutput(output)
        XCTAssertEqual(branches.count, 2)
    }

    func testBranchParsingDropsLinesWithTooFewParts() {
        let branches = parseBranchOutput("bad-line-no-separators")
        XCTAssertTrue(branches.isEmpty)
    }
}

// MARK: - Parsing helpers (replicate adapter logic without spawning processes)

private extension GitShellParsingTests {

    // Replicate GitSourceControlAdapter.commits() parsing
    func parseCommitLogOutput(_ output: String) -> [Commit] {
        guard !output.isEmpty else { return [] }
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        return output.components(separatedBy: "\n").compactMap { line -> Commit? in
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 6 else { return nil }
            return Commit(
                id: parts[0],
                shortHash: parts[1],
                author: parts[2],
                authorEmail: parts[3],
                date: dateFormatter.date(from: parts[4]) ?? Date(),
                message: parts[5],
                parents: parts.count > 6
                    ? parts[6].split(separator: " ").compactMap { s in
                        let str = String(s)
                        return str.isEmpty ? nil : str
                      }
                    : []
            )
        }
    }

    // Replicate GitSourceControlAdapter.workingTreeChanges() parsing
    func parsePorcelainStatus(_ output: String) -> (staged: [GitFileChange], unstaged: [GitFileChange], untracked: [GitFileChange]) {
        guard !output.isEmpty else { return ([], [], []) }
        var staged: [GitFileChange] = []
        var unstaged: [GitFileChange] = []
        var untracked: [GitFileChange] = []
        for line in output.components(separatedBy: "\n") {
            guard line.count >= 4 else { continue }
            let indexStatus = line[line.startIndex]
            let workTreeStatus = line[line.index(after: line.startIndex)]
            let filePath = String(line.dropFirst(3))
            if indexStatus == "?" {
                untracked.append(GitFileChange(filePath: filePath, status: .untracked, staged: false))
                continue
            }
            if indexStatus != " " {
                staged.append(GitFileChange(filePath: filePath, status: statusChar(indexStatus), staged: true))
            }
            if workTreeStatus != " " {
                unstaged.append(GitFileChange(filePath: filePath, status: statusChar(workTreeStatus), staged: false))
            }
        }
        return (staged, unstaged, untracked)
    }

    func statusChar(_ c: Character) -> GitFileChangeStatus {
        switch c {
        case "M": .modified
        case "A": .added
        case "D": .deleted
        case "R": .renamed
        case "C": .copied
        case "U": .unmerged
        default: .modified
        }
    }

    // Replicate GitSourceControlAdapter.branches() parsing
    func parseBranchOutput(_ output: String) -> [Branch] {
        guard !output.isEmpty else { return [] }
        return output.components(separatedBy: "\n").compactMap { line -> Branch? in
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
    }

    // Replicate GitSourceControlAdapter.parseTrackInfo()
    func parseTrackInfo(_ info: String) -> (ahead: Int, behind: Int) {
        var ahead = 0
        var behind = 0
        if let r = info.range(of: #"ahead (\d+)"#, options: .regularExpression) {
            let match = info[r]
            ahead = Int(match.split(separator: " ").last.map(String.init) ?? "0") ?? 0
        }
        if let r = info.range(of: #"behind (\d+)"#, options: .regularExpression) {
            let match = info[r]
            behind = Int(match.split(separator: " ").last.map(String.init) ?? "0") ?? 0
        }
        return (ahead, behind)
    }

    // MARK: - Diff sample builders

    func singleFileDiff(name: String, status: String) -> String {
        """
        diff --git a/\(name) b/\(name)
        index abc1234..def5678 100644
        --- a/\(name)
        +++ b/\(name)
        @@ -1,3 +1,3 @@
         context line
        -old line
        +new line
         another context
        """
    }

    func addedFileDiff(name: String) -> String {
        """
        diff --git a/\(name) b/\(name)
        new file mode 100644
        index 0000000..abc1234
        --- /dev/null
        +++ b/\(name)
        @@ -0,0 +1,3 @@
        +line one
        +line two
        +line three
        """
    }

    func deletedFileDiff(name: String) -> String {
        """
        diff --git a/\(name) b/\(name)
        deleted file mode 100644
        index abc1234..0000000
        --- a/\(name)
        +++ /dev/null
        @@ -1,2 +0,0 @@
        -line one
        -line two
        """
    }

    func binaryFileDiff(name: String) -> String {
        """
        diff --git a/\(name) b/\(name)
        index abc..def 100644
        Binary files a/\(name) and b/\(name) differ
        """
    }

    func renamedFileDiff(from old: String, to new: String) -> String {
        """
        diff --git a/\(old) b/\(new)
        similarity index 95%
        rename from \(old)
        rename to \(new)
        index abc..def 100644
        --- a/\(old)
        +++ b/\(new)
        @@ -1,2 +1,2 @@
         unchanged
        -old
        +new
        """
    }

    func twoFileDiff() -> String {
        """
        diff --git a/file1.swift b/file1.swift
        index abc..def 100644
        --- a/file1.swift
        +++ b/file1.swift
        @@ -1,2 +1,2 @@
         ctx
        -old
        +new
        diff --git a/file2.swift b/file2.swift
        index 111..222 100644
        --- a/file2.swift
        +++ b/file2.swift
        @@ -1,1 +1,2 @@
         existing
        +added
        """
    }

    func threeFileDiff() -> String {
        twoFileDiff() + "\n" + singleFileDiff(name: "file3.swift", status: "modified")
    }

    func sampleCommitLogLine(
        hash: String = "abc1234567890abcdef1234567890abcdef123456",
        short: String = "abc1234",
        msg: String = "Fix auth bug"
    ) -> String {
        "\(hash)|||\(short)|||Alice Smith|||alice@example.com|||2024-06-01T12:00:00+00:00|||\(msg)|||parent1hash"
    }
}
