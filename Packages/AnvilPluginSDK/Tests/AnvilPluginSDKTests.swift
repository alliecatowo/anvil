import XCTest
@testable import AnvilPluginSDK

final class AnvilPluginSDKTests: XCTestCase {
    func testPluginMetadataCreation() {
        let metadata = PluginMetadata(
            id: "com.test.plugin",
            name: "Test Plugin",
            version: "1.0.0",
            provides: [.provider(for: "observability", id: "test-obs")],
            views: [.sidebarSection(mode: "ship", id: "test-sidebar")],
            commands: [.command(id: "test.action", title: "Test Action")]
        )

        XCTAssertEqual(metadata.id, "com.test.plugin")
        XCTAssertEqual(metadata.provides.count, 1)
        XCTAssertEqual(metadata.views.count, 1)
        XCTAssertEqual(metadata.commands.count, 1)
    }

    func testPrimitiveRequirementCreation() {
        let req = PrimitiveRequirement.primitive("source-control")
        XCTAssertEqual(req.primitiveId, "source-control")
    }
}
