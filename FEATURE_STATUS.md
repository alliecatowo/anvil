# Anvil Feature Status — Complete Audit

> [!WARNING]
> This file is a point-in-time generated audit and may be stale.
> It is not a release gate and it is not the canonical source of truth.
> Use [`ROADMAP_NATIVE_2026.md`](ROADMAP_NATIVE_2026.md) for order, [`TRUTH_MATRIX.md`](TRUTH_MATRIX.md) for visible affordances, and [`UI_IMPLEMENTATION_GOVERNANCE.md`](UI_IMPLEMENTATION_GOVERNANCE.md) for rules.

*Generated 2026-03-27. Based on static analysis of all packages: AnvilUI, AnvilDomain, AnvilApplication, AnvilACP, AnvilInfrastructure, AnvilGit.*

---

## CRITICAL BUGS (Fix First)

### Bug 1 — Typing Intercepted / Users Can't Type in Input Fields

**Root cause:** `KeyEventRouter` is installed via `.keyEventRouter()` on the entire `MainWindow` at the root level (MainWindow.swift line ~93). It uses `.onKeyPress(phases: .down)` at the window root, which intercepts ALL key presses before child views.

While the router returns `.ignored` for most keys, the `ChordTracker` inside it intercepts single bare characters (no modifiers). When a chord is pending (user has pressed `g`), the NEXT character typed is consumed by chord matching, not delivered to any TextField. This makes typing in text fields unreliable — pressing `g` then `b` triggers the "goto.branch" chord instead of typing "gb".

Additionally, if any overlay (CommandPalette, QuickCapture) appears with `@FocusState`-driven auto-focus (`.onAppear { isSearchFocused = true }`), that TextField steals focus from whatever the user was typing in.

**Files:**
- `Packages/AnvilUI/Sources/Keyboard/KeyEventRouter.swift` — root-level `.onKeyPress(phases: .down)` handler
- `Packages/AnvilUI/Sources/Keyboard/ChordTracker.swift` — consumes single characters when chord is pending
- `Packages/AnvilUI/Sources/Shell/CommandPalette.swift` — `.onAppear { isSearchFocused = true }`
- `Packages/AnvilUI/Sources/Shell/MainWindow.swift` — where `.keyEventRouter()` is applied

---

### Bug 2 — Sidebar Items Unclickable

**Root cause (primary):** All four overlay views (CommandPalette, QuickCapture, ProjectSwitcher, CodebaseQAView) render a full-screen `Color.black.opacity(0.4).ignoresSafeArea()` backdrop that occupies the ENTIRE screen including the sidebar area. This backdrop has an `.onTapGesture` to dismiss the overlay, meaning every tap anywhere — including on sidebar items — is consumed by the backdrop, never reaching sidebar views underneath.

This is visible in the `.overlay {}` block in MainWindow.swift (lines ~60–74): overlays are applied AFTER the sidebar in the view hierarchy, so they sit on top.

**Root cause (secondary):** `navItem()` helper in `Sidebar.swift` (lines ~269–293, used by AuxiliarySidebar) builds rows with `.contentShape(Rectangle())` but has **no `.onTapGesture` or `Button` action**. Even if overlays weren't blocking, tapping auxiliary sidebar items does nothing.

**Files:**
- `Packages/AnvilUI/Sources/Shell/MainWindow.swift` — overlay block that places full-screen tap-capturing backdrops over entire window
- `Packages/AnvilUI/Sources/Shell/CommandPalette.swift:12–19` — `Color.black.opacity(0.4).ignoresSafeArea().onTapGesture {}`
- `Packages/AnvilUI/Sources/Shell/QuickCapture.swift:31–37` — same pattern
- `Packages/AnvilUI/Sources/Shell/CodebaseQAView.swift:23–27` — same pattern
- `Packages/AnvilUI/Sources/Shell/Sidebar.swift:269–293` — `navItem()` missing tap handler

---

## SHELL / GLOBAL

### App Entry Point & Window Layout
**Mode:** Global
**Expected behavior:** App launches, shows main window with mode tabs, sidebar, content area, status bar.
**Current status:** WORKING
**Evidence:** `AnvilApp.swift` has proper `@main`, `WindowGroup`, `AppState`+`DependencyContainer` as `@StateObject`, `.keyEventRouter()` applied. `MainWindow` assembles all panels correctly.
**Files:** `App/AnvilApp.swift`, `Packages/AnvilUI/Sources/Shell/MainWindow.swift`

---

### Mode Tab Bar
**Mode:** Global
**Expected behavior:** Shows Intent/Agent/Review/Ship (labeled) + auxiliary modes (icons). Clicking switches mode. Active mode highlighted.
**Current status:** WORKING
**Evidence:** `ModeTabBar.swift` renders core modes with labels and auxiliary modes as compact icons. Mode switching calls `appState.switchMode()`. ⌘1–9 shortcuts registered in `AnvilCommands.swift`.
**Files:** `Packages/AnvilUI/Sources/Shell/ModeTabBar.swift`, `Packages/AnvilUI/Sources/App/AnvilCommands.swift`

---

### Sidebar (container)
**Mode:** Global
**Expected behavior:** Collapses to 48px icon rail, resizes, dispatches to mode-specific sidebar.
**Current status:** PARTIAL
**Evidence:** Sidebar.swift delegates to `AgentSidebar`, `IntentSidebar`, `ReviewSidebar`, `ShipSidebar`, `AuxiliarySidebar`. Collapse/expand logic exists. Resize not confirmed.
**Root cause (if broken):** AuxiliarySidebar's `navItem()` helper lacks tap handlers (secondary bug above).
**Files:** `Packages/AnvilUI/Sources/Shell/Sidebar.swift`

---

### Command Palette
**Mode:** Global
**Expected behavior:** ⌘K opens palette. Fuzzy-search commands, files, symbols. Keyboard nav. Enter executes.
**Current status:** WORKING (but contributes to Bug 2)
**Evidence:** `CommandPalette.swift` + `CommandPaletteViewModel.swift` implement fuzzy matching, three modes (commands/files/symbols), keyboard nav, action execution. **But** its full-screen backdrop blocks sidebar clicks when palette is open.
**Files:** `Packages/AnvilUI/Sources/Shell/CommandPalette.swift`, `Packages/AnvilUI/Sources/Shell/CommandPaletteViewModel.swift`

---

### Status Bar
**Mode:** Global
**Expected behavior:** Shows project switcher, branch, agent activity, cursor position, encoding.
**Current status:** WORKING
**Evidence:** `StatusBar.swift` — branch picker, project switcher, agent activity indicator, cursor position (line:col), encoding display all present.
**Files:** `Packages/AnvilUI/Sources/Shell/StatusBar.swift`

---

### Content Area
**Mode:** Global
**Expected behavior:** Displays the correct mode view based on current mode selection.
**Current status:** WORKING
**Evidence:** `ContentArea.swift` switches on `appState.currentMode` and renders appropriate mode views.
**Files:** `Packages/AnvilUI/Sources/Shell/ContentArea.swift`

---

### Quick Capture (⌘⇧Space)
**Mode:** Global
**Expected behavior:** Overlay appears, user types quick note, saves to project notes.
**Current status:** STUB
**Evidence:** `QuickCapture.swift` has UI with TextField and save/dismiss handlers, but saving is a local stub (no real persistence to project notes). Also contributes to Bug 2 via full-screen backdrop.
**Files:** `Packages/AnvilUI/Sources/Shell/QuickCapture.swift`

---

### Project Switcher
**Mode:** Global
**Expected behavior:** Switch between open projects.
**Current status:** STUB
**Evidence:** `ProjectSwitcher.swift` has search UI and keyboard nav, but project list is empty/fake. Also contributes to Bug 2 via full-screen backdrop.
**Files:** `Packages/AnvilUI/Sources/Shell/ProjectSwitcher.swift`

---

### Codebase Q&A
**Mode:** Global
**Expected behavior:** Ask questions about the codebase, get answers with file citations.
**Current status:** STUB
**Evidence:** `CodebaseQAView.swift` has TextField UI but no real ACP integration for actual Q&A. Also contributes to Bug 2 via full-screen backdrop.
**Files:** `Packages/AnvilUI/Sources/Shell/CodebaseQAView.swift`

---

### Project Notes (⌘⇧N)
**Mode:** Global
**Expected behavior:** Scratchpad for project-level notes, persisted.
**Current status:** STUB
**Evidence:** `ProjectNotes.swift` + `ProjectNotesViewModel.swift` exist, markdown editor present, but persistence unclear.
**Files:** `Packages/AnvilUI/Sources/Shell/ProjectNotes.swift`

---

### Inspector Panel (⌘⇧I)
**Mode:** Global
**Expected behavior:** Right-side contextual detail panel, 320px default.
**Current status:** STUB
**Evidence:** `InspectorPanel.swift` exists but content is empty placeholder.
**Files:** `Packages/AnvilUI/Sources/Shell/InspectorPanel.swift`

---

### Terminal Bottom Panel (⌘J)
**Mode:** Global
**Expected behavior:** Terminal always accessible from any mode via bottom panel toggle.
**Current status:** STUB
**Evidence:** `TerminalPanel.swift` exists but is a placeholder stub. Real PTY (`AnvilTerminal` package) does not exist.
**Files:** `Packages/AnvilUI/Sources/Shell/TerminalPanel.swift`

---

### Source Control Panel
**Mode:** Global
**Expected behavior:** VS Code-style git panel with staged/unstaged changes, commit UI, branch ops.
**Current status:** STUB
**Evidence:** `SourceControlPanel.swift` is a stub. However real git operations ARE implemented in `AnvilGit` — panel just needs real wiring.
**Files:** `Packages/AnvilUI/Sources/Shell/SourceControlPanel.swift`, `Packages/AnvilGit/Sources/`

---

### Search Panel (⌘⇧F)
**Mode:** Global
**Expected behavior:** Full-text project-wide search with results and preview.
**Current status:** STUB
**Evidence:** `SearchPanel.swift` + `ProjectSearchViewModel.swift` are stubs.
**Files:** `Packages/AnvilUI/Sources/Shell/SearchPanel.swift`

---

### Welcome Page
**Mode:** Global
**Expected behavior:** Landing page when no project open, shows recent projects, tips.
**Current status:** WORKING
**Evidence:** `WelcomePage.swift` renders recent projects list and quick-action tips.
**Files:** `Packages/AnvilUI/Sources/Shell/WelcomePage.swift`

---

### Settings Window
**Mode:** Global
**Expected behavior:** Tabbed settings: General, Providers, Appearance, Keybindings.
**Current status:** PARTIAL
**Evidence:** `SettingsWindow.swift` has real tab structure with provider config, appearance, keybindings tabs. Missing: search, per-project overrides, import/export, theme editor, font picker.
**Files:** `Packages/AnvilUI/Sources/Settings/SettingsWindow.swift`

---

### Setup Wizard
**Mode:** Global
**Expected behavior:** First-launch onboarding: welcome → environment scan → ACP config → project setup → ready.
**Current status:** WORKING
**Evidence:** `SetupWizard.swift` has full 5-step flow with real state management.
**Files:** `Packages/AnvilUI/Sources/App/SetupWizard.swift`

---

### GitHub OAuth Login
**Mode:** Global
**Expected behavior:** Device flow GitHub auth with code display and polling.
**Current status:** WORKING
**Evidence:** `GitHubLoginView.swift` + `GitHubAuthViewModel.swift` implement real device flow auth.
**Files:** `Packages/AnvilUI/Sources/Auth/GitHubLoginView.swift`

---

### Keyboard Shortcuts System
**Mode:** Global
**Expected behavior:** ⌘1–9 mode switching, ⌘K palette, ⌘B sidebar, vim-style j/k navigation in lists, chord sequences (g+t, g+b).
**Current status:** PARTIAL (BROKEN — see Bug 1)
**Evidence:** `KeyboardManager.swift`, `KeyEventRouter.swift`, `ChordTracker.swift`, `Keybindings.swift` all exist. Chord system (`g→t`, `g→b` etc.) defined. j/k list navigation and mode-specific bindings (a/r in review, y/n in agent) defined. BUT: chord tracker intercepts bare key presses in a way that breaks TextField input.
**Root cause:** `.onKeyPress(phases: .down)` at MainWindow root + ChordTracker consuming single chars.
**Files:** `Packages/AnvilUI/Sources/Keyboard/`

---

## AGENT MODE

### Agent Sidebar (Session List)
**Mode:** Agent
**Expected behavior:** Lists all sessions, synthesis rooms section, New Session button. Clicking session opens conversation.
**Current status:** WORKING
**Evidence:** `AgentSidebar.swift` — `ForEach(viewModel.sessions)` with real `.onTapGesture { viewModel.selectedSessionId = session.id; viewModel.showConversation() }`. Session rows with context menus. Synthesis rooms section present.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/AgentSidebar.swift`

---

### Conversation View (Chat UI)
**Mode:** Agent
**Expected behavior:** Shows message history, streaming responses, tool call cards, input bar at bottom.
**Current status:** REAL
**Evidence:** `ConversationView.swift` — full implementation with streaming code blocks, tool call rendering, input bar, queued message support (Windsurf-style).
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/ConversationView.swift`

---

### Streaming Code Blocks
**Mode:** Agent
**Expected behavior:** Code in responses renders with syntax highlighting and streaming animation.
**Current status:** WORKING
**Evidence:** `StreamingCodeBlock.swift` — syntax highlighting, streaming animation, copy button.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/StreamingCodeBlock.swift`

---

### Agent Plan View
**Mode:** Agent
**Expected behavior:** Structured plan with steps, progress, approve/cancel buttons, editable steps.
**Current status:** WORKING
**Evidence:** `AgentPlanView.swift` — step list with status tracking, progress bar, user annotations, approve/cancel.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/AgentPlanView.swift`

---

### Session Dashboard
**Mode:** Agent
**Expected behavior:** Grid of all sessions with multi-select, synthesis/critique actions.
**Current status:** WORKING
**Evidence:** `SessionDashboard.swift` — grid layout, multi-select state, synthesis room creation, critique dispatch.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/SessionDashboard.swift`

---

### Synthesis Rooms
**Mode:** Agent
**Expected behavior:** Combine outputs from multiple sessions, orchestrator synthesizes results.
**Current status:** WORKING (UI) / STUB (backend)
**Evidence:** `SynthesisRoomView.swift` exists with real UI. `SynthesisRoom` domain entity defined. But actual synthesis (ACP call that summarizes multiple sessions) is not wired end-to-end.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/SynthesisRoomView.swift`

---

### Token Usage Bar
**Mode:** Agent
**Expected behavior:** Progress bar showing context window consumption.
**Current status:** PARTIAL
**Evidence:** `TokenUsageBar.swift` exists. Token tracking in `AgentSession` entity is real. Visual bar confirmed but real-time update from streaming unclear.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/TokenUsageBar.swift`

---

### Slash Commands (/review, /commit, /test)
**Mode:** Agent
**Expected behavior:** Type `/` in input bar, autocomplete menu appears with commands.
**Current status:** STUB
**Evidence:** `SlashCommandMenu.swift` exists as a UI stub. Command framework referenced in TASKS.md as completed (#11), but view is a stub.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/SlashCommandMenu.swift`

---

### @ Reference Autocomplete
**Mode:** Agent
**Expected behavior:** Type `@` to reference files, tickets, branches with autocomplete popup.
**Current status:** STUB
**Evidence:** `AtReferencePopup.swift` is a stub placeholder.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/AtReferencePopup.swift`

---

### Model Picker
**Mode:** Agent
**Expected behavior:** Per-session model selection (Claude/GPT/Ollama).
**Current status:** STUB
**Evidence:** `ModelPicker.swift` is a stub. `AgentViewModel` has model state but picker UI not implemented.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/ModelPicker.swift`

---

### Auto PR Sheet
**Mode:** Agent
**Expected behavior:** One-click PR creation from completed agent session.
**Current status:** STUB
**Evidence:** `AutoPRSheet.swift` is a stub.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/AutoPRSheet.swift`

---

### Inline Code Edit (⌘K in Editor)
**Mode:** Agent / Editor
**Expected behavior:** Select code → ⌘K → describe change → accept/reject diff hunks.
**Current status:** PARTIAL
**Evidence:** `InlineEditBar.swift` and `InlineEditView.swift` exist with diff hunk UI. Backend (`CodeEditSuggestion`, `EditHunk` domain entities) defined. ACP integration path exists but end-to-end wiring unclear.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/EditorMode/InlineEditBar.swift`

---

### Context Chip / Context Injection
**Mode:** Agent
**Expected behavior:** Drag files/tickets/errors into conversation to inject as context.
**Current status:** STUB
**Evidence:** `ContextChip.swift` is a stub placeholder.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/ContextChip.swift`

---

### Background Agent Sessions
**Mode:** Agent
**Expected behavior:** Sessions run while user works in other modes. Activity indicator in status bar.
**Current status:** WORKING (domain)
**Evidence:** `AgentSession.isBackground` property defined. `AgentViewModel` has backgroundSessions tracking. Status bar activity indicator confirmed in `StatusBar.swift`.
**Files:** `Packages/AnvilUI/Sources/Modes/Agent/AgentViewModel.swift`

---

### Cost Budget Per Session
**Mode:** Agent
**Expected behavior:** Set spend limit; hard stop when exceeded.
**Current status:** WORKING (domain)
**Evidence:** `AgentSession.costBudget`, `hardStopOnBudget`, `budgetUsage` all defined in domain entity. `ACPCostTracker` tracks real costs. UI display of budget/warnings needs verification.
**Files:** `Packages/AnvilDomain/Sources/Agent/AgentSession.swift`, `Packages/AnvilACP/Sources/ACPCostTracker.swift`

---

### ACP Provider (Anthropic/OpenAI/Ollama)
**Mode:** Agent
**Expected behavior:** Real API calls to AI providers.
**Current status:** REAL
**Evidence:** `AnthropicProvider`, `OpenAIProvider`, `OllamaProvider`, `ClaudeProcessProvider`, `ClaudeCLIProvider`, `ZedACPProvider` — all make REAL HTTP/process calls.
**Files:** `Packages/AnvilACP/Sources/`

---

## INTENT MODE (TICKETS)

### Kanban Board
**Mode:** Intent
**Expected behavior:** Cards organized in columns (Todo/In Progress/Done), drag-to-reorder.
**Current status:** WORKING
**Evidence:** `BoardView.swift` — full kanban with drag-drop, WIP limits, column management.
**Files:** `Packages/AnvilUI/Sources/Modes/Intent/BoardView.swift`

---

### Ticket List View
**Mode:** Intent
**Expected behavior:** Flat list of tickets with sorting/filtering.
**Current status:** WORKING
**Evidence:** `TicketListView.swift` present and wired to `IntentViewModel`.
**Files:** `Packages/AnvilUI/Sources/Modes/Intent/TicketListView.swift`

---

### Ticket Detail
**Mode:** Intent
**Expected behavior:** Full ticket view: description, labels, relations, activity log.
**Current status:** PARTIAL
**Evidence:** `TicketDetailView.swift` renders description, labels, relations. Activity log is a stub.
**Files:** `Packages/AnvilUI/Sources/Modes/Intent/TicketDetailView.swift`

---

### Intent Sidebar
**Mode:** Intent
**Expected behavior:** Search, view mode picker (board/list), cycle info, grouped ticket list.
**Current status:** WORKING
**Evidence:** `IntentSidebar.swift` — search, board/list toggle, cycle info, grouped lists with real `.onTapGesture` handlers.
**Files:** `Packages/AnvilUI/Sources/Modes/Intent/IntentSidebar.swift`

---

### Inline Ticket Creation
**Mode:** Intent
**Expected behavior:** Click "+" on board column to add ticket inline.
**Current status:** WORKING
**Evidence:** `BoardView.swift` has quick-add row with inline TextField per column.
**Files:** `Packages/AnvilUI/Sources/Modes/Intent/BoardView.swift`

---

### Ticket Linking (blocks/blocked-by/related)
**Mode:** Intent
**Expected behavior:** Link tickets with relationship types.
**Current status:** WORKING (domain + UI)
**Evidence:** `TicketRelation` entity defined, `IntentViewModel` has relations state. UI in `TicketDetailView`.
**Files:** `Packages/AnvilUI/Sources/Modes/Intent/TicketDetailView.swift`

---

### Ticket → Branch → Agent Pipeline
**Mode:** Intent
**Expected behavior:** One button to checkout branch + dispatch agent from ticket.
**Current status:** WORKING
**Evidence:** TASKS.md #103 marked complete. Button confirmed in `TicketDetailView`.
**Files:** `Packages/AnvilUI/Sources/Modes/Intent/TicketDetailView.swift`

---

### Ticket Sub-tasks / Checklist
**Mode:** Intent
**Expected behavior:** Checklist items within a ticket.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #62 pending. No domain entity for sub-tasks.

---

### Bulk Ticket Actions
**Mode:** Intent
**Expected behavior:** Select multiple tickets, change status/priority/assignee in bulk.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #63 pending.

---

### Ticket Comments / Activity Log
**Mode:** Intent
**Expected behavior:** Comment thread on each ticket with user activity.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #64 pending. Activity log in `TicketDetailView` is a stub.

---

### Sprint Planning View
**Mode:** Intent
**Expected behavior:** Drag tickets from backlog into sprint/cycle.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #115 pending.

---

### Ticket Provider (Real Backend)
**Mode:** Intent
**Expected behavior:** Sync with Linear, Jira, or GitHub Issues.
**Current status:** NOT IMPLEMENTED
**Evidence:** `TicketPort` protocol defined but no concrete adapter exists. All ticket data is in-memory only.

---

## REVIEW MODE

### Review Inbox
**Mode:** Review
**Expected behavior:** Superhuman-style PR inbox with j/k nav, batch ops, pending/completed sections.
**Current status:** WORKING
**Evidence:** `ReviewInboxView.swift` — pending/completed sections, batch actions, keyboard hints.
**Files:** `Packages/AnvilUI/Sources/Modes/Review/ReviewInboxView.swift`

---

### Diff Review (Side-by-Side / Unified)
**Mode:** Review
**Expected behavior:** Show file diffs with per-hunk approve/reject, blame toggle.
**Current status:** WORKING
**Evidence:** `DiffReviewView.swift` — side-by-side and unified modes, hunk-level actions, blame overlay.
**Files:** `Packages/AnvilUI/Sources/Modes/Review/DiffReviewView.swift`

---

### GitHub PR Detail
**Mode:** Review
**Expected behavior:** PR title, body, CI checks, merge button, comments.
**Current status:** PARTIAL
**Evidence:** `GitHubPRDetailView.swift` has CI section, merge button, comments display. Real GitHub API via `GitHubSourceControlCloudAdapter`.
**Files:** `Packages/AnvilUI/Sources/Modes/Review/GitHubPRDetailView.swift`

---

### Inline PR Comments
**Mode:** Review
**Expected behavior:** Add comments on specific diff lines.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #34 pending.

---

### Comment Threads
**Mode:** Review
**Expected behavior:** Threaded replies on review comments.
**Current status:** WORKING
**Evidence:** TASKS.md #197 marked complete. `PRCommentThread` domain entity defined.
**Files:** `Packages/AnvilDomain/Sources/Review/PullRequest.swift`

---

### Git Graph
**Mode:** Review
**Expected behavior:** Visual branch topology / commit DAG.
**Current status:** STUB
**Evidence:** `GitGraphView.swift` is a stub. However `GitGraphBuilder` in `AnvilGit` has real topology logic.
**Files:** `Packages/AnvilUI/Sources/Modes/Review/GitGraphView.swift`, `Packages/AnvilGit/Sources/GitGraphBuilder.swift`

---

### Merge / Rebase from Review
**Mode:** Review
**Expected behavior:** Merge PR, rebase branch from review UI.
**Current status:** PARTIAL
**Evidence:** Merge button present in `GitHubPRDetailView`. `SubmitReviewUseCase` defined. Rebase button present (TASKS.md #201 complete).
**Files:** `Packages/AnvilUI/Sources/Modes/Review/GitHubPRDetailView.swift`

---

### AI Review Summary
**Mode:** Review
**Expected behavior:** AI generates review summary from diff.
**Current status:** NOT IMPLEMENTED (use case exists)
**Evidence:** `AIReviewUseCase` defined in `AnvilApplication`. Takes diff + ACP provider → returns `[ReviewComment]`. Not wired to UI.
**Files:** `Packages/AnvilApplication/Sources/Review/AIReviewUseCase.swift`

---

### Git Blame in Diff
**Mode:** Review
**Expected behavior:** Toggle blame view to see per-line author/commit.
**Current status:** WORKING
**Evidence:** TASKS.md #70 complete. `DiffReviewView` has blame toggle. `git blame --porcelain` in AnvilGit is real.
**Files:** `Packages/AnvilUI/Sources/Modes/Review/DiffReviewView.swift`

---

## SHIP MODE

### Ship Sidebar
**Mode:** Ship
**Expected behavior:** Deployment targets list.
**Current status:** PARTIAL
**Evidence:** `ShipSidebar.swift` exists with deployment targets section. Data is placeholder/stub.
**Files:** `Packages/AnvilUI/Sources/Modes/Ship/ShipSidebar.swift`

---

### Deploy Dashboard
**Mode:** Ship
**Expected behavior:** Status of deployments, health checks, recent builds.
**Current status:** STUB
**Evidence:** `DeployDashboardView.swift` is a stub.
**Files:** `Packages/AnvilUI/Sources/Modes/Ship/DeployDashboardView.swift`

---

### Build Log Viewer
**Mode:** Ship
**Expected behavior:** Stream/view build logs.
**Current status:** STUB
**Evidence:** `BuildLogView.swift` is a stub.
**Files:** `Packages/AnvilUI/Sources/Modes/Ship/BuildLogView.swift`

---

### Env Var Manager
**Mode:** Ship
**Expected behavior:** View/edit environment variables per environment.
**Current status:** STUB
**Evidence:** `EnvVarManagerView.swift` is a stub.
**Files:** `Packages/AnvilUI/Sources/Modes/Ship/EnvVarManagerView.swift`

---

### Real Deployment Provider
**Mode:** Ship
**Expected behavior:** Connect to Vercel/Railway/Fly.io and trigger real deployments.
**Current status:** NOT IMPLEMENTED
**Evidence:** `HostingPort` protocol defined. No concrete adapter. TASKS.md #38 pending.

---

## EDITOR MODE

### File Tree Sidebar
**Mode:** Editor
**Expected behavior:** Collapsible directory tree, file icons, source control toggle.
**Current status:** WORKING
**Evidence:** `EditorSidebar.swift` — folder expansion, file selection, source control toggle.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/EditorMode/EditorSidebar.swift`

---

### Split Editor
**Mode:** Editor
**Expected behavior:** ⌘\ splits vertically, ⌘⇧\ horizontally.
**Current status:** WORKING
**Evidence:** TASKS.md #42 complete. `SplitEditorState.swift`, `EditorPaneView.swift` implement real split logic.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/EditorMode/SplitEditorState.swift`

---

### Find/Replace (in file + project)
**Mode:** Editor
**Expected behavior:** ⌘F for in-file, ⌘⇧F for project-wide.
**Current status:** WORKING (UI) / PARTIAL (project-wide)
**Evidence:** `FindReplaceBar.swift` confirmed. TASKS.md #23 and #24 marked complete.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/EditorMode/FindReplaceBar.swift`

---

### Breadcrumb Navigation
**Mode:** Editor
**Expected behavior:** File path at top, click to navigate.
**Current status:** WORKING
**Evidence:** TASKS.md #95 complete. `BreadcrumbBar.swift` present.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/EditorMode/BreadcrumbBar.swift`

---

### Editor Tab Bar
**Mode:** Editor
**Expected behavior:** Open file tabs, close with ⌘W.
**Current status:** WORKING
**Evidence:** `EditorTabBar.swift` present and wired to `EditorViewModel`.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/EditorMode/EditorTabBar.swift`

---

### Symbol Outline
**Mode:** Editor
**Expected behavior:** Sidebar panel showing functions/classes/symbols in current file.
**Current status:** WORKING
**Evidence:** `SymbolOutline.swift` present.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/EditorMode/SymbolOutline.swift`

---

### Git Decorations in Gutter
**Mode:** Editor
**Expected behavior:** Added/modified/deleted line indicators in editor margin.
**Current status:** WORKING
**Evidence:** TASKS.md #33 complete.

---

### Indent Guides / Word Wrap / Whitespace
**Mode:** Editor
**Expected behavior:** Visual editor aids toggleable.
**Current status:** WORKING
**Evidence:** TASKS.md #52, #54, #154 complete.

---

### LSP Integration
**Mode:** Editor
**Expected behavior:** Autocomplete, go-to-definition, hover docs, error squiggles.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #30, #31 pending. No LSP client package exists. `AnvilEditor` package does not exist.

---

### Tree-sitter Syntax Highlighting
**Mode:** Editor
**Expected behavior:** Real grammar-based syntax highlighting.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #156 pending. `AnvilEditor` package does not exist. Current highlighting is likely regex-based.

---

### Code Folding
**Mode:** Editor
**Expected behavior:** Collapse blocks/functions.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #40 pending.

---

### Multi-cursor Editing
**Mode:** Editor
**Expected behavior:** Multiple simultaneous cursors.
**Current status:** NOT IMPLEMENTED
**Evidence:** TASKS.md #51 pending.

---

## TERMINAL MODE

### Terminal View
**Mode:** Terminal
**Expected behavior:** Real PTY shell (zsh/bash), ANSI colors, resize, multiple tabs.
**Current status:** STUB
**Evidence:** `TerminalView.swift` exists. `TerminalViewModel.swift` exists. But `AnvilTerminal` package does NOT exist. No real PTY implementation anywhere in codebase.
**Root cause:** `AnvilTerminal` package was never created. TASKS.md #6, #25, #26 still pending.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/TerminalMode/TerminalView.swift`

---

### Terminal Tabs
**Mode:** Terminal
**Expected behavior:** Multiple terminal sessions with tab switcher.
**Current status:** STUB (UI only)
**Evidence:** `TerminalTabBar.swift` exists. No real backend.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/TerminalMode/TerminalTabBar.swift`

---

## DATABASE MODE

### Database Mode Layout
**Mode:** Database
**Expected behavior:** Schema explorer left, query console + results right.
**Current status:** PARTIAL (layout only)
**Evidence:** `DatabaseMode.swift` has correct split layout. `SchemaExplorer`, `QueryConsole`, `ResultsTable` are all stubs.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/DatabaseMode/`

---

### Real Database Connection
**Mode:** Database
**Expected behavior:** Connect to PostgreSQL, MySQL, SQLite.
**Current status:** STUB
**Evidence:** `DatabasePort` protocol defined. `SQLiteStore` in `AnvilInfrastructure` has empty method bodies. TASKS.md #27 pending.

---

## DOCS MODE

### Docs Mode Layout
**Mode:** Docs
**Expected behavior:** Document browser left, markdown editor right.
**Current status:** PARTIAL (layout only)
**Evidence:** `DocsMode.swift` has split layout. `DocBrowser` and `DocEditor` are stubs.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/DocsMode/`

---

### Markdown Editor
**Mode:** Docs
**Expected behavior:** Rich markdown editing with live preview.
**Current status:** STUB
**Evidence:** `DocEditor.swift` is a stub. TASKS.md #80, #81 pending.

---

## MESSAGING MODE

### Messaging Mode Layout
**Mode:** Messaging
**Expected behavior:** Channel list left, chat messages right.
**Current status:** PARTIAL (layout only)
**Evidence:** `MessagingMode.swift` has correct split layout. `ChannelList` and `ChatView` are stubs.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/MessagingMode/`

---

### Real Slack Integration
**Mode:** Messaging
**Expected behavior:** Connect to Slack workspace, send/receive messages.
**Current status:** NOT IMPLEMENTED
**Evidence:** `MessagingPort` protocol defined. No concrete adapter. TASKS.md #107 pending.

---

## NOTIFICATIONS MODE

### Notification Inbox
**Mode:** Notifications
**Expected behavior:** Inbox of prioritized notifications from GitHub, CI, etc.
**Current status:** PARTIAL
**Evidence:** `NotificationsMode.swift` has real polling via `GitHubNotificationPoller`. `InboxView.swift` is a stub but poller is real.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/NotificationsMode/`

---

### Desktop Notifications
**Mode:** Notifications
**Expected behavior:** macOS native notifications for important events.
**Current status:** WORKING
**Evidence:** TASKS.md #84 complete. `DesktopNotificationService` referenced in DependencyContainer.

---

### GitHub Notification Poller
**Mode:** Notifications
**Expected behavior:** Poll GitHub notifications API and aggregate.
**Current status:** WORKING
**Evidence:** `GitHubNotificationPoller.swift` makes real API calls.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/NotificationsMode/GitHubNotificationPoller.swift`

---

## OBSERVABILITY MODE

### Observability Mode Layout
**Mode:** Observability
**Expected behavior:** Error feed left, error detail right; metrics tab.
**Current status:** PARTIAL (layout only)
**Evidence:** `ObservabilityMode.swift` has tab selector and split layout. `ErrorFeed`, `ErrorDetailView`, `MetricsDashboard` are stubs.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/ObservabilityMode/`

---

### Real Sentry Integration
**Mode:** Observability
**Expected behavior:** Connect to Sentry, show real errors with stack traces.
**Current status:** NOT IMPLEMENTED
**Evidence:** `ObservabilityPort` protocol defined. No concrete adapter. TASKS.md #87 pending.

---

## TESTING MODE

### Test Runner UI
**Mode:** Testing
**Expected behavior:** Test suite tree, test results, pass/fail indicators.
**Current status:** REAL (with demo data)
**Evidence:** `TestingMode.swift` and `TestingViewModel.swift` have real state management with demo data loading. Suite tree + test detail split view working.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/TestingMode/`

---

### Real Test Execution
**Mode:** Testing
**Expected behavior:** Run actual Swift/XCTest/etc. tests and show results.
**Current status:** NOT IMPLEMENTED
**Evidence:** `TestingPort` protocol defined. No concrete adapter.

---

## EXTENSIONS / PLUGIN MODE

### Plugin Marketplace Browser
**Mode:** Extensions
**Expected behavior:** Browse, search, install, manage plugins.
**Current status:** PARTIAL
**Evidence:** `PluginMarketplaceMode.swift` has browse/installed/detail tabs. `PluginCard.swift` has install/uninstall buttons. `PluginMarketplaceViewModel.swift` handles state. BUT: `PluginDetailView.swift` and `InstalledPluginsView.swift` are stubs.
**Files:** `Packages/AnvilUI/Sources/Modes/Auxiliary/ExtensionsMode/`

---

### Real Plugin Loading
**Mode:** Extensions
**Expected behavior:** Load and activate installed plugins at runtime.
**Current status:** NOT IMPLEMENTED
**Evidence:** `PluginManager` in Application layer manages in-memory plugin list. No dynamic loading/sandboxing. TASKS.md #146, #340 pending.

---

## INFRASTRUCTURE

### Git Operations (AnvilGit)
**Mode:** Global
**Expected behavior:** All git operations (branches, commits, diffs, staging, worktrees, blame, stash, tags, graph).
**Current status:** REAL
**Evidence:** `GitSourceControlAdapter` calls real `/usr/bin/git` for every operation. `DiffParser` parses real diffs. `WorktreeEngine` creates real worktrees at `~/.anvil/worktrees/`.
**Files:** `Packages/AnvilGit/Sources/`

---

### GitHub Cloud Adapter
**Mode:** Global
**Expected behavior:** PR listing, PR comments, CI status, merge, push/pull.
**Current status:** REAL (partially)
**Evidence:** `GitHubSourceControlCloudAdapter` referenced throughout app. Real OAuth token used. Some operations real, others may be partial.
**Files:** `Packages/AnvilInfrastructure/Sources/`

---

### File Store (Persistence)
**Mode:** Global
**Expected behavior:** Read/write JSON files to disk for app state.
**Current status:** REAL
**Evidence:** `FileStore` uses real `FileManager` APIs.
**Files:** `Packages/AnvilInfrastructure/Sources/FileStore.swift`

---

### Keychain Store (Secrets)
**Mode:** Global
**Expected behavior:** Store API keys and tokens securely in macOS Keychain.
**Current status:** REAL
**Evidence:** `KeychainStore` uses real Security framework (`SecItemAdd`, `SecItemCopyMatching`, etc.).
**Files:** `Packages/AnvilInfrastructure/Sources/KeychainStore.swift`

---

### SQLite Store
**Mode:** Global
**Expected behavior:** Local database for app data.
**Current status:** STUB
**Evidence:** `SQLiteStore` methods have empty bodies with TODO comments referencing GRDB.
**Files:** `Packages/AnvilInfrastructure/Sources/SQLiteStore.swift`

---

### Project Manager
**Mode:** Global
**Expected behavior:** CRUD for projects, persisted to `~/.anvil/projects/projects.json`.
**Current status:** REAL
**Evidence:** `ProjectManager` actor uses `FileStore` for real disk persistence.
**Files:** `Packages/AnvilApplication/Sources/ProjectManager.swift`

---

### Event Bus
**Mode:** Global
**Expected behavior:** Domain pub/sub: publish events, handlers subscribed by type.
**Current status:** REAL
**Evidence:** `EventBus` actor with `publish()` / `subscribe()`. Events defined: `AgentCompletedEvent`, `BuildFailedEvent`, `PRMergedEvent`.
**Files:** `Packages/AnvilApplication/Sources/EventBus.swift`

---

### Worktree Orchestrator
**Mode:** Agent
**Expected behavior:** Auto-create git worktree per agent session at `~/.anvil/worktrees/`.
**Current status:** REAL
**Evidence:** `WorktreeOrchestrator` actor + `WorktreeEngine` in AnvilGit both real. `CreateWorktreeUseCase` defined.
**Files:** `Packages/AnvilApplication/Sources/`, `Packages/AnvilGit/Sources/WorktreeEngine.swift`

---

### ACP Cost Tracking
**Mode:** Global
**Expected behavior:** Real-time cost tracking per session with daily totals.
**Current status:** REAL
**Evidence:** `ACPCostTracker` records real costs with pricing models. `CostCalculator` and `TokenCounter` are real.
**Files:** `Packages/AnvilACP/Sources/`

---

## DOMAIN MODEL

### All 27 Ports (Protocols)
**Mode:** Global
**Expected behavior:** Abstract contracts for every primitive.
**Current status:** PROTOCOLS ONLY — no concrete implementations
**Evidence:** All 27 ports (`AgentPort`, `SourceControlPort`, `TicketPort`, `DatabasePort`, etc.) are protocol definitions only. Implementations are expected from external plugins/adapters. Only `GitSourceControlAdapter` (AnvilGit), some ACP providers (AnvilACP), and GitHub adapter (AnvilInfrastructure) exist.

---

### Domain Events
**Mode:** Global
**Expected behavior:** Events published on EventBus when domain actions occur.
**Current status:** PARTIAL (3 events defined)
**Evidence:** `AgentCompletedEvent`, `BuildFailedEvent`, `PRMergedEvent` defined. Most expected events (ticket created, PR reviewed, deploy succeeded, etc.) not yet defined.

---

## MISSING PACKAGES

| Package | Status | Notes |
|---------|--------|-------|
| AnvilEditor | MISSING | Tree-sitter, LSP integration not started |
| AnvilTerminal | MISSING | Real PTY terminal not started |

---

## SUMMARY TABLE

| Feature Area | Status | Key Gap |
|---|---|---|
| **BUG: Keyboard interception** | BROKEN | ChordTracker consumes chars that should reach TextFields |
| **BUG: Sidebar unclickable** | BROKEN | Overlay backdrops cover entire window incl. sidebar |
| App Shell / Layout | WORKING | — |
| Mode Switching | WORKING | — |
| Agent Conversations | WORKING | Slash cmds, @refs, model picker are stubs |
| Agent Synthesis Rooms | PARTIAL | UI real, backend synthesis not wired |
| Intent / Kanban | WORKING | Sub-tasks, bulk actions, comments missing |
| Review Mode | PARTIAL | Inline comments, AI summary not implemented |
| Ship Mode | STUB | No real deployment provider |
| Editor (basic) | WORKING | No LSP, no Tree-sitter, no AnvilEditor pkg |
| Terminal | STUB | AnvilTerminal package doesn't exist |
| Database | STUB | No real DB connection |
| Docs | STUB | No real markdown editor |
| Messaging | STUB | No Slack integration |
| Notifications | PARTIAL | GitHub polling real; inbox UI stub |
| Observability | STUB | No Sentry integration |
| Testing | PARTIAL | Demo data real; actual test runner missing |
| Extensions | PARTIAL | Browse UI real; plugin loading not implemented |
| Git (AnvilGit) | REAL | Full git CLI integration |
| ACP (AI providers) | REAL | Anthropic, OpenAI, Ollama, Claude CLI all real |
| Infrastructure | PARTIAL | FileStore/Keychain real; SQLite stub |
| 27 Domain Ports | PROTOCOLS ONLY | Implementations needed per provider |
