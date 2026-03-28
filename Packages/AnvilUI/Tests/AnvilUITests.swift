import XCTest
@testable import AnvilUI

final class AnvilUITests: XCTestCase {
    @MainActor
    func testAppStateSpaceSwitching() {
        let state = AppState()
        state.switchSpace(.review)
        XCTAssertEqual(state.currentSpace, .review)
    }

    func testAllSpacesHaveIcons() {
        for space in AnvilSpace.allCases {
            XCTAssertFalse(space.icon.isEmpty)
        }
    }
}
