import XCTest
@testable import AnvilUI

final class AnvilUITests: XCTestCase {
    @MainActor
    func testAppStateModeSwitching() {
        let state = AppState()
        state.switchMode(.review)
        XCTAssertEqual(state.currentMode, .review)
    }

    func testAllModesHaveIcons() {
        for mode in AnvilMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
        }
    }
}
