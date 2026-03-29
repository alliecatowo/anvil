import XCTest
@testable import AnvilApplication
import AnvilDomain

/// Tests for AgentSession conversation forking — parentSessionId, forkFromMessageIndex,
/// isForked computed property, and fork metadata preservation through Codable round-trips.
final class ConversationForkingTests: XCTestCase {

    // MARK: - isForked computed property

    func testIsForkedFalseWhenNoParent() {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        XCTAssertFalse(session.isForked)
    }

    func testIsForkedTrueWhenParentSessionIdSet() {
        let session = AgentSession(
            id: "s2", providerId: "test", model: "claude",
            parentSessionId: "s1"
        )
        XCTAssertTrue(session.isForked)
    }

    func testIsForkedFalseWhenParentSessionIdIsNil() {
        let session = AgentSession(
            id: "s1", providerId: "test", model: "claude",
            parentSessionId: nil
        )
        XCTAssertFalse(session.isForked)
    }

    // MARK: - parentSessionId

    func testParentSessionIdStoredCorrectly() {
        let session = AgentSession(
            id: "child", providerId: "test", model: "claude",
            parentSessionId: "parent-id"
        )
        XCTAssertEqual(session.parentSessionId, "parent-id")
    }

    func testParentSessionIdDefaultsToNil() {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        XCTAssertNil(session.parentSessionId)
    }

    func testParentSessionIdCanBeAnyString() {
        let ids = ["abc", "uuid-1234", "session/with/slashes", ""]
        for id in ids {
            let session = AgentSession(
                id: UUID().uuidString, providerId: "test", model: "claude",
                parentSessionId: id
            )
            XCTAssertEqual(session.parentSessionId, id)
        }
    }

    // MARK: - forkFromMessageIndex

    func testForkFromMessageIndexDefaultsToNil() {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")
        XCTAssertNil(session.forkFromMessageIndex)
    }

    func testForkFromMessageIndexStoredCorrectly() {
        let session = AgentSession(
            id: "s2", providerId: "test", model: "claude",
            parentSessionId: "s1",
            forkFromMessageIndex: 5
        )
        XCTAssertEqual(session.forkFromMessageIndex, 5)
    }

    func testForkFromMessageIndexZeroIsValid() {
        let session = AgentSession(
            id: "s2", providerId: "test", model: "claude",
            parentSessionId: "s1",
            forkFromMessageIndex: 0
        )
        XCTAssertEqual(session.forkFromMessageIndex, 0)
    }

    func testForkFromMessageIndexCanBeAnyNonNegativeInt() {
        let indices = [0, 1, 10, 100, Int.max]
        for index in indices {
            let session = AgentSession(
                id: UUID().uuidString, providerId: "test", model: "claude",
                parentSessionId: "parent",
                forkFromMessageIndex: index
            )
            XCTAssertEqual(session.forkFromMessageIndex, index)
        }
    }

    // MARK: - Fork with message slice

    func testForkSessionContainsPrefixOfParentMessages() {
        let messages = (0..<10).map { i in
            AgentMessage(role: i % 2 == 0 ? .user : .assistant, content: "Message \(i)")
        }
        let parent = AgentSession(
            id: "parent", providerId: "test", model: "claude", messages: messages
        )

        let forkIndex = 4
        let forkMessages = Array(parent.messages.prefix(forkIndex))
        let fork = AgentSession(
            id: "fork", providerId: "test", model: "claude",
            messages: forkMessages,
            parentSessionId: parent.id,
            forkFromMessageIndex: forkIndex
        )

        XCTAssertEqual(fork.messages.count, 4)
        XCTAssertEqual(fork.forkFromMessageIndex, 4)
        XCTAssertEqual(fork.parentSessionId, "parent")
    }

    func testForkPreservesMessageContentFromParent() {
        let msg1 = AgentMessage(id: "m1", role: .user, content: "First question")
        let msg2 = AgentMessage(id: "m2", role: .assistant, content: "First answer")
        let msg3 = AgentMessage(id: "m3", role: .user, content: "Second question")
        let parent = AgentSession(
            id: "p1", providerId: "test", model: "claude", messages: [msg1, msg2, msg3]
        )

        let fork = AgentSession(
            id: "f1", providerId: "test", model: "claude",
            messages: Array(parent.messages.prefix(2)),
            parentSessionId: parent.id,
            forkFromMessageIndex: 2
        )

        XCTAssertEqual(fork.messages[0].content, "First question")
        XCTAssertEqual(fork.messages[1].content, "First answer")
    }

    func testForkedSessionHasUniqueId() {
        let parent = AgentSession(id: "parent-id", providerId: "test", model: "claude")
        let fork = AgentSession(
            id: UUID().uuidString, providerId: "test", model: "claude",
            parentSessionId: parent.id
        )
        XCTAssertNotEqual(fork.id, parent.id)
    }

    func testForkedSessionCanHaveItsOwnCustomName() {
        let parent = AgentSession(
            id: "p1", providerId: "test", model: "claude", customName: "Parent task"
        )
        let fork = AgentSession(
            id: "f1", providerId: "test", model: "claude",
            customName: "Alternative approach",
            parentSessionId: parent.id,
            forkFromMessageIndex: 0
        )
        XCTAssertEqual(fork.customName, "Alternative approach")
        XCTAssertEqual(parent.customName, "Parent task")
    }

    // MARK: - Codable round-trips

    func testForkFieldsPreservedThroughCodable() throws {
        let session = AgentSession(
            id: "fork-session", providerId: "anthropic", model: "claude-opus-4-6",
            parentSessionId: "original-session",
            forkFromMessageIndex: 7
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentSession.self, from: data)

        XCTAssertEqual(decoded.id, "fork-session")
        XCTAssertEqual(decoded.parentSessionId, "original-session")
        XCTAssertEqual(decoded.forkFromMessageIndex, 7)
        XCTAssertTrue(decoded.isForked)
    }

    func testNilForkFieldsPreservedThroughCodable() throws {
        let session = AgentSession(id: "s1", providerId: "test", model: "claude")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentSession.self, from: data)

        XCTAssertNil(decoded.parentSessionId)
        XCTAssertNil(decoded.forkFromMessageIndex)
        XCTAssertFalse(decoded.isForked)
    }

    // MARK: - displayName for forked sessions

    func testForkedSessionDisplayNameUsesCustomName() {
        let session = AgentSession(
            id: "f1", providerId: "test", model: "claude",
            customName: "Fork: new approach",
            parentSessionId: "p1"
        )
        XCTAssertEqual(session.displayName, "Fork: new approach")
    }

    func testForkedSessionDisplayNameUsesWorkItemId() {
        let session = AgentSession(
            id: "f1", providerId: "test", model: "claude",
            workItemId: "TICKET-42",
            parentSessionId: "p1"
        )
        XCTAssertEqual(session.displayName, "TICKET-42")
    }

    func testForkedSessionDisplayNameFallsBackToFirstUserMessage() {
        let msg = AgentMessage(role: .user, content: "Try a different approach")
        let session = AgentSession(
            id: "f1", providerId: "test", model: "claude",
            messages: [msg],
            parentSessionId: "p1"
        )
        XCTAssertEqual(session.displayName, "Try a different approach")
    }

    func testForkedSessionDisplayNameFallsBackToSession() {
        let session = AgentSession(
            id: "f1", providerId: "test", model: "claude",
            parentSessionId: "p1"
        )
        XCTAssertEqual(session.displayName, "Session")
    }

    // MARK: - Multiple fork levels

    func testMultipleLevelsOfForking() {
        let root = AgentSession(id: "root", providerId: "test", model: "claude")

        let fork1 = AgentSession(
            id: "fork1", providerId: "test", model: "claude",
            parentSessionId: root.id,
            forkFromMessageIndex: 3
        )

        let fork2 = AgentSession(
            id: "fork2", providerId: "test", model: "claude",
            parentSessionId: fork1.id,
            forkFromMessageIndex: 1
        )

        XCTAssertFalse(root.isForked)
        XCTAssertTrue(fork1.isForked)
        XCTAssertTrue(fork2.isForked)
        XCTAssertEqual(fork2.parentSessionId, "fork1")
        XCTAssertEqual(fork1.parentSessionId, "root")
    }

    // MARK: - isBackground with fork

    func testForkedSessionCanBeBackground() {
        let session = AgentSession(
            id: "f1", providerId: "test", model: "claude",
            isBackground: true,
            parentSessionId: "p1"
        )
        XCTAssertTrue(session.isBackground)
        XCTAssertTrue(session.isForked)
    }

    // MARK: - forkFromMessageIndex independent of parentSessionId

    func testForkIndexWithoutParentIdIsAllowed() {
        // Structural test: the model allows this combination (no validation constraint)
        let session = AgentSession(
            id: "s1", providerId: "test", model: "claude",
            forkFromMessageIndex: 2
        )
        XCTAssertNil(session.parentSessionId)
        XCTAssertEqual(session.forkFromMessageIndex, 2)
        XCTAssertFalse(session.isForked) // isForked only checks parentSessionId
    }
}
