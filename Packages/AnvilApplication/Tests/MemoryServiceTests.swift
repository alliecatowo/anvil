import XCTest
@testable import AnvilApplication
import AnvilDomain

/// Tests for MemoryService (auto-memory tier) and ProjectRulesService (project rules tier).
/// MemoryService is an actor — all tests use async/await.
final class MemoryServiceTests: XCTestCase {

    private var tempDir: String!
    private var service: MemoryService!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = NSTemporaryDirectory() + "anvil-memory-tests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        service = MemoryService(storagePath: tempDir + "/memories.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDir)
        tempDir = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - Load (empty state)

    func testLoadEntriesReturnsEmptyWhenFileDoesNotExist() async throws {
        // storagePath points to a non-existent file
        let freshService = MemoryService(storagePath: tempDir + "/nonexistent.json")
        let entries = try await freshService.loadEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testLoadEntriesPopulatesInternalState() async throws {
        let entries = try await service.loadEntries()
        XCTAssertTrue(entries.isEmpty)
        let all = await service.allEntries()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - MemoryEntry model

    func testMemoryEntryInitWithDefaults() {
        let entry = MemoryEntry(
            sessionId: "s1",
            category: .fileCreated,
            summary: "Created Foo.swift"
        )
        XCTAssertFalse(entry.id.isEmpty)
        XCTAssertEqual(entry.sessionId, "s1")
        XCTAssertEqual(entry.category, .fileCreated)
        XCTAssertEqual(entry.summary, "Created Foo.swift")
        XCTAssertNil(entry.detail)
    }

    func testMemoryEntryInitWithDetail() {
        let entry = MemoryEntry(
            sessionId: "s1",
            category: .fileModified,
            summary: "Modified Bar.swift",
            detail: "/path/to/Bar.swift"
        )
        XCTAssertEqual(entry.detail, "/path/to/Bar.swift")
    }

    func testMemoryEntryIdIsUniquePerInstance() {
        let a = MemoryEntry(sessionId: "s1", category: .other, summary: "A")
        let b = MemoryEntry(sessionId: "s1", category: .other, summary: "A")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testMemoryEntryCodableRoundTrip() throws {
        let original = MemoryEntry(
            id: "fixed-id",
            sessionId: "sess",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            category: .decision,
            summary: "Decided to use SwiftUI",
            detail: "Architecture choice"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MemoryEntry.self, from: data)

        XCTAssertEqual(decoded.id, "fixed-id")
        XCTAssertEqual(decoded.sessionId, "sess")
        XCTAssertEqual(decoded.category, .decision)
        XCTAssertEqual(decoded.summary, "Decided to use SwiftUI")
        XCTAssertEqual(decoded.detail, "Architecture choice")
    }

    // MARK: - MemoryCategory

    func testAllCategoriesHaveIcon() {
        for category in MemoryCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) has empty icon")
        }
    }

    func testAllCategoriesHaveDisplayName() {
        for category in MemoryCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "\(category) has empty displayName")
        }
    }

    func testCategoryRawValues() {
        XCTAssertEqual(MemoryCategory.fileCreated.rawValue, "file_created")
        XCTAssertEqual(MemoryCategory.fileModified.rawValue, "file_modified")
        XCTAssertEqual(MemoryCategory.bugFixed.rawValue, "bug_fixed")
        XCTAssertEqual(MemoryCategory.decision.rawValue, "decision")
        XCTAssertEqual(MemoryCategory.dependency.rawValue, "dependency")
        XCTAssertEqual(MemoryCategory.architecture.rawValue, "architecture")
        XCTAssertEqual(MemoryCategory.other.rawValue, "other")
    }

    func testMemoryCategoryCodable() throws {
        for category in MemoryCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(MemoryCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }

    // MARK: - scanSession — file tool calls

    func testScanSessionExtractsFileCreatedFromCreateFileTool() async throws {
        let tool = ToolCall(name: "create_file", arguments: "{\"path\":\"/src/Foo.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])

        let entries = try await service.scanSession(session)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].category, .fileCreated)
        XCTAssertEqual(entries[0].summary, "Created Foo.swift")
        XCTAssertEqual(entries[0].detail, "/src/Foo.swift")
    }

    func testScanSessionExtractsFileModifiedFromWriteFileTool() async throws {
        let tool = ToolCall(name: "write_file", arguments: "{\"path\":\"/src/Bar.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])

        let entries = try await service.scanSession(session)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].category, .fileModified)
        XCTAssertEqual(entries[0].summary, "Modified Bar.swift")
    }

    func testScanSessionIgnoresUnknownToolNames() async throws {
        let tool = ToolCall(name: "bash_exec", arguments: "{\"command\":\"ls\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])

        let entries = try await service.scanSession(session)
        XCTAssertTrue(entries.isEmpty)
    }

    func testScanSessionExtractsMultipleFileToolCalls() async throws {
        let t1 = ToolCall(name: "create_file", arguments: "{\"path\":\"/a/A.swift\"}")
        let t2 = ToolCall(name: "write_file", arguments: "{\"path\":\"/b/B.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [t1, t2])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])

        let entries = try await service.scanSession(session)
        XCTAssertEqual(entries.count, 2)
    }

    func testScanSessionToolCallMissingPathReturnsNoEntry() async throws {
        let tool = ToolCall(name: "write_file", arguments: "{\"content\":\"hello\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])

        let entries = try await service.scanSession(session)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - scanSession — content extraction

    func testScanSessionExtractsBugFixFromAssistantMessage() async throws {
        let msg = AgentMessage(role: .assistant, content: "Fixed the bug in the auth flow.")
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])

        let entries = try await service.scanSession(session)

        XCTAssertTrue(entries.contains { $0.category == .bugFixed })
    }

    func testScanSessionExtractsDecisionFromAssistantMessage() async throws {
        let msg = AgentMessage(role: .assistant, content: "I decided to use async/await here.")
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])

        let entries = try await service.scanSession(session)

        XCTAssertTrue(entries.contains { $0.category == .decision })
    }

    func testScanSessionDoesNotExtractFromUserMessages() async throws {
        let msg = AgentMessage(role: .user, content: "Fixed the bug, I decided to use X.")
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])

        // Only assistant messages are scanned for content patterns
        let entries = try await service.scanSession(session)
        XCTAssertTrue(entries.filter { $0.category == .bugFixed || $0.category == .decision }.isEmpty)
    }

    func testScanSessionDeduplicatesBySummary() async throws {
        let tool = ToolCall(name: "write_file", arguments: "{\"path\":\"/src/Foo.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg, msg])

        let entries = try await service.scanSession(session)
        // Two identical toolcalls produce two MemoryEntry instances with same summary,
        // but deduplication by summary should reduce to 1
        XCTAssertEqual(entries.count, 1)
    }

    func testScanSessionNewCallDeduplicatesAgainstExistingEntries() async throws {
        // First scan
        let tool = ToolCall(name: "write_file", arguments: "{\"path\":\"/x/X.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session1 = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await service.scanSession(session1)

        // Second scan with the same file
        let session2 = AgentSession(id: "s2", providerId: "test", model: "claude", messages: [msg])
        let second = try await service.scanSession(session2)

        // Should not re-add the duplicate
        XCTAssertTrue(second.isEmpty)
    }

    func testScanSessionAttachesSessionId() async throws {
        let tool = ToolCall(name: "create_file", arguments: "{\"path\":\"/a.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "my-session-id", providerId: "test", model: "claude", messages: [msg])

        let entries = try await service.scanSession(session)

        XCTAssertEqual(entries[0].sessionId, "my-session-id")
    }

    func testScanSessionEmptyMessagesReturnsNoEntries() async throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        let entries = try await service.scanSession(session)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Persistence

    func testScanSessionPersistsEntriesToDisk() async throws {
        let tool = ToolCall(name: "create_file", arguments: "{\"path\":\"/new.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await service.scanSession(session)

        // Fresh service reading from same path
        let reloaded = MemoryService(storagePath: tempDir + "/memories.json")
        let entries = try await reloaded.loadEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].summary, "Created new.swift")
    }

    func testAllEntriesReflectsScannedEntries() async throws {
        let tool = ToolCall(name: "write_file", arguments: "{\"path\":\"/f.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await service.scanSession(session)

        let all = await service.allEntries()
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - deleteEntry

    func testDeleteEntryRemovesEntryFromInternalState() async throws {
        let tool = ToolCall(name: "create_file", arguments: "{\"path\":\"/del.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        let entries = try await service.scanSession(session)

        let id = entries[0].id
        try await service.deleteEntry(id: id)

        let all = await service.allEntries()
        XCTAssertFalse(all.contains { $0.id == id })
    }

    func testDeleteEntryPersistsDeletionToDisk() async throws {
        let tool = ToolCall(name: "create_file", arguments: "{\"path\":\"/persist.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        let entries = try await service.scanSession(session)

        try await service.deleteEntry(id: entries[0].id)

        let reloaded = MemoryService(storagePath: tempDir + "/memories.json")
        let reloadedEntries = try await reloaded.loadEntries()
        XCTAssertTrue(reloadedEntries.isEmpty)
    }

    func testDeleteEntryWithUnknownIdIsNoOp() async throws {
        try await service.deleteEntry(id: "nonexistent-id")
        let all = await service.allEntries()
        XCTAssertTrue(all.isEmpty)
    }
}

// MARK: - ProjectRulesServiceTests

final class ProjectRulesServiceTests: XCTestCase {

    private var tempDir: String!
    private var rulesService: ProjectRulesService!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "anvil-rules-tests-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        rulesService = ProjectRulesService()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        tempDir = nil
        rulesService = nil
        super.tearDown()
    }

    // MARK: - loadRules

    func testLoadRulesReturnsNilWhenFileDoesNotExist() {
        let result = rulesService.loadRules(projectPath: tempDir)
        XCTAssertNil(result)
    }

    func testLoadRulesReturnsNilForEmptyFile() throws {
        let anvilDir = (tempDir as NSString).appendingPathComponent(".anvil")
        try FileManager.default.createDirectory(atPath: anvilDir, withIntermediateDirectories: true)
        let rulesPath = (anvilDir as NSString).appendingPathComponent("rules.md")
        try "".write(toFile: rulesPath, atomically: true, encoding: .utf8)

        let result = rulesService.loadRules(projectPath: tempDir)
        XCTAssertNil(result)
    }

    func testLoadRulesReturnsNilForWhitespaceOnlyFile() throws {
        let anvilDir = (tempDir as NSString).appendingPathComponent(".anvil")
        try FileManager.default.createDirectory(atPath: anvilDir, withIntermediateDirectories: true)
        let rulesPath = (anvilDir as NSString).appendingPathComponent("rules.md")
        try "   \n\t\n  ".write(toFile: rulesPath, atomically: true, encoding: .utf8)

        let result = rulesService.loadRules(projectPath: tempDir)
        XCTAssertNil(result)
    }

    // MARK: - saveRules + loadRules round-trip

    func testSaveAndLoadRulesRoundTrip() throws {
        let rules = "# Rules\n- No force push to main\n- Require tests for all changes"
        try rulesService.saveRules(rules, projectPath: tempDir)

        let loaded = rulesService.loadRules(projectPath: tempDir)
        XCTAssertEqual(loaded, rules)
    }

    func testSaveRulesCreatesAnvilDirectory() throws {
        let anvilDir = (tempDir as NSString).appendingPathComponent(".anvil")
        XCTAssertFalse(FileManager.default.fileExists(atPath: anvilDir))

        try rulesService.saveRules("Some rules", projectPath: tempDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: anvilDir))
    }

    func testSaveRulesCreatesRulesFile() throws {
        try rulesService.saveRules("Test rules content", projectPath: tempDir)

        let rulesPath = rulesService.rulesPath(projectPath: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rulesPath))
    }

    func testSaveRulesOverwritesPreviousContent() throws {
        try rulesService.saveRules("First version", projectPath: tempDir)
        try rulesService.saveRules("Second version", projectPath: tempDir)

        let loaded = rulesService.loadRules(projectPath: tempDir)
        XCTAssertEqual(loaded, "Second version")
    }

    func testSaveRulesPreservesMarkdownFormatting() throws {
        let markdown = "# Project Rules\n\n## Testing\n- All code must have tests\n\n## Style\n- Use 4-space indentation\n"
        try rulesService.saveRules(markdown, projectPath: tempDir)

        let loaded = rulesService.loadRules(projectPath: tempDir)
        XCTAssertEqual(loaded, markdown)
    }

    // MARK: - rulesPath

    func testRulesPathPointsToAnvilRulesMd() {
        let path = rulesService.rulesPath(projectPath: "/Users/test/myproject")
        XCTAssertEqual(path, "/Users/test/myproject/.anvil/rules.md")
    }

    func testRulesPathForNestedProject() {
        let path = rulesService.rulesPath(projectPath: "/a/b/c")
        XCTAssertTrue(path.hasSuffix("/.anvil/rules.md"))
        XCTAssertTrue(path.hasPrefix("/a/b/c"))
    }

    // MARK: - Two-tier memory: auto vs project rules are independent

    func testAutoMemoryAndProjectRulesStoredSeparately() async throws {
        let memService = MemoryService(storagePath: tempDir + "/.anvil/memories.json")
        let tool = ToolCall(name: "create_file", arguments: "{\"path\":\"/x.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await memService.scanSession(session)

        try rulesService.saveRules("# My rules", projectPath: tempDir)

        // Memories file exists
        let memoriesPath = tempDir + "/.anvil/memories.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: memoriesPath))

        // Rules file exists separately
        let rulesPath = rulesService.rulesPath(projectPath: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rulesPath))

        // They are different files
        XCTAssertNotEqual(memoriesPath, rulesPath)
    }

    func testProjectRulesDoNotAffectAutoMemories() async throws {
        let memService = MemoryService(storagePath: tempDir + "/memories.json")

        try rulesService.saveRules("# Rules content", projectPath: tempDir)

        // Auto-memories should still be empty — rules file doesn't pollute memories
        let entries = try await memService.loadEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testAutoMemoriesDoNotAffectProjectRules() async throws {
        let memService = MemoryService(storagePath: tempDir + "/memories.json")
        let tool = ToolCall(name: "create_file", arguments: "{\"path\":\"/a.swift\"}")
        let msg = AgentMessage(role: .assistant, content: "", toolCalls: [tool])
        let session = AgentSession(id: "s1", providerId: "test", model: "claude", messages: [msg])
        _ = try await memService.scanSession(session)

        // Project rules should still return nil — memory scan doesn't create rules
        let rules = rulesService.loadRules(projectPath: tempDir)
        XCTAssertNil(rules)
    }
}
