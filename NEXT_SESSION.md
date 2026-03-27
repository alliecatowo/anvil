# Next Session Priorities

## P0 — Must fix before anything else

1. **Editor crashes when clicking through files** — pinwheel/lag when navigating file tree. Likely unbounded re-rendering or missing virtualization. Profile with Instruments, fix the hot path.

2. **Rewrite ALL tests to verify click RESULTS, not element existence** — Current tests are useless. A test that passes when buttons don't work is worse than no test. Every test should: click a thing → verify the RESULT changed (new view appeared, state updated, data changed). Use XCTAssertTrue with waitForExistence on the RESULT, not the button.

3. **Make ALL sidebar items interactive** — Auxiliary sidebars (Editor, DB, Terminal, Docs, Messaging, Notifications, Testing, Extensions) are static labels. Each item needs: tap handler → update ViewModel → change content area. No decoration without function.

4. **Real PTY terminal** — #1 most embarrassing gap. forkpty(), spawn $SHELL, ANSI colors, .zshrc loading. Users expect a real shell.

5. **Wire ACP provider config end-to-end** — Settings → save API key → create provider → Agent mode can actually stream from Claude. The pieces exist but aren't connected.

## P1 — High impact

6. **Claude Code conversation history** — Load previous Claude Code sessions into Agent mode. Read from ~/.claude/ or wherever CC stores history.

7. **Performance audit** — Editor file tree, large file handling, mode switching latency. Profile everything.

8. **Fix all NSApp.sendAction usages** — Replace remaining instances with SettingsLink or proper SwiftUI navigation.

9. **Collapsible sidebar sections** — Items that look collapsible should actually collapse. Wire chevron state.

10. **Search panel positioning** — ⌘⇧F panel should be properly positioned, not overlapping content.

## Testing Philosophy (for next session)

**Bad test (what we have now):**
```swift
func testNewSession() {
    let button = app.buttons["New Session"]
    XCTAssertTrue(button.exists) // USELESS — button exists but might not work
}
```

**Good test (what we need):**
```swift
func testNewSession() {
    let button = app.buttons["New Session"]
    XCTAssertTrue(button.exists)
    button.click()

    // Verify the RESULT — a new session appeared
    let sessionList = app.scrollViews.firstMatch
    let sessionItem = sessionList.buttons.firstMatch
    XCTAssertTrue(sessionItem.waitForExistence(timeout: 3), "New session should appear in sidebar")

    // Verify we're in conversation view, not empty state
    let inputField = app.textFields["Message the agent..."]
    XCTAssertTrue(inputField.waitForExistence(timeout: 3), "Input field should appear for new session")
}
```

Every test: action → verify result. No exceptions.

## Three Test Layers Required

### 1. Unit Tests (XCTest — fast, no UI)
Test ViewModels and domain logic in isolation:
```swift
func testStartNewSessionCreatesSession() {
    let vm = AgentViewModel()
    XCTAssertEqual(vm.sessions.count, 0)
    vm.startNewSession(prompt: "", model: "claude-sonnet-4-6")
    XCTAssertEqual(vm.sessions.count, 1)
    XCTAssertNotNil(vm.selectedSessionId)
    XCTAssertEqual(vm.selectedSession?.status, .idle)
}
```

### 2. Integration Tests (XCTest — test real wiring)
Test that layers connect properly:
```swift
func testAcpProviderStreamsResponse() async {
    let client = ACPClient()
    let provider = OllamaProvider() // or mock
    await client.registerProvider(provider)
    let p = await client.provider("ollama")
    XCTAssertNotNil(p)
}
```

### 3. E2E UI Tests (XCUITest — full click-through flows)
Test complete user journeys, every micro-interaction:
```swift
func testFullAgentWorkflow() {
    let app = XCUIApplication()
    app.launch()

    // 1. Click Agent tab
    app.buttons["Agent"].click()

    // 2. Click New Session
    let newSession = app.buttons["New Session"]
    XCTAssertTrue(newSession.waitForExistence(timeout: 3))
    newSession.click()

    // 3. Verify conversation view appeared
    let inputField = app.textFields["Message the agent..."]
    XCTAssertTrue(inputField.waitForExistence(timeout: 3))

    // 4. Type a message
    inputField.click()
    inputField.typeText("Hello, fix the auth bug")

    // 5. Click send
    app.buttons["Send"].click()

    // 6. Verify message appears in conversation
    let userMessage = app.staticTexts["Hello, fix the auth bug"]
    XCTAssertTrue(userMessage.waitForExistence(timeout: 5))

    // 7. Verify agent responds (or shows thinking indicator)
    let thinkingOrResponse = app.staticTexts["Thinking..."].exists
        || app.scrollViews.staticTexts.count > 1
    XCTAssertTrue(thinkingOrResponse)
}

func testFullTicketToAgentPipeline() {
    let app = XCUIApplication()
    app.launch()

    // Load demo data first
    app.menuItems["Load Demo Project"].click()

    // 1. Go to Intent mode
    app.buttons["Intent"].click()

    // 2. Click a ticket
    let ticket = app.staticTexts["ANV-101"]
    XCTAssertTrue(ticket.waitForExistence(timeout: 3))
    ticket.click()

    // 3. Verify ticket detail opened
    let title = app.staticTexts["Fix SSO token refresh"]
    XCTAssertTrue(title.waitForExistence(timeout: 3))

    // 4. Click "Start Work"
    let startWork = app.buttons["Start Work"]
    XCTAssertTrue(startWork.waitForExistence(timeout: 3))
    startWork.click()

    // 5. Verify switched to Agent mode with pre-filled session
    let agentTab = app.buttons["Agent"]
    // Agent tab should now be active
    let inputField = app.textFields["Message the agent..."]
    XCTAssertTrue(inputField.waitForExistence(timeout: 5))
}

func testEveryModeHasClickableContent() {
    let app = XCUIApplication()
    app.launch()
    app.menuItems["Load Demo Project"].click()

    let modes = ["Intent", "Agent", "Review", "Ship"]
    for mode in modes {
        app.buttons[mode].click()

        // Each mode should have SOMETHING clickable beyond the tab itself
        let clickableElements = app.buttons.allElementsBoundByIndex
            .filter { $0.isHittable && $0.label != mode }
        XCTAssertGreaterThan(clickableElements.count, 0,
            "\(mode) mode should have clickable elements")
    }
}

func testCommandPaletteSearchAndExecute() {
    let app = XCUIApplication()
    app.launch()

    // Open command palette
    app.typeKey("k", modifierFlags: .command)

    let searchField = app.textFields.firstMatch
    XCTAssertTrue(searchField.waitForExistence(timeout: 2))

    // Search for "Agent"
    searchField.typeText("Agent")

    // Verify results appeared
    let result = app.staticTexts["Switch to Agent"]
    XCTAssertTrue(result.waitForExistence(timeout: 2))

    // Click result
    result.click()

    // Verify mode actually switched
    // (command palette should dismiss and Agent mode should be active)
    XCTAssertFalse(searchField.exists, "Palette should dismiss after execution")
}
```

### Coverage Target — EVERY feature, not just agent mode

The examples above are just examples. The test suite must cover EVERY mode, EVERY sidebar, EVERY button, EVERY interaction in the entire app. The test writer agent should:

1. **Enumerate every clickable element in every mode** — walk the entire UI tree
2. **For each element, write a test that clicks it and verifies the result**
3. **For each mode**: verify sidebar items are clickable, content updates on selection, empty states show CTAs, demo data populates correctly
4. **For each form/input**: type text, submit, verify state changed
5. **Cross-mode flows**: Intent→Agent, Agent→Review, Review→Ship (the full pipeline)

Specific coverage needed (not just agent — ALL of these):
- All 13+ modes: click tab → verify content renders, sidebar has items, items are clickable
- Intent: create ticket, drag on kanban, click ticket detail, link tickets, dispatch to agent
- Agent: new session, send message, get response, slash commands, @ refs, model picker, export, rename, delete, synthesis room, plan view, background session
- Review: inbox click, diff renders, approve/reject hunks, PR detail, merge button, blame toggle, git graph
- Ship: environment cards, deploy button, build logs, env vars, rollback
- Editor: open file, syntax highlighting renders, find/replace, breadcrumbs, split editor, code folding, inline edit, word wrap, whitespace viz, indent guides, git gutter
- Database: schema tree clickable, run query, results render
- Terminal: input works, output renders (once PTY is real)
- Docs: doc tree clickable, editor renders, preview works
- Messaging: channel list clickable, chat renders, send message
- Notifications: inbox items clickable, action buttons work, preferences open
- Observability: error list clickable, detail renders, metrics show
- Schedule: agenda items clickable, time blocks render
- Testing: test tree clickable, run button works, results render
- Extensions: plugin cards clickable, install/uninstall works
- Command palette: open, search, navigate, execute — for files, symbols, and commands
- Quick capture: open, type, select type, submit
- Project notes: open, type, save
- Settings: every tab, every toggle, provider config
- Source control: stage/unstage, commit, push/pull, stash, tags, branches, remotes
- Status bar: branch click opens picker, settings gear opens settings, cursor position clickable

**If a test passes but the feature doesn't work, the test is a bug.**
