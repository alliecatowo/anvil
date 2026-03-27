import XCTest
@testable import AnvilGit
import AnvilDomain

final class AnvilGitTests: XCTestCase {
    func testDiffParserEmptyDiff() {
        let parser = DiffParser()
        let result = parser.parse("")
        XCTAssertTrue(result.isEmpty)
    }

    func testDiffParserSingleFile() {
        let parser = DiffParser()
        let diff = """
        diff --git a/test.swift b/test.swift
        index abc1234..def5678 100644
        --- a/test.swift
        +++ b/test.swift
        @@ -1,3 +1,4 @@
         line one
        -line two
        +line two modified
        +line three new
         line four
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.filePath, "test.swift")
    }

    func testDiffParserDetectsAddedFile() {
        let parser = DiffParser()
        let diff = """
        diff --git a/new.swift b/new.swift
        new file mode 100644
        index 0000000..abc1234
        --- /dev/null
        +++ b/new.swift
        @@ -0,0 +1,3 @@
        +line one
        +line two
        +line three
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.status, .added)
    }

    func testDiffParserDetectsDeletedFile() {
        let parser = DiffParser()
        let diff = """
        diff --git a/old.swift b/old.swift
        deleted file mode 100644
        index abc1234..0000000
        --- a/old.swift
        +++ /dev/null
        @@ -1,2 +0,0 @@
        -line one
        -line two
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.status, .deleted)
    }

    func testDiffParserMultipleFiles() {
        let parser = DiffParser()
        let diff = """
        diff --git a/file1.swift b/file1.swift
        index abc1234..def5678 100644
        --- a/file1.swift
        +++ b/file1.swift
        @@ -1,2 +1,2 @@
         unchanged
        -old line
        +new line
        diff --git a/file2.swift b/file2.swift
        index 111..222 100644
        --- a/file2.swift
        +++ b/file2.swift
        @@ -1,1 +1,2 @@
         existing
        +added
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].filePath, "file1.swift")
        XCTAssertEqual(result[1].filePath, "file2.swift")
    }

    func testDiffParserBinaryFile() {
        let parser = DiffParser()
        let diff = """
        diff --git a/image.png b/image.png
        index abc..def 100644
        Binary files a/image.png and b/image.png differ
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first?.isBinary ?? false)
    }

    func testDiffParserHunkLineNumbers() {
        let parser = DiffParser()
        let diff = """
        diff --git a/test.swift b/test.swift
        index abc..def 100644
        --- a/test.swift
        +++ b/test.swift
        @@ -10,3 +10,4 @@
         context
        -removed
        +added1
        +added2
         context2
        """
        let result = parser.parse(diff)
        XCTAssertEqual(result.count, 1)

        let hunks = result.first?.hunks ?? []
        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunks.first?.oldStart, 10)
        XCTAssertEqual(hunks.first?.newStart, 10)

        let lines = hunks.first?.lines ?? []
        XCTAssertEqual(lines.count, 5)
        XCTAssertEqual(lines[0].type, .context)
        XCTAssertEqual(lines[1].type, .removed)
        XCTAssertEqual(lines[2].type, .added)
        XCTAssertEqual(lines[3].type, .added)
        XCTAssertEqual(lines[4].type, .context)
    }

    func testGraphBuilderEmptyCommits() {
        let builder = GitGraphBuilder()
        let graph = builder.buildGraph(from: [], headRef: nil)
        XCTAssertTrue(graph.nodes.isEmpty)
        XCTAssertEqual(graph.maxColumns, 0)
    }

    func testGraphBuilderLinearHistory() {
        let builder = GitGraphBuilder()
        let commits = [
            makeCommit(id: "c3", parents: ["c2"]),
            makeCommit(id: "c2", parents: ["c1"]),
            makeCommit(id: "c1", parents: []),
        ]
        let graph = builder.buildGraph(from: commits, headRef: "c3")
        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertTrue(graph.nodes[0].isHead)
        // Linear history should stay in column 0
        XCTAssertEqual(graph.nodes[0].column, 0)
        XCTAssertEqual(graph.nodes[1].column, 0)
        XCTAssertEqual(graph.nodes[2].column, 0)
    }

    func testGraphBuilderMergeCommit() {
        let builder = GitGraphBuilder()
        let commits = [
            makeCommit(id: "merge", parents: ["c2", "c3"]),
            makeCommit(id: "c2", parents: ["c1"]),
            makeCommit(id: "c3", parents: ["c1"]),
            makeCommit(id: "c1", parents: []),
        ]
        let graph = builder.buildGraph(from: commits, headRef: nil)
        XCTAssertEqual(graph.nodes.count, 4)
        // Merge commit's second parent should be in a different column
        XCTAssertTrue(graph.maxColumns >= 2)
    }

    // MARK: - Helpers

    private func makeCommit(id: String, parents: [String]) -> Commit {
        Commit(
            id: id,
            shortHash: String(id.prefix(7)),
            author: "Test",
            authorEmail: "test@test.com",
            date: Date(),
            message: "commit \(id)",
            parents: parents
        )
    }
}
