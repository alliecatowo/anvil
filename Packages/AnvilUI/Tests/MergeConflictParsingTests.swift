import XCTest
import AnvilDomain

/// XCTest coverage for merge conflict marker parsing.
///
/// GitSourceControlAdapter.parseConflictFile is private and reads from disk.
/// These tests replicate its parsing algorithm (the region state machine) directly,
/// so the logic is verified independently of the file system.
///
/// Conflict format:
///   <<<<<<< HEAD
///   <ours lines>
///   ||||||| base  (optional diff3 base)
///   <base lines>
///   =======
///   <theirs lines>
///   >>>>>>> branch
final class MergeConflictParsingTests: XCTestCase {

    // MARK: - Replicated Parser

    /// Replicates GitSourceControlAdapter.parseConflictFile logic
    /// so we can test the algorithm without a real file on disk.
    private func parseConflictMarkers(
        content: String,
        filePath: String = "test.swift"
    ) -> MergeConflict {
        var oursLines: [String] = []
        var baseLines: [String] = []
        var theirsLines: [String] = []
        var hasBase = false

        enum Region { case outside, ours, base, theirs }
        var region = Region.outside

        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("<<<<<<<") {
                region = .ours
            } else if line.hasPrefix("|||||||") {
                region = .base
                hasBase = true
            } else if line.hasPrefix("=======") {
                region = .theirs
            } else if line.hasPrefix(">>>>>>>") {
                region = .outside
            } else {
                switch region {
                case .outside: break
                case .ours:    oursLines.append(line)
                case .base:    baseLines.append(line)
                case .theirs:  theirsLines.append(line)
                }
            }
        }

        return MergeConflict(
            filePath: filePath,
            oursContent: oursLines.joined(separator: "\n"),
            theirsContent: theirsLines.joined(separator: "\n"),
            baseContent: hasBase ? baseLines.joined(separator: "\n") : nil
        )
    }

    // MARK: - Basic two-way conflict (no base)

    private let twoWayConflict = """
    line before conflict
    <<<<<<< HEAD
    let x = 1
    let y = 2
    =======
    let x = 99
    >>>>>>> feature/new-values
    line after conflict
    """

    func testTwoWayOursContentParsed() {
        let conflict = parseConflictMarkers(content: twoWayConflict)
        XCTAssertTrue(conflict.oursContent.contains("let x = 1"))
        XCTAssertTrue(conflict.oursContent.contains("let y = 2"))
    }

    func testTwoWayTheirsContentParsed() {
        let conflict = parseConflictMarkers(content: twoWayConflict)
        XCTAssertTrue(conflict.theirsContent.contains("let x = 99"))
    }

    func testTwoWayBaseContentIsNil() {
        let conflict = parseConflictMarkers(content: twoWayConflict)
        XCTAssertNil(conflict.baseContent, "Two-way conflict should have no base content")
    }

    func testTwoWayOursDoesNotContainMarkers() {
        let conflict = parseConflictMarkers(content: twoWayConflict)
        XCTAssertFalse(conflict.oursContent.contains("<<<<<<<"))
        XCTAssertFalse(conflict.oursContent.contains("======="))
        XCTAssertFalse(conflict.oursContent.contains(">>>>>>>"))
    }

    func testTwoWayTheirsDoesNotContainMarkers() {
        let conflict = parseConflictMarkers(content: twoWayConflict)
        XCTAssertFalse(conflict.theirsContent.contains("<<<<<<<"))
        XCTAssertFalse(conflict.theirsContent.contains("======="))
        XCTAssertFalse(conflict.theirsContent.contains(">>>>>>>"))
    }

    func testTwoWayLinesOutsideConflictNotIncluded() {
        let conflict = parseConflictMarkers(content: twoWayConflict)
        XCTAssertFalse(conflict.oursContent.contains("line before conflict"))
        XCTAssertFalse(conflict.theirsContent.contains("line after conflict"))
    }

    // MARK: - Three-way conflict (diff3 with |||||||)

    private let threeWayConflict = """
    <<<<<<< HEAD
    func greet() { print("hello") }
    ||||||| base commit
    func greet() { print("hi") }
    =======
    func greet() { print("howdy") }
    >>>>>>> feature/greeting
    """

    func testThreeWayOursContentParsed() {
        let conflict = parseConflictMarkers(content: threeWayConflict)
        XCTAssertTrue(conflict.oursContent.contains("hello"))
        XCTAssertFalse(conflict.oursContent.contains("hi"))
        XCTAssertFalse(conflict.oursContent.contains("howdy"))
    }

    func testThreeWayBaseContentParsed() {
        let conflict = parseConflictMarkers(content: threeWayConflict)
        XCTAssertNotNil(conflict.baseContent)
        XCTAssertTrue(conflict.baseContent!.contains("hi"))
    }

    func testThreeWayTheirsContentParsed() {
        let conflict = parseConflictMarkers(content: threeWayConflict)
        XCTAssertTrue(conflict.theirsContent.contains("howdy"))
        XCTAssertFalse(conflict.theirsContent.contains("hello"))
    }

    func testThreeWayBaseDoesNotContainMarkers() {
        let conflict = parseConflictMarkers(content: threeWayConflict)
        XCTAssertFalse(conflict.baseContent!.contains("|||||||"))
        XCTAssertFalse(conflict.baseContent!.contains("======="))
    }

    // MARK: - Multi-line ours/theirs

    private let multiLineConflict = """
    <<<<<<< HEAD
    import Foundation
    import SwiftUI
    import Combine
    =======
    import Foundation
    import AppKit
    >>>>>>> dev
    """

    func testMultiLineOursParsed() {
        let conflict = parseConflictMarkers(content: multiLineConflict)
        XCTAssertTrue(conflict.oursContent.contains("SwiftUI"))
        XCTAssertTrue(conflict.oursContent.contains("Combine"))
        XCTAssertTrue(conflict.oursContent.contains("Foundation"))
    }

    func testMultiLineTheirsParsed() {
        let conflict = parseConflictMarkers(content: multiLineConflict)
        XCTAssertTrue(conflict.theirsContent.contains("AppKit"))
        XCTAssertFalse(conflict.theirsContent.contains("SwiftUI"))
    }

    func testMultiLineTheirsLineCount() {
        let conflict = parseConflictMarkers(content: multiLineConflict)
        let lines = conflict.theirsContent.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2, "theirs should have exactly 2 lines")
    }

    func testMultiLineOursLineCount() {
        let conflict = parseConflictMarkers(content: multiLineConflict)
        let lines = conflict.oursContent.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 3, "ours should have exactly 3 lines")
    }

    // MARK: - Empty ours or theirs

    func testEmptyOursSection() {
        let content = """
        <<<<<<< HEAD
        =======
        let added = true
        >>>>>>> feature
        """
        let conflict = parseConflictMarkers(content: content)
        XCTAssertTrue(conflict.oursContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(conflict.theirsContent.contains("let added = true"))
    }

    func testEmptyTheirsSection() {
        let content = """
        <<<<<<< HEAD
        let removed = true
        =======
        >>>>>>> feature
        """
        let conflict = parseConflictMarkers(content: content)
        XCTAssertTrue(conflict.oursContent.contains("let removed = true"))
        XCTAssertTrue(conflict.theirsContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - File path stored correctly

    func testFilePathStoredOnConflict() {
        let conflict = parseConflictMarkers(content: twoWayConflict, filePath: "Sources/App.swift")
        XCTAssertEqual(conflict.filePath, "Sources/App.swift")
    }

    // MARK: - isResolved defaults to false

    func testConflictIsNotResolvedByDefault() {
        let conflict = parseConflictMarkers(content: twoWayConflict)
        XCTAssertFalse(conflict.isResolved)
    }

    // MARK: - No conflict markers → empty content

    func testNoMarkersYieldsEmptyContent() {
        let content = "just a normal file\nwith no conflict markers\n"
        let conflict = parseConflictMarkers(content: content)
        XCTAssertTrue(conflict.oursContent.isEmpty)
        XCTAssertTrue(conflict.theirsContent.isEmpty)
        XCTAssertNil(conflict.baseContent)
    }

    // MARK: - MergeConflict struct

    func testMergeConflictIdEqualsFilePath() {
        let conflict = MergeConflict(filePath: "src/main.swift", oursContent: "", theirsContent: "")
        XCTAssertEqual(conflict.id, "src/main.swift")
    }

    func testMergeConflictCodableRoundTrip() throws {
        let original = MergeConflict(
            filePath: "test.swift",
            oursContent: "our code",
            theirsContent: "their code",
            baseContent: "base code",
            isResolved: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MergeConflict.self, from: data)
        XCTAssertEqual(decoded.filePath, original.filePath)
        XCTAssertEqual(decoded.oursContent, original.oursContent)
        XCTAssertEqual(decoded.theirsContent, original.theirsContent)
        XCTAssertEqual(decoded.baseContent, original.baseContent)
        XCTAssertEqual(decoded.isResolved, original.isResolved)
    }

    func testMergeConflictBaseContentCanBeNil() throws {
        let original = MergeConflict(filePath: "f.swift", oursContent: "a", theirsContent: "b", baseContent: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MergeConflict.self, from: data)
        XCTAssertNil(decoded.baseContent)
    }

    func testMergeConflictIsResolvedDefaultsFalse() {
        let conflict = MergeConflict(filePath: "x.swift", oursContent: "", theirsContent: "")
        XCTAssertFalse(conflict.isResolved)
    }

    func testMergeConflictIsResolvedCanBeSetTrue() {
        var conflict = MergeConflict(filePath: "x.swift", oursContent: "", theirsContent: "")
        conflict.isResolved = true
        XCTAssertTrue(conflict.isResolved)
    }
}
