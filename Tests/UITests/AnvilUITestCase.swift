import XCTest

/// Base class for all Anvil UI tests.
/// Automatically attaches screenshots at key states so agents and reviewers
/// can visually verify features without launching the app manually.
class AnvilUITestCase: XCTestCase {

    var app: XCUIApplication!

    /// Override in subclasses that want to launch manually with custom state.
    var shouldAutoLaunchApp: Bool { true }

    /// Additional launch arguments used by the default bootstrap path.
    var launchArguments: [String] { [] }

    /// Additional launch environment used by the default bootstrap path.
    /// UI tests always bypass first-run setup to keep launch deterministic.
    var launchEnvironment: [String: String] {
        ["ANVIL_SKIP_SETUP_WIZARD": "1"]
    }

    /// Capture the default launch screenshot for this test.
    var shouldCaptureLaunchScreenshot: Bool { true }

    /// Capture a teardown screenshot when the test finishes.
    var shouldCaptureTearDownScreenshot: Bool { true }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        if shouldAutoLaunchApp {
            launchApp()
        }
    }

    override func tearDownWithError() throws {
        if shouldCaptureTearDownScreenshot {
            addScreenshot("teardown")
        }
        app?.terminate()
        try super.tearDownWithError()
    }

    /// Launch the app with optional overrides, preserving the app's fixed-size default recipe.
    func launchApp(
        additionalArguments: [String] = [],
        additionalEnvironment: [String: String] = [:],
        captureLaunchScreenshot: Bool? = nil
    ) {
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"] + launchArguments + additionalArguments

        var environment = launchEnvironment
        for (key, value) in additionalEnvironment {
            environment[key] = value
        }
        app.launchEnvironment = environment

        app.launch()
        waitForAppWindow()

        if captureLaunchScreenshot ?? shouldCaptureLaunchScreenshot {
            addScreenshot("launch")
        }
    }

    private func waitForAppWindow(timeout: TimeInterval = 10) {
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: timeout)
    }

    // MARK: - Screenshot helpers

    /// Attach a screenshot with the given name. All screenshots are kept always
    /// so they appear in the xcresult bundle and can be extracted by agents.
    func addScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Navigate to a space by clicking its icon rail button, then screenshot.
    func navigateToSpace(_ name: String) {
        let btn = app.buttons[name]
        if btn.exists { btn.click() }
        addScreenshot("space-\(name.lowercased())")
    }

    /// Wait for an element to appear, adding a screenshot when it does.
    @discardableResult
    func waitAndScreenshot(_ element: XCUIElement, name: String, timeout: TimeInterval = 3) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        addScreenshot(name)
        return exists
    }
}
