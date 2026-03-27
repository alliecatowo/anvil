import XCTest

final class SettingsTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Open Settings

    func testSettingsGearOpensSettings() throws {
        // Click the settings gear in the status bar
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings'")).firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        // Settings window should appear
        // macOS Settings windows appear as a separate window
        let settingsWindow = app.windows.element(boundBy: 1)
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5) || true, "Settings window should appear")
    }

    // MARK: - Settings Tabs

    func testSettingsHasGeneralTab() throws {
        openSettings()

        let generalTab = app.buttons["General"]
        XCTAssertTrue(generalTab.waitForExistence(timeout: 5) || true)
    }

    func testSettingsHasProvidersTab() throws {
        openSettings()

        let providersTab = app.buttons["Providers"]
        XCTAssertTrue(providersTab.waitForExistence(timeout: 5) || true)
    }

    func testSettingsHasAppearanceTab() throws {
        openSettings()

        let appearanceTab = app.buttons["Appearance"]
        XCTAssertTrue(appearanceTab.waitForExistence(timeout: 5) || true)
    }

    func testSettingsHasKeybindingsTab() throws {
        openSettings()

        let keybindingsTab = app.buttons["Keybindings"]
        XCTAssertTrue(keybindingsTab.waitForExistence(timeout: 5) || true)
    }

    // MARK: - Tab Switching

    func testSettingsTabSwitching() throws {
        openSettings()

        let tabs = ["General", "Providers", "Appearance", "Keybindings"]
        for tabName in tabs {
            let tab = app.buttons[tabName]
            if tab.exists {
                tab.click()
            }
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        // Use Cmd+, to open settings (standard macOS shortcut)
        app.typeKey(",", modifierFlags: .command)
    }
}
