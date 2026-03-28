import XCTest
@testable import AnvilInfrastructure

final class AnvilInfrastructureTests: XCTestCase {
    func testFileStorePathResolution() async {
        let store = FileStore(basePath: "/tmp/anvil-test")
        let exists = await store.exists(path: "nonexistent-file")
        XCTAssertFalse(exists)
    }
}
