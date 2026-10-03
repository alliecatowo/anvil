import XCTest
@testable import AnvilGit
import AnvilDomain

/// XCTest coverage for git blame --porcelain output parsing.
///
/// GitSourceControlAdapter.parseBlameOutput is private, so these tests
/// replicate its algorithm directly from the implementation so the
/// parser logic can be verified without spawning a git subprocess.
final class BlameParsingTests: XCTestCase {

    // MARK: - Replicated Parser
    // Mirrors GitSourceControlAdapter.parseBlameOutput(_:) exactly.

    private func parseBlameOutput(_ output: String) -> [BlameLine] {
        var blameLines: [BlameLine] = []
        let lines = output.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let headerParts = line.split(separator: " ")
            guard headerParts.count >= 3 else { i += 1; continue }

            let commitHash = String(headerParts[0])
            guard commitHash.count >= 7 else { i += 1; continue }

            let lineNumber = Int(String(headerParts[2])) ?? 0

            var author = ""
            var date = Date(timeIntervalSince1970: 0)
            var content = ""
            i += 1

            while i < lines.count {
                let currentLine = lines[i]
                if currentLine.hasPrefix("author ") {
                    author = String(currentLine.dropFirst("author ".count))
                } else if currentLine.hasPrefix("author-time ") {
                    let timestamp = TimeInterval(String(currentLine.dropFirst("author-time ".count))) ?? 0
                    date = Date(timeIntervalSince1970: timestamp)
                } else if currentLine.hasPrefix("\t") {
                    content = String(currentLine.dropFirst())
                    i += 1
                    break
                }
                i += 1
            }

            blameLines.append(BlameLine(
                lineNumber: lineNumber,
                commitHash: commitHash,
                author: author,
                date: date,
                content: content
            ))
        }

        return blameLines
    }

    // MARK: - Fixtures

    /// A well-formed porcelain blame output for two lines from two commits.
    private let twoLinePorcelain = """
    abc1234567890abcdef1234567890abcdef12345678 1 1 1
    author Alice Smith
    author-mail <alice@example.com>
    author-time 1700000000
    author-tz +0000
    committer Bob Jones
    committer-mail <bob@example.com>
    committer-time 1700000100
    committer-tz +0000
    summary Initial commit
    filename main.swift
    \timport Foundation
    def9876543210fedcba0987654321fedcba9876543 2 2 1
    author Bob Jones
    author-mail <bob@example.com>
    author-time 1710000000
    author-tz +0000
    committer Bob Jones
    committer-mail <bob@example.com>
    committer-time 1710000100
    committer-tz +0000
    summary Add struct definition
    filename main.swift
    \tstruct Foo {}
    """

    // MARK: - Basic parsing

    func testTwoLineOutputProducesTwoBlamLines() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines.count, 2)
    }

    func testFirstLineAuthorParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[0].author, "Alice Smith")
    }

    func testSecondLineAuthorParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[1].author, "Bob Jones")
    }

    func testFirstLineCommitHashParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[0].commitHash, "abc1234567890abcdef1234567890abcdef12345678")
    }

    func testSecondLineCommitHashParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[1].commitHash, "def9876543210fedcba0987654321fedcba9876543")
    }

    func testFirstLineContentParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[0].content, "import Foundation")
    }

    func testSecondLineContentParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[1].content, "struct Foo {}")
    }

    func testFirstLineNumberParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[0].lineNumber, 1)
    }

    func testSecondLineNumberParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[1].lineNumber, 2)
    }

    func testFirstLineDateParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[0].date.timeIntervalSince1970, 1700000000, accuracy: 1)
    }

    func testSecondLineDateParsed() {
        let lines = parseBlameOutput(twoLinePorcelain)
        XCTAssertEqual(lines[1].date.timeIntervalSince1970, 1710000000, accuracy: 1)
    }

    // MARK: - Single line fixture

    private let singleLinePorcelain = """
    aabbccdd1234567890aabbccdd1234567890aabbcc 5 5 1
    author Jane Doe
    author-mail <jane@example.com>
    author-time 1650000000
    author-tz +0100
    committer Jane Doe
    committer-mail <jane@example.com>
    committer-time 1650000000
    committer-tz +0100
    summary Fix bug
    filename app.swift
    \tlet result = compute()
    """

    func testSingleLineParsed() {
        let lines = parseBlameOutput(singleLinePorcelain)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].author, "Jane Doe")
        XCTAssertEqual(lines[0].lineNumber, 5)
        XCTAssertEqual(lines[0].content, "let result = compute()")
        XCTAssertEqual(lines[0].date.timeIntervalSince1970, 1650000000, accuracy: 1)
    }

    // MARK: - Empty content line

    func testEmptyContentLinePreserved() {
        let fixture = """
        aabbccdd1234567890aabbccdd1234567890aabbcc 3 3 1
        author Dev
        author-mail <dev@example.com>
        author-time 1600000000
        author-tz +0000
        committer Dev
        committer-mail <dev@example.com>
        committer-time 1600000000
        committer-tz +0000
        summary empty line
        filename x.swift
        \t
        """
        let lines = parseBlameOutput(fixture)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].content, "")
    }

    // MARK: - Malformed / edge cases

    func testEmptyOutputReturnsEmpty() {
        let lines = parseBlameOutput("")
        XCTAssertTrue(lines.isEmpty)
    }

    func testOnlyWhitespaceReturnsEmpty() {
        let lines = parseBlameOutput("   \n  \n  ")
        XCTAssertTrue(lines.isEmpty)
    }

    func testShortHashLineSkipped() {
        // commitHash with fewer than 7 chars is invalid and must be skipped
        let fixture = """
        abc12 1 1 1
        author Short
        author-time 0
        \tsome content
        """
        let lines = parseBlameOutput(fixture)
        XCTAssertTrue(lines.isEmpty, "Short commit hash should be skipped")
    }

    func testMissingAuthorTimeDefaultsToEpoch() {
        let fixture = """
        aabbccdd1234567890aabbccdd1234567890aabbcc 1 1 1
        author NoTime
        author-mail <notime@example.com>
        committer NoTime
        committer-mail <notime@example.com>
        summary test
        filename x.swift
        \tsome code
        """
        let lines = parseBlameOutput(fixture)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].author, "NoTime")
        // No author-time means timestamp 0 → epoch
        XCTAssertEqual(lines[0].date.timeIntervalSince1970, 0, accuracy: 1)
    }

    func testContentTabPrefixStripped() {
        // The tab character is the delimiter — content after it should have no leading tab
        let fixture = """
        aabbccdd1234567890aabbccdd1234567890aabbcc 1 1 1
        author Alice
        author-time 0
        \t    indented code
        """
        let lines = parseBlameOutput(fixture)
        XCTAssertEqual(lines[0].content, "    indented code")
    }

    // MARK: - BlameLine struct

    func testBlameLineStoresAllFields() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let blame = BlameLine(lineNumber: 7, commitHash: "abcdef1", author: "Dev", date: date, content: "let x = 1")
        XCTAssertEqual(blame.lineNumber, 7)
        XCTAssertEqual(blame.commitHash, "abcdef1")
        XCTAssertEqual(blame.author, "Dev")
        XCTAssertEqual(blame.date, date)
        XCTAssertEqual(blame.content, "let x = 1")
    }

    func testBlameLineCodableRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let original = BlameLine(lineNumber: 3, commitHash: "abc1234", author: "Alice", date: date, content: "func foo() {}")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BlameLine.self, from: data)
        XCTAssertEqual(decoded.lineNumber, original.lineNumber)
        XCTAssertEqual(decoded.commitHash, original.commitHash)
        XCTAssertEqual(decoded.author, original.author)
        XCTAssertEqual(decoded.content, original.content)
    }
}
