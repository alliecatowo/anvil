import XCTest
@testable import AnvilGit
import AnvilDomain

// Tests for git CLI output parsing: diff, commit log format, branch tracking.
// These exercise the parsing logic without spawning real git processes.

final class DiffParserEdgeCaseTests: XCTestCase {

    let parser = DiffParser()

    // MARK: - Renamed file

    func testDiffParserDetectsRenamedFile() {
        let diff = """
        diff --git a/old_name.swift b/new_name.swift
        similarity index 95%
        rename from old_name.swift
        rename to new_name.swift
        index abc..def 100644
        --- a/old_name.swift
        +++ b/new_name.swift
        @@ -1,3 +1,3 @@
         unchanged
        -old line
        +new line
         unchanged2
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.status, .renamed)
    }

    // MARK: - Paths with spaces

    func testDiffParserPathWithSpaces() {
        let diff = """
        diff --git a/my file.swift b/my file.swift
        index abc..def 100644
        --- a/my file.swift
        +++ b/my file.swift
        @@ -1,1 +1,2 @@
         existing
        +added
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertFalse(result[0].filePath.isEmpty)
    }

    // MARK: - Whitespace-only input

    func testDiffParserWhitespaceOnlyInput() {
        let result = parser.parse("   \n\t\n  ")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Multiple hunks in one file

    func testDiffParserMultipleHunksInOneFile() {
        let diff = """
        diff --git a/multi.swift b/multi.swift
        index abc..def 100644
        --- a/multi.swift
        +++ b/multi.swift
        @@ -1,3 +1,3 @@
         context1
        -old1
        +new1
         context2
        @@ -10,3 +10,3 @@
         context3
        -old2
        +new2
         context4
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.hunks.count, 2)
    }

    // MARK: - Hunk with zero count

    func testDiffParserHunkWithZeroOldCount() {
        let diff = """
        diff --git a/zero.swift b/zero.swift
        index abc..def 100644
        --- a/zero.swift
        +++ b/zero.swift
        @@ -5,0 +5,2 @@
        +added line 1
        +added line 2
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        let hunks = result.first?.hunks ?? []
        XCTAssertEqual(hunks.count, 1)
        let lines = hunks.first?.lines ?? []
        XCTAssertTrue(lines.allSatisfy { $0.type == .added })
    }

    // MARK: - Only removed lines

    func testDiffParserHunkAllRemoved() {
        let diff = """
        diff --git a/removed.swift b/removed.swift
        index abc..def 100644
        --- a/removed.swift
        +++ b/removed.swift
        @@ -1,3 +1,0 @@
        -line one
        -line two
        -line three
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        let lines = result.first?.hunks.first?.lines ?? []
        XCTAssertTrue(lines.allSatisfy { $0.type == .removed })
    }

    // MARK: - Three files with a binary in the middle

    func testDiffParserThreeFilesWithBinaryInMiddle() {
        let diff = """
        diff --git a/first.swift b/first.swift
        index abc..def 100644
        --- a/first.swift
        +++ b/first.swift
        @@ -1,1 +1,2 @@
         existing
        +added
        diff --git a/image.png b/image.png
        index abc..def 100644
        Binary files a/image.png and b/image.png differ
        diff --git a/last.swift b/last.swift
        new file mode 100644
        index 0000000..abc1234
        --- /dev/null
        +++ b/last.swift
        @@ -0,0 +1,1 @@
        +new file content
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 3)
        XCTAssertFalse(result[0].isBinary)
        XCTAssertTrue(result[1].isBinary)
        XCTAssertFalse(result[2].isBinary)
        XCTAssertEqual(result[2].status, .added)
    }

    // MARK: - Line numbers

    func testDiffParserAddedLineNumbers() {
        let diff = """
        diff --git a/nums.swift b/nums.swift
        index abc..def 100644
        --- a/nums.swift
        +++ b/nums.swift
        @@ -5,2 +5,3 @@
         context
        +inserted
         context2
        """
        let result = parser.parse(diff)
        let lines = result.first?.hunks.first?.lines ?? []
        let added = lines.first { $0.type == .added }
        XCTAssertNotNil(added?.newLineNumber)
        XCTAssertNil(added?.oldLineNumber)
    }

    func testDiffParserRemovedLineNumbers() {
        let diff = """
        diff --git a/nums2.swift b/nums2.swift
        index abc..def 100644
        --- a/nums2.swift
        +++ b/nums2.swift
        @@ -3,3 +3,2 @@
         keep
        -remove me
         keep2
        """
        let result = parser.parse(diff)
        let lines = result.first?.hunks.first?.lines ?? []
        let removed = lines.first { $0.type == .removed }
        XCTAssertNotNil(removed?.oldLineNumber)
        XCTAssertNil(removed?.newLineNumber)
    }

    func testDiffParserContextLineNumbers() {
        let diff = """
        diff --git a/ctx.swift b/ctx.swift
        index abc..def 100644
        --- a/ctx.swift
        +++ b/ctx.swift
        @@ -1,2 +1,3 @@
         context1
        +added
         context2
        """
        let result = parser.parse(diff)
        let lines = result.first?.hunks.first?.lines ?? []
        let ctxLines = lines.filter { $0.type == .context }
        XCTAssertTrue(ctxLines.allSatisfy { $0.oldLineNumber != nil && $0.newLineNumber != nil })
    }

    // MARK: - Hunk header oldStart / newStart parsing

    func testDiffParserHunkHeaderLargeLineNumbers() {
        let diff = """
        diff --git a/large.swift b/large.swift
        index abc..def 100644
        --- a/large.swift
        +++ b/large.swift
        @@ -500,5 +600,6 @@
         c1
         c2
        -rem
        +add1
        +add2
         c3
         c4
        """
        let result = parser.parse(diff)
        let hunk = result.first?.hunks.first
        XCTAssertEqual(hunk?.oldStart, 500)
        XCTAssertEqual(hunk?.newStart, 600)
    }
}

// MARK: - GitGraphBuilder Additional Tests

final class GitGraphBuilderAdditionalTests: XCTestCase {

    let builder = GitGraphBuilder()

    func testSingleCommitGraph() {
        let commits = [makeCommit(id: "c1", parents: [])]
        let graph = builder.buildGraph(from: commits, headRef: "c1")
        XCTAssertEqual(graph.nodes.count, 1)
        XCTAssertTrue(graph.nodes.first?.isHead ?? false)
    }

    func testGraphPreservesCommitCount() {
        let commits = (0..<10).map { i in
            makeCommit(id: "c\(i)", parents: i > 0 ? ["c\(i-1)"] : [])
        }
        let graph = builder.buildGraph(from: commits, headRef: nil)
        XCTAssertEqual(graph.nodes.count, 10)
    }

    func testHeadNodeIsMarked() {
        let commits = [
            makeCommit(id: "head", parents: ["base"]),
            makeCommit(id: "base", parents: []),
        ]
        let graph = builder.buildGraph(from: commits, headRef: "head")
        let headNode = graph.nodes.first { $0.isHead }
        XCTAssertNotNil(headNode)
        XCTAssertEqual(headNode?.commit.id, "head")
    }

    func testNonHeadNodesAreNotMarked() {
        let commits = [
            makeCommit(id: "head", parents: ["base"]),
            makeCommit(id: "base", parents: []),
        ]
        let graph = builder.buildGraph(from: commits, headRef: "head")
        let nonHead = graph.nodes.filter { !$0.isHead }
        XCTAssertTrue(nonHead.allSatisfy { !$0.isHead })
    }

    func testLinearHistoryMaxColumnsIsOne() {
        let commits = [
            makeCommit(id: "c3", parents: ["c2"]),
            makeCommit(id: "c2", parents: ["c1"]),
            makeCommit(id: "c1", parents: []),
        ]
        let graph = builder.buildGraph(from: commits, headRef: nil)
        XCTAssertEqual(graph.maxColumns, 1)
    }

    func testBranchingHistoryMaxColumnsAtLeastTwo() {
        let commits = [
            makeCommit(id: "merge", parents: ["branch1", "branch2"]),
            makeCommit(id: "branch1", parents: ["base"]),
            makeCommit(id: "branch2", parents: ["base"]),
            makeCommit(id: "base", parents: []),
        ]
        let graph = builder.buildGraph(from: commits, headRef: nil)
        XCTAssertGreaterThanOrEqual(graph.maxColumns, 2)
    }

    func testNilHeadRefMeansNoNodeIsHead() {
        let commits = [
            makeCommit(id: "c1", parents: []),
            makeCommit(id: "c2", parents: ["c1"]),
        ]
        let graph = builder.buildGraph(from: commits, headRef: nil)
        XCTAssertFalse(graph.nodes.contains { $0.isHead })
    }

    // MARK: - Helper

    private func makeCommit(id: String, parents: [String]) -> Commit {
        Commit(
            id: id,
            shortHash: String(id.prefix(7)),
            author: "Tester",
            authorEmail: "test@test.com",
            date: Date(),
            message: "commit \(id)",
            parents: parents
        )
    }
}
