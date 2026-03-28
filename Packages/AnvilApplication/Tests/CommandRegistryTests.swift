import XCTest
@testable import AnvilApplication
import AnvilDomain

/// XCTest coverage for CommandRegistry: register, lookup, execute, unregister,
/// space-scoped filtering, category/group queries, and batch registration.
@MainActor
final class CommandRegistryTests: XCTestCase {

    var registry: CommandRegistry!

    override func setUp() async throws {
        registry = await CommandRegistry()
    }

    override func tearDown() async throws {
        registry = nil
    }

    // MARK: - Helpers

    private func makeCommand(
        id: String,
        title: String = "Test Command",
        category: CommandCategory = .actions,
        spaceScope: String? = nil,
        group: String? = nil,
        keyboardShortcut: String? = nil
    ) -> AnvilCommand {
        AnvilCommand(
            id: id,
            title: title,
            subtitle: nil,
            icon: "circle",
            category: category,
            keyboardShortcut: keyboardShortcut,
            spaceScope: spaceScope,
            group: group
        )
    }

    // MARK: - Register

    func testRegisterAddsCommand() {
        let cmd = makeCommand(id: "cmd.1", title: "Alpha")
        registry.register(cmd) {}
        XCTAssertEqual(registry.commands.count, 1)
        XCTAssertEqual(registry.commands[0].id, "cmd.1")
    }

    func testRegisterMultipleCommands() {
        registry.register(makeCommand(id: "a")) {}
        registry.register(makeCommand(id: "b")) {}
        registry.register(makeCommand(id: "c")) {}
        XCTAssertEqual(registry.commands.count, 3)
    }

    func testRegisterReplacesExistingCommandWithSameId() {
        registry.register(makeCommand(id: "dup", title: "Before")) {}
        registry.register(makeCommand(id: "dup", title: "After")) {}
        XCTAssertEqual(registry.commands.count, 1, "Duplicate ID must replace, not append")
        XCTAssertEqual(registry.commands[0].title, "After")
    }

    func testRegisterPreservesAllFields() {
        let cmd = AnvilCommand(
            id: "full.cmd",
            title: "Full Command",
            subtitle: "A subtitle",
            icon: "star",
            category: .review,
            keyboardShortcut: "⌘R",
            spaceScope: "Review",
            group: "Git"
        )
        registry.register(cmd) {}
        let fetched = registry.command(id: "full.cmd")!
        XCTAssertEqual(fetched.title, "Full Command")
        XCTAssertEqual(fetched.subtitle, "A subtitle")
        XCTAssertEqual(fetched.icon, "star")
        XCTAssertEqual(fetched.category, .review)
        XCTAssertEqual(fetched.keyboardShortcut, "⌘R")
        XCTAssertEqual(fetched.spaceScope, "Review")
        XCTAssertEqual(fetched.group, "Git")
    }

    // MARK: - Batch register

    func testBatchRegisterAddsAllCommands() {
        let batch: [(command: AnvilCommand, handler: @MainActor () -> Void)] = [
            (makeCommand(id: "b1", title: "Batch 1"), {}),
            (makeCommand(id: "b2", title: "Batch 2"), {}),
            (makeCommand(id: "b3", title: "Batch 3"), {}),
        ]
        registry.register(batch)
        XCTAssertEqual(registry.commands.count, 3)
        let ids = registry.commands.map(\.id)
        XCTAssertTrue(ids.contains("b1"))
        XCTAssertTrue(ids.contains("b2"))
        XCTAssertTrue(ids.contains("b3"))
    }

    func testBatchRegisterRespectsUpsertSemantics() {
        registry.register(makeCommand(id: "dup", title: "Original")) {}
        let batch: [(command: AnvilCommand, handler: @MainActor () -> Void)] = [
            (makeCommand(id: "dup", title: "Replaced"), {}),
            (makeCommand(id: "new", title: "New"), {}),
        ]
        registry.register(batch)
        XCTAssertEqual(registry.commands.count, 2)
        XCTAssertEqual(registry.command(id: "dup")?.title, "Replaced")
    }

    // MARK: - Lookup (command(id:))

    func testLookupByIdReturnsCorrectCommand() {
        registry.register(makeCommand(id: "find.me", title: "Find Me")) {}
        registry.register(makeCommand(id: "other", title: "Other")) {}
        let found = registry.command(id: "find.me")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "Find Me")
    }

    func testLookupByIdReturnsNilForUnknownId() {
        registry.register(makeCommand(id: "existing")) {}
        XCTAssertNil(registry.command(id: "nonexistent"))
    }

    func testLookupOnEmptyRegistryReturnsNil() {
        XCTAssertNil(registry.command(id: "anything"))
    }

    // MARK: - Unregister

    func testUnregisterRemovesCommand() {
        registry.register(makeCommand(id: "rm.me")) {}
        registry.unregister(id: "rm.me")
        XCTAssertNil(registry.command(id: "rm.me"))
        XCTAssertTrue(registry.commands.isEmpty)
    }

    func testUnregisterNonExistentIdIsSafe() {
        registry.register(makeCommand(id: "keep")) {}
        registry.unregister(id: "does-not-exist")
        XCTAssertEqual(registry.commands.count, 1)
    }

    func testUnregisterLeavesOtherCommandsIntact() {
        registry.register(makeCommand(id: "a")) {}
        registry.register(makeCommand(id: "b")) {}
        registry.register(makeCommand(id: "c")) {}
        registry.unregister(id: "b")
        XCTAssertEqual(registry.commands.count, 2)
        XCTAssertNotNil(registry.command(id: "a"))
        XCTAssertNil(registry.command(id: "b"))
        XCTAssertNotNil(registry.command(id: "c"))
    }

    // MARK: - Execute

    func testExecuteCallsHandler() {
        var called = false
        registry.register(makeCommand(id: "exec.me")) { called = true }
        let result = registry.execute(id: "exec.me")
        XCTAssertTrue(result, "execute must return true when handler exists")
        XCTAssertTrue(called, "execute must invoke the registered handler")
    }

    func testExecuteReturnsFalseForUnknownId() {
        let result = registry.execute(id: "unknown.cmd")
        XCTAssertFalse(result, "execute must return false when no handler is registered")
    }

    func testExecuteUnregisteredCommandDoesNotThrow() {
        registry.register(makeCommand(id: "temp")) {}
        registry.unregister(id: "temp")
        let result = registry.execute(id: "temp")
        XCTAssertFalse(result, "execute after unregister must return false")
    }

    func testExecuteUpdatesHandlerAfterReplacement() {
        var firstCalled = false
        var secondCalled = false
        registry.register(makeCommand(id: "replace.me")) { firstCalled = true }
        registry.register(makeCommand(id: "replace.me")) { secondCalled = true }
        registry.execute(id: "replace.me")
        XCTAssertFalse(firstCalled, "Old handler must not be called after replacement")
        XCTAssertTrue(secondCalled, "New handler must be called after replacement")
    }

    func testExecuteCanBeCalledMultipleTimes() {
        var count = 0
        registry.register(makeCommand(id: "count.me")) { count += 1 }
        registry.execute(id: "count.me")
        registry.execute(id: "count.me")
        registry.execute(id: "count.me")
        XCTAssertEqual(count, 3, "Handler must be invocable multiple times")
    }

    // MARK: - Space-scoped filtering

    func testCommandsForSpaceIncludesGlobalCommands() {
        registry.register(makeCommand(id: "global", spaceScope: nil)) {}
        let result = registry.commands(forSpace: "Plan")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "global")
    }

    func testCommandsForSpaceIncludesScopedCommandsForMatchingSpace() {
        registry.register(makeCommand(id: "plan.cmd", spaceScope: "Plan")) {}
        let result = registry.commands(forSpace: "Plan")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "plan.cmd")
    }

    func testCommandsForSpaceExcludesScopedCommandsForOtherSpace() {
        registry.register(makeCommand(id: "review.cmd", spaceScope: "Review")) {}
        let result = registry.commands(forSpace: "Plan")
        XCTAssertTrue(result.isEmpty, "Space-scoped command must not appear in other spaces")
    }

    func testCommandsForNilSpaceReturnsOnlyGlobalCommands() {
        registry.register(makeCommand(id: "global", spaceScope: nil)) {}
        registry.register(makeCommand(id: "plan.only", spaceScope: "Plan")) {}
        let result = registry.commands(forSpace: nil)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "global")
    }

    func testMixedGlobalAndScopedCommandsForSpace() {
        registry.register(makeCommand(id: "global1", spaceScope: nil)) {}
        registry.register(makeCommand(id: "global2", spaceScope: nil)) {}
        registry.register(makeCommand(id: "build.cmd", spaceScope: "Build")) {}
        registry.register(makeCommand(id: "plan.cmd", spaceScope: "Plan")) {}

        let buildCommands = registry.commands(forSpace: "Build")
        XCTAssertEqual(buildCommands.count, 3) // global1 + global2 + build.cmd
        let buildIds = buildCommands.map(\.id)
        XCTAssertTrue(buildIds.contains("global1"))
        XCTAssertTrue(buildIds.contains("global2"))
        XCTAssertTrue(buildIds.contains("build.cmd"))
        XCTAssertFalse(buildIds.contains("plan.cmd"))
    }

    // MARK: - Category filtering

    func testCommandsByCategoryFiltersCorrectly() {
        registry.register(makeCommand(id: "nav1", category: .navigation)) {}
        registry.register(makeCommand(id: "nav2", category: .navigation)) {}
        registry.register(makeCommand(id: "agent1", category: .agent)) {}

        let navCommands = registry.commands(category: .navigation)
        XCTAssertEqual(navCommands.count, 2)
        XCTAssertTrue(navCommands.allSatisfy { $0.category == .navigation })
    }

    func testCommandsByCategoryRespectsSpaceScope() {
        registry.register(makeCommand(id: "global.nav", category: .navigation, spaceScope: nil)) {}
        registry.register(makeCommand(id: "plan.nav", category: .navigation, spaceScope: "Plan")) {}
        registry.register(makeCommand(id: "review.nav", category: .navigation, spaceScope: "Review")) {}

        let planNav = registry.commands(category: .navigation, space: "Plan")
        XCTAssertEqual(planNav.count, 2) // global + plan-scoped
        let ids = planNav.map(\.id)
        XCTAssertTrue(ids.contains("global.nav"))
        XCTAssertTrue(ids.contains("plan.nav"))
        XCTAssertFalse(ids.contains("review.nav"))
    }

    func testCommandsByCategoryReturnsEmptyForUnusedCategory() {
        registry.register(makeCommand(id: "nav", category: .navigation)) {}
        let result = registry.commands(category: .terminal)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Group filtering

    func testCommandsByGroupFiltersCorrectly() {
        registry.register(makeCommand(id: "git.status", group: "Git")) {}
        registry.register(makeCommand(id: "git.commit", group: "Git")) {}
        registry.register(makeCommand(id: "term.new", group: "Terminal")) {}

        let gitCommands = registry.commands(group: "Git")
        XCTAssertEqual(gitCommands.count, 2)
        XCTAssertTrue(gitCommands.allSatisfy { $0.group == "Git" })
    }

    func testCommandsByGroupReturnsEmptyForUnknownGroup() {
        registry.register(makeCommand(id: "cmd", group: "Git")) {}
        let result = registry.commands(group: "Editor")
        XCTAssertTrue(result.isEmpty)
    }

    func testCommandsByGroupRespectsSpaceScope() {
        registry.register(makeCommand(id: "global.git", spaceScope: nil, group: "Git")) {}
        registry.register(makeCommand(id: "review.git", spaceScope: "Review", group: "Git")) {}

        let planGit = registry.commands(group: "Git", space: "Plan")
        XCTAssertEqual(planGit.count, 1)
        XCTAssertEqual(planGit[0].id, "global.git")
    }

    // MARK: - CommandCategory

    func testAllCommandCategoryRawValues() {
        let expected = ["Navigation", "Agent", "Plan", "Review", "Operate",
                        "Editor", "Terminal", "View", "Actions", "Spaces"]
        let actual = CommandCategory.allCases.map(\.rawValue)
        XCTAssertEqual(Set(actual), Set(expected))
    }

    func testCommandCategoryRawValueRoundTrips() {
        for category in CommandCategory.allCases {
            let recovered = CommandCategory(rawValue: category.rawValue)
            XCTAssertEqual(recovered, category)
        }
    }

    // MARK: - AnvilCommand value semantics

    func testAnvilCommandIdIsUnique() {
        let a = makeCommand(id: "cmd.a")
        let b = makeCommand(id: "cmd.b")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testAnvilCommandNilOptionalsByDefault() {
        let cmd = AnvilCommand(id: "min", title: "Minimal", icon: "star", category: .actions)
        XCTAssertNil(cmd.subtitle)
        XCTAssertNil(cmd.keyboardShortcut)
        XCTAssertNil(cmd.spaceScope)
        XCTAssertNil(cmd.group)
    }
}
