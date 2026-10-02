# Anvil

Agent-native development environment for macOS. Swift 6, SwiftUI, macOS 15+.

For the full architecture, current feature status, and build instructions see:
`ARCHITECTURE/OVERVIEW.md`

## Architecture (summary)

Hexagonal architecture (ports and adapters) with DDD:
- **AnvilDomain** — Pure Swift domain layer. Zero dependencies. Primitives (ports), entities, value objects, domain events.
- **AnvilApplication** — Use cases, event bus, services. Depends on Domain only.
- **AnvilACP** — AI provider protocol and implementations. The universal AI backbone.
- **AnvilInfrastructure** — Adapters (providers). Depends on Domain + Application.
- **AnvilUI** — SwiftUI presentation. Depends on Application + Domain. NEVER imports Infrastructure directly.
- **AnvilPluginSDK** — Public SDK for plugin developers.
- **AnvilEditor** — Editor engine (future: Tree-sitter, LSP).
- **AnvilTerminal** — Terminal emulator (future: SwiftTerm).
- **AnvilGit** — Git operations (future: libgit2).

## Key Concepts

- **Primitives** = Ports (abstract contracts). 25 total defined in SPEC.md.
- **Providers** = Adapters (concrete implementations). Swappable at runtime.
- **ACP** = Agent Communication Protocol. Every AI feature flows through ACP. Plugins get AI for free.
- **Shell vocabulary** = Plan, Build, Review, Operate, Library, plus canonical shell regions `Workspace Rail`, `Sidebar`, `Canvas`, `Inspector`, `Utility Deck`, `Toolbar`, and `Status Bar`. See [`ARCHITECTURE/SHELL_VOCABULARY.md`](ARCHITECTURE/SHELL_VOCABULARY.md).

## Build

```bash
./scripts/dev --generate-only
xcodebuild -project Anvil.xcodeproj -scheme Anvil -derivedDataPath /tmp/anvil-derived build
./scripts/test-packages
```

Open `Anvil.xcodeproj` for normal development. Do not open the repo root as a Swift package workspace.

## Visual Verification — REQUIRED for all UI agents

**Every UI agent MUST visually verify their work before marking a task complete.**

### Build and launch

```bash
# Build
xcodebuild -project Anvil.xcodeproj -scheme Anvil -derivedDataPath /tmp/anvil-derived build

# Launch (non-interactive)
open /tmp/anvil-derived/Build/Products/Debug/Anvil.app
sleep 3  # wait for launch
```

### Screenshot a window

```bash
# Get Anvil's window ID
WINDOW_ID=$(osascript -e 'tell application "System Events" to get id of first window of process "Anvil"')
screencapture -l $WINDOW_ID -x /tmp/anvil-screenshot.png
# Then Read /tmp/anvil-screenshot.png to view it
```

### Click through the UI (use accessibility tree, not coordinates)

```bash
# AppleScript — click a named button
osascript -e 'tell application "System Events" to tell process "Anvil" to click button "Settings" of window 1'

# JXA — more powerful, use for navigation
osascript -l JavaScript -e '
  const app = Application("Anvil");
  app.activate();
'
```

### XCUITest with screenshots (preferred for structured traversal)

All UI tests MUST attach screenshots at key states:

```swift
func addScreenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

Run tests and extract screenshots:

```bash
xcodebuild test -project Anvil.xcodeproj -scheme Anvil \
  -destination 'platform=macOS' \
  -resultBundlePath /tmp/anvil-test-results.xcresult

xcrun xcresulttool get --path /tmp/anvil-test-results.xcresult --format json
```

### Agent workflow

1. Build the feature
2. Build the app (`xcodebuild ... build`)
3. Launch app and take a screenshot
4. Read the screenshot to visually verify the feature looks correct
5. If it looks wrong, fix it and repeat from step 2
6. Only mark task complete after visual confirmation

## macOS Tahoe Aesthetic — MANDATORY for all UI

Every pixel of user-facing UI must look like Apple built it for macOS Tahoe (macOS 26). No exceptions.

### Materials and surfaces
- `.ultraThinMaterial` or `.regularMaterial` for all panels, popovers, sidebars
- `.glassEffect(.regular)` for the new Tahoe liquid glass (macOS 26 API) on cards, overlays, inspector panels
- No custom opaque backgrounds where a material would be appropriate
- Window chrome: `NSVisualEffectView` vibrancy — use `.sidebar` for sidebars, `.underWindowBackground` for content

### Typography
- System fonts only: `.system`, `.headline`, `.subheadline`, `.caption`, `.footnote`
- `AnvilFont` wrappers must map to system semantic sizes
- No custom font files unless brand-critical
- Use `.monospacedDigit` for numbers (cost, token counts, line numbers)

### Controls and interactions
- Buttons: `.bordered` / `.borderedProminent` / `.plain` — never custom background+border combos
- Pickers: `.segmented` for 2-4 choices in toolbars, `.menu` in forms
- Lists: `.sidebar` style in sidebars, `.inset` in content areas — never `alternatesRowBackgrounds: true`
- Tables: native `Table` with `TableColumn` — no alternating stripes via custom code
- Toolbars: `ToolbarItem` in `.toolbar` modifier — no floating HStacks posing as toolbars
- Empty states: centered icon (SF Symbol, `.thin` weight, 28pt) + label + optional action button

### Color
- `Color.accentColor` for interactive elements — respect the user's accent color setting
- `.primary` / `.secondary` / `.tertiary` for text hierarchy
- `.red` / `.orange` / `.green` for semantic states (error/warning/success)
- No hardcoded hex colors in UI code

### Animation
- `withAnimation(.spring(response: 0.3, dampingFraction: 0.8))` for state transitions
- Pulsing indicators: `scaleEffect` + `opacity` loop, never spinning custom shapes
- Sheet/popover presentations: use native `.sheet`, `.popover`, `.inspector` modifiers

### What NOT to do
- No `ZStack` + `RoundedRectangle` + `.fill` custom buttons
- No `VStack` tab bars — use `SidebarTabBar` (already in AnvilSidebarKit)
- No web-style card grids in sidebars
- No fixed-height rows that create phantom empty stripes
- No `frame(minHeight:)` on Lists or Tables

## Critical Rules

- AnvilUI NEVER imports AnvilInfrastructure. All communication goes through Application layer protocols.
- First-party plugins use the same API as third-party. No private APIs.
- All types must be Sendable (Swift 6 strict concurrency).
- Every domain event flows through the EventBus.
- Agent sessions get isolated worktrees automatically.
- No visible affordance ships unless it is in `TRUTH_MATRIX.md` with a real handler.
- No shortcut label appears in UI unless the command exists and is wired.
- Shell work (rail, sidebar, inspector, utility deck) lands before or with feature breadth.
- **UI agents MUST visually verify their work via screenshot before marking complete.** See Visual Verification above.

## Governance Documents

| Document | Purpose |
|---|---|
| `ARCHITECTURE/OVERVIEW.md` | Full architecture, feature status, build instructions |
| `ARCHITECTURE/TASK_REGISTRY.md` | Master task list: 338 tasks with priorities |
| `ARCHITECTURE/SHELL_VOCABULARY.md` | Canonical shell names, hierarchy, and grouping model |
| `ARCHITECTURE/SHELL_STANDARDIZATION_TASKS.md` | Long-form migration backlog for the standardized shell model |
| `ARCHITECTURE/UX_SHELL.md` | Shell contract: ownership rules for every window region |
| `ARCHITECTURE/PROVIDER_MODEL.md` | Multi-provider rules and capability sets |
| `ARCHITECTURE/COMPETITOR_GAP.md` | Gap analysis vs Cursor, Windsurf, Zed, Xcode, Linear, GitHub, Raycast |
| `ROADMAP_NATIVE_2026.md` | Canonical 100-task phased roadmap |
| `TRUTH_MATRIX.md` | Anti-stub ledger: every visible affordance mapped to a real handler |
| `UI_IMPLEMENTATION_GOVERNANCE.md` | Rules for what can ship and what cannot |
| `SPEC.md` | Full product specification |
