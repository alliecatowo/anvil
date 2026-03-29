import XCTest
@testable import AnvilUI

/// XCTest coverage for SlashCommand parsing and filtering logic:
/// - SlashCommand.all contains all expected commands
/// - Empty filter returns full list
/// - "/" prefix (trimmed) returns full list
/// - Partial filter narrows results
/// - No-match filter returns empty
/// - isContextCommand / autoSend classification
/// - promptTemplate / type accessors
/// - Filtering is case-insensitive
final class SlashCommandTests: XCTestCase {

    // MARK: - Catalog completeness

    func testAllCommandsNonEmpty() {
        XCTAssertFalse(SlashCommand.all.isEmpty)
    }

    func testPromptCommandsNonEmpty() {
        XCTAssertFalse(SlashCommand.promptCommands.isEmpty)
    }

    func testContextCommandsNonEmpty() {
        XCTAssertFalse(SlashCommand.contextCommands.isEmpty)
    }

    func testAllEqualsPromptPlusContext() {
        XCTAssertEqual(SlashCommand.all.count, SlashCommand.promptCommands.count + SlashCommand.contextCommands.count)
    }

    // MARK: - Expected commands present

    func testFileCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/file" })
    }

    func testTabCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/tab" })
    }

    func testSelectionCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/selection" })
    }

    func testDiffCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/diff" })
    }

    func testBranchCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/branch" })
    }

    func testTicketCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/ticket" })
    }

    func testFixCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/fix" })
    }

    func testExplainCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/explain" })
    }

    func testTestCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/test" })
    }

    func testCommitCommandPresent() {
        XCTAssertTrue(SlashCommand.all.contains { $0.name == "/commit" })
    }

    // MARK: - Filtering logic (replicated from SlashCommandMenu.filtered)

    private func filter(_ query: String) -> [SlashCommand] {
        let q = query.lowercased().trimmingCharacters(in: .init(charactersIn: "/"))
        if q.isEmpty { return SlashCommand.all }
        return SlashCommand.all.filter {
            $0.name.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }

    func testEmptyQueryReturnsAll() {
        XCTAssertEqual(filter("").count, SlashCommand.all.count)
    }

    func testSlashOnlyReturnsAll() {
        XCTAssertEqual(filter("/").count, SlashCommand.all.count)
    }

    func testFilQueryFiltersToFileCommand() {
        let results = filter("fil")
        XCTAssertTrue(results.contains { $0.name == "/file" })
        XCTAssertFalse(results.contains { $0.name == "/tab" })
        XCTAssertFalse(results.contains { $0.name == "/diff" })
    }

    func testSlashFilQueryFiltersToFileCommand() {
        let results = filter("/fil")
        XCTAssertTrue(results.contains { $0.name == "/file" })
    }

    func testTabQueryFiltersToTabCommand() {
        let results = filter("tab")
        XCTAssertTrue(results.contains { $0.name == "/tab" })
    }

    func testDiffQueryFiltersToDiffCommand() {
        let results = filter("diff")
        XCTAssertTrue(results.contains { $0.name == "/diff" })
    }

    func testBranchQueryFiltersToBranchCommand() {
        let results = filter("branch")
        XCTAssertTrue(results.contains { $0.name == "/branch" })
    }

    func testNoMatchQueryReturnsEmpty() {
        let results = filter("zzznomatch")
        XCTAssertTrue(results.isEmpty)
    }

    func testFilteringIsCaseInsensitive() {
        let lower = filter("file")
        let upper = filter("FILE")
        let mixed = filter("FiLe")
        XCTAssertEqual(lower.count, upper.count)
        XCTAssertEqual(lower.count, mixed.count)
    }

    func testFilterMatchesDescription() {
        // /fix has description "Fix the bug" — search for "bug" should find it
        let results = filter("bug")
        XCTAssertTrue(results.contains { $0.name == "/fix" })
    }

    func testFilterMatchesDocDescription() {
        // /doc has description "Generate documentation"
        let results = filter("documentation")
        XCTAssertTrue(results.contains { $0.name == "/doc" })
    }

    // MARK: - isContextCommand classification

    func testFileCommandIsContextCommand() {
        let cmd = SlashCommand.all.first { $0.name == "/file" }!
        XCTAssertTrue(cmd.isContextCommand)
    }

    func testTabCommandIsContextCommand() {
        let cmd = SlashCommand.all.first { $0.name == "/tab" }!
        XCTAssertTrue(cmd.isContextCommand)
    }

    func testDiffCommandIsContextCommand() {
        let cmd = SlashCommand.all.first { $0.name == "/diff" }!
        XCTAssertTrue(cmd.isContextCommand)
    }

    func testBranchCommandIsContextCommand() {
        let cmd = SlashCommand.all.first { $0.name == "/branch" }!
        XCTAssertTrue(cmd.isContextCommand)
    }

    func testFixCommandIsNotContextCommand() {
        let cmd = SlashCommand.all.first { $0.name == "/fix" }!
        XCTAssertFalse(cmd.isContextCommand)
    }

    func testExplainCommandIsNotContextCommand() {
        let cmd = SlashCommand.all.first { $0.name == "/explain" }!
        XCTAssertFalse(cmd.isContextCommand)
    }

    // MARK: - autoSend

    func testCommitCommandAutoSend() {
        let cmd = SlashCommand.all.first { $0.name == "/commit" }!
        XCTAssertTrue(cmd.autoSend)
    }

    func testFixCommandNotAutoSend() {
        let cmd = SlashCommand.all.first { $0.name == "/fix" }!
        XCTAssertFalse(cmd.autoSend)
    }

    func testContextCommandsNotAutoSend() {
        for cmd in SlashCommand.contextCommands {
            XCTAssertFalse(cmd.autoSend, "\(cmd.name) should not be autoSend")
        }
    }

    // MARK: - promptTemplate

    func testFixCommandHasNonEmptyPromptTemplate() {
        let cmd = SlashCommand.all.first { $0.name == "/fix" }!
        XCTAssertFalse(cmd.promptTemplate.isEmpty)
    }

    func testContextCommandsHaveEmptyPromptTemplate() {
        for cmd in SlashCommand.contextCommands {
            XCTAssertTrue(cmd.promptTemplate.isEmpty, "\(cmd.name) context command should have empty promptTemplate")
        }
    }

    // MARK: - SlashCommandType cases

    func testFileCommandHasPickerType() {
        let cmd = SlashCommand.all.first { $0.name == "/file" }!
        if case .picker(let kind) = cmd.type {
            XCTAssertEqual(kind, .file)
        } else {
            XCTFail("/file should have .picker(.file) type")
        }
    }

    func testTicketCommandHasPickerType() {
        let cmd = SlashCommand.all.first { $0.name == "/ticket" }!
        if case .picker(let kind) = cmd.type {
            XCTAssertEqual(kind, .ticket)
        } else {
            XCTFail("/ticket should have .picker(.ticket) type")
        }
    }

    func testTabCommandHasInjectContextType() {
        let cmd = SlashCommand.all.first { $0.name == "/tab" }!
        if case .injectContext = cmd.type {
            // correct
        } else {
            XCTFail("/tab should have .injectContext type")
        }
    }

    func testDiffCommandHasInjectContextType() {
        let cmd = SlashCommand.all.first { $0.name == "/diff" }!
        if case .injectContext = cmd.type {
            // correct
        } else {
            XCTFail("/diff should have .injectContext type")
        }
    }

    func testFixCommandHasPromptType() {
        let cmd = SlashCommand.all.first { $0.name == "/fix" }!
        if case .prompt = cmd.type {
            // correct
        } else {
            XCTFail("/fix should have .prompt type")
        }
    }

    // MARK: - IDs are unique

    func testAllCommandIdsAreUnique() {
        let ids = SlashCommand.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Slash command IDs must be unique")
    }

    // MARK: - Names start with slash

    func testAllCommandNamesStartWithSlash() {
        for cmd in SlashCommand.all {
            XCTAssertTrue(cmd.name.hasPrefix("/"), "\(cmd.name) must start with /")
        }
    }

    // MARK: - SlashFilePickerMenu filtering logic (replicated)

    private func filterFiles(_ files: [String], query: String) -> [String] {
        let q = query.lowercased()
        if q.isEmpty { return Array(files.prefix(20)) }
        return files.filter {
            URL(fileURLWithPath: $0).lastPathComponent.lowercased().contains(q)
            || $0.lowercased().contains(q)
        }.prefix(20).map { $0 }
    }

    func testFilePickerEmptyQueryReturnsAll() {
        let files = ["/src/App.swift", "/src/Main.swift", "/src/View.swift"]
        XCTAssertEqual(filterFiles(files, query: "").count, 3)
    }

    func testFilePickerFiltersOnLastPathComponent() {
        let files = ["/src/AppState.swift", "/src/AgentViewModel.swift", "/src/Main.swift"]
        let results = filterFiles(files, query: "app")
        XCTAssertTrue(results.contains("/src/AppState.swift"))
        XCTAssertFalse(results.contains("/src/Main.swift"))
    }

    func testFilePickerFiltersOnFullPath() {
        let files = ["/tests/UITests/SpaceTests.swift", "/src/Main.swift"]
        let results = filterFiles(files, query: "uitests")
        XCTAssertTrue(results.contains("/tests/UITests/SpaceTests.swift"))
    }

    func testFilePickerCapsAtTwenty() {
        let files = (1...30).map { "/src/File\($0).swift" }
        let results = filterFiles(files, query: "")
        XCTAssertEqual(results.count, 20)
    }

    func testFilePickerNoMatchReturnsEmpty() {
        let files = ["/src/App.swift"]
        XCTAssertTrue(filterFiles(files, query: "zzz").isEmpty)
    }
}
