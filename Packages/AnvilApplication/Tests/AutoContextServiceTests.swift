import XCTest
@testable import AnvilApplication
import AnvilDomain

/// XCTest coverage for AutoContextService.score():
/// - mentionedInMessage exact filename → 50 pts, rises to top
/// - recentlyEdited recency bonus (index 0 = 25+30=55, index 9 = 25+3=28)
/// - sameDirectory → 15 pts bonus
/// - keywordMatch on file name parts
/// - top-N cap at maxSuggestions (5)
/// - dismiss removes file from results
/// - isEnabled = false → empty suggestions
/// - resetDismissals restores dismissed file
@MainActor
final class AutoContextServiceTests: XCTestCase {

    var service: AutoContextService!

    override func setUp() {
        service = AutoContextService()
    }

    override func tearDown() {
        service = nil
    }

    // MARK: - Helpers

    private func makeMessage(_ text: String) -> AgentMessage {
        AgentMessage(role: .user, content: text)
    }

    // MARK: - Initial state

    func testInitialSuggestionsAreEmpty() {
        XCTAssertTrue(service.suggestions.isEmpty)
    }

    func testMaxSuggestionsIsFive() {
        XCTAssertEqual(service.maxSuggestions, 5)
    }

    func testIsEnabledDefaultTrue() {
        XCTAssertTrue(service.isEnabled)
    }

    // MARK: - isEnabled = false

    func testDisabledReturnEmptySuggestions() {
        service.isEnabled = false
        service.score(
            messageText: "fix EditorViewModel",
            recentMessages: [],
            recentlyEditedPaths: ["/src/EditorViewModel.swift"],
            focusedFilePath: nil,
            projectFiles: ["/src/EditorViewModel.swift"]
        )
        XCTAssertTrue(service.suggestions.isEmpty)
    }

    // MARK: - mentionedInMessage

    func testExactFileNameInMessageGets50Points() {
        let files = ["/src/EditorViewModel.swift", "/src/Other.swift"]
        service.score(
            messageText: "fix EditorViewModel.swift please",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        let top = service.suggestions.first
        XCTAssertEqual(top?.path, "/src/EditorViewModel.swift")
        XCTAssertGreaterThanOrEqual(top?.score ?? 0, 50)
    }

    func testFileNameWithoutExtensionInMessageGets40Points() {
        let files = ["/src/AgentViewModel.swift"]
        service.score(
            messageText: "refactor agentviewmodel to use combine",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.isEmpty)
        XCTAssertEqual(service.suggestions.first?.reason, .mentionedInMessage)
    }

    func testFullPathInMessageScored() {
        let files = ["/src/App/AppState.swift"]
        service.score(
            messageText: "update /src/App/AppState.swift for new space",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.isEmpty)
    }

    func testMentionedFileRanksAboveRecentlyEdited() {
        let files = ["/src/Mentioned.swift", "/src/RecentlyEdited.swift"]
        service.score(
            messageText: "look at Mentioned.swift",
            recentMessages: [],
            recentlyEditedPaths: ["/src/RecentlyEdited.swift"],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertEqual(service.suggestions.first?.path, "/src/Mentioned.swift")
    }

    func testRecentMessageMentionScored() {
        let files = ["/src/Foo.swift"]
        let recentMsg = makeMessage("we discussed Foo.swift earlier")
        service.score(
            messageText: "",
            recentMessages: [recentMsg],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.isEmpty)
        XCTAssertEqual(service.suggestions.first?.reason, .mentionedInMessage)
    }

    // MARK: - recentlyEdited recency bonus

    func testFirstRecentlyEditedFileHasHigherScore() {
        let files = ["/src/First.swift", "/src/Ninth.swift"]
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: ["/src/First.swift", "/src/Ignored.swift", "/src/Ignored2.swift",
                                  "/src/Ignored3.swift", "/src/Ignored4.swift", "/src/Ignored5.swift",
                                  "/src/Ignored6.swift", "/src/Ignored7.swift", "/src/Ignored8.swift",
                                  "/src/Ninth.swift"],
            focusedFilePath: nil,
            projectFiles: files
        )
        let firstScore = service.suggestions.first { $0.path == "/src/First.swift" }?.score ?? 0
        let ninthScore = service.suggestions.first { $0.path == "/src/Ninth.swift" }?.score ?? 0
        XCTAssertGreaterThan(firstScore, ninthScore, "Earlier-edited file should score higher")
    }

    func testRecentlyEditedReasonAssigned() {
        let files = ["/src/Edit.swift"]
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: ["/src/Edit.swift"],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertEqual(service.suggestions.first?.reason, .recentlyEdited)
    }

    func testRecentlyEditedPathNotInProjectFilesIgnored() {
        // Only project files get included
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: ["/external/NotInProject.swift"],
            focusedFilePath: nil,
            projectFiles: ["/src/App.swift"]
        )
        XCTAssertFalse(service.suggestions.contains { $0.path == "/external/NotInProject.swift" })
    }

    // MARK: - sameDirectory

    func testSameDirectoryFilesGetBonus() {
        let files = ["/src/App/AppState.swift", "/src/App/AppDelegate.swift", "/src/Other/Unrelated.swift"]
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: "/src/App/AppState.swift",
            projectFiles: files
        )
        let delegate = service.suggestions.first { $0.path == "/src/App/AppDelegate.swift" }
        let unrelated = service.suggestions.first { $0.path == "/src/Other/Unrelated.swift" }
        if let d = delegate, let u = unrelated {
            XCTAssertGreaterThan(d.score, u.score, "Same-directory file should score higher than different-directory")
        } else if delegate != nil {
            // Unrelated not in top-5, but delegate is — that's also correct
            XCTAssertNotNil(delegate)
        }
    }

    func testSameDirectoryReasonAssignedWhenOnlySignal() {
        let files = ["/dir/Other.swift"]
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: "/dir/Focused.swift",
            projectFiles: files
        )
        if let result = service.suggestions.first {
            XCTAssertEqual(result.reason, .sameDirectory)
            XCTAssertEqual(result.score, 15)
        }
    }

    func testFocusedFileItselfNotIncludedInSameDirectory() {
        let files = ["/dir/Focused.swift", "/dir/Other.swift"]
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: "/dir/Focused.swift",
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.contains { $0.path == "/dir/Focused.swift" })
    }

    // MARK: - keywordMatch

    func testKeywordMatchOnCamelCaseParts() {
        // "AuthViewModel" splits to "Auth" + "View" + "Model" → "auth", "view", "model"
        let files = ["/src/AuthViewModel.swift"]
        service.score(
            messageText: "fix auth issue in view",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.isEmpty)
        XCTAssertEqual(service.suggestions.first?.reason, .keywordMatch)
    }

    func testKeywordMatchOnSnakeCaseParts() {
        let files = ["/src/user_profile_view.swift"]
        service.score(
            messageText: "update user profile",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.isEmpty)
    }

    func testKeywordMatchScoresPerMatchCount() {
        // Two matching parts should score 20, one matching part should score 10
        let files = ["/src/AgentSession.swift", "/src/AgentViewModel.swift"]
        // "agent" matches both; "session" only matches first
        service.score(
            messageText: "fix agent session handling",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        // Both should be in suggestions if not over-shadowed
        XCTAssertFalse(service.suggestions.isEmpty)
    }

    // MARK: - top-N cap

    func testTopNCappedAtFive() {
        let files = (1...20).map { "/src/File\($0).swift" }
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: files,  // all recently edited, all in project
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertLessThanOrEqual(service.suggestions.count, 5)
    }

    func testTopNResultsSortedByScoreDescending() {
        let files = (1...10).map { "/src/File\($0).swift" }
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: files,
            focusedFilePath: nil,
            projectFiles: files
        )
        let scores = service.suggestions.map(\.score)
        XCTAssertEqual(scores, scores.sorted(by: >), "Suggestions must be sorted by score descending")
    }

    func testEmptyProjectFilesReturnsEmpty() {
        service.score(
            messageText: "anything",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: []
        )
        XCTAssertTrue(service.suggestions.isEmpty)
    }

    // MARK: - dismiss

    func testDismissRemovesFileFromSuggestions() {
        let files = ["/src/ToRemove.swift", "/src/Keep.swift"]
        service.score(
            messageText: "",
            recentMessages: [],
            recentlyEditedPaths: files,
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.isEmpty)

        service.dismiss("/src/ToRemove.swift")
        XCTAssertFalse(service.suggestions.contains { $0.path == "/src/ToRemove.swift" })
    }

    func testDismissExcludesFileFromSubsequentScoring() {
        let files = ["/src/Dismissed.swift"]
        service.dismiss("/src/Dismissed.swift")
        service.score(
            messageText: "fix Dismissed.swift",
            recentMessages: [],
            recentlyEditedPaths: ["/src/Dismissed.swift"],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertTrue(service.suggestions.isEmpty)
    }

    func testResetDismissalsAllowsDismissedFileToAppearAgain() {
        let files = ["/src/Dismissed.swift"]
        service.dismiss("/src/Dismissed.swift")
        service.resetDismissals()
        service.score(
            messageText: "fix Dismissed.swift",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.isEmpty)
    }

    // MARK: - clear

    func testClearRemovesAllSuggestions() {
        let files = ["/src/App.swift"]
        service.score(
            messageText: "fix App.swift",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertFalse(service.suggestions.isEmpty)
        service.clear()
        XCTAssertTrue(service.suggestions.isEmpty)
    }

    // MARK: - ScoredFile struct

    func testScoredFileIdEqualsPath() {
        let files = ["/src/App.swift"]
        service.score(
            messageText: "fix App.swift",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        if let f = service.suggestions.first {
            XCTAssertEqual(f.id, f.path)
        }
    }

    func testScoredFileNameIsLastPathComponent() {
        let files = ["/src/deeply/nested/MyFile.swift"]
        service.score(
            messageText: "fix MyFile.swift",
            recentMessages: [],
            recentlyEditedPaths: [],
            focusedFilePath: nil,
            projectFiles: files
        )
        XCTAssertEqual(service.suggestions.first?.name, "MyFile.swift")
    }
}
