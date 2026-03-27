import XCTest
@testable import AnvilDomain

final class AnvilDomainTests: XCTestCase {
    func testEntityIdGeneration() {
        let id1 = EntityID<String>()
        let id2 = EntityID<String>()
        XCTAssertNotEqual(id1, id2)
    }

    func testEntityIdFromStringLiteral() {
        let id: EntityID<String> = "test-id"
        XCTAssertEqual(id.rawValue, "test-id")
    }

    func testTicketPriorityOrdering() {
        XCTAssertTrue(TicketPriority.critical < TicketPriority.high)
        XCTAssertTrue(TicketPriority.high < TicketPriority.medium)
        XCTAssertTrue(TicketPriority.medium < TicketPriority.low)
    }

    func testApprovalPolicyDefaultAsks() {
        let policy = ApprovalPolicy(rules: [
            ApprovalRule(pattern: "read_", action: .autoApprove),
            ApprovalRule(pattern: "write_", action: .ask),
        ])
        XCTAssertFalse(policy.requiresApproval(for: "read_file"))
        XCTAssertTrue(policy.requiresApproval(for: "write_file"))
        XCTAssertTrue(policy.requiresApproval(for: "unknown_tool"))
    }
}
