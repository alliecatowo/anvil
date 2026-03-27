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
