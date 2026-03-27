# ANVIL — Design Vision v0.2

**Research date:** 2026-03-27
**Author:** Product Research Agent
**Status:** Canonical reference for v0.2 feature prioritization

---

## Executive Summary

Anvil's core bet is that the post-IDE era has arrived: AI is not a feature, it's the operating surface. The leading tools confirm this. Cursor's cloud agents (launched Mar 2026) handle multi-repo changes autonomously. Windsurf Cascade plans long-horizon tasks in the background. Warp has rebranded as an "Agentic Development Environment." VS Code agent mode went GA. Linear's agent lives in every comment box.

The race is on. Anvil's advantage is **native macOS architecture + opinionated four-mode workflow + first-class ACP**. What we can ship in v0.2 that none of the competitors can: a tool that feels like it was born on the Mac, not ported to it — with an agent that flows through every surface, not bolted onto a sidebar.

---

## Part 1: What We Learned from the Competition

### Cursor (Electron, cross-platform)
**What they do brilliantly:**
- Autonomy slider: Tab → Cmd+K → full agent. Every developer finds their comfort level
- Cloud agents (Mar 2026): run in isolated VMs, triggered by events (Slack, Linear, GitHub, PagerDuty)
- Composer 2: frontier-level model optimized for complex agentic tasks
- Automations framework: always-on agents that "learn from past runs and improve with repetition"
- 30+ plugin ecosystem (Atlassian, Datadog, GitLab) in the last month alone
- BugBot: autonomous PR review running in GitHub
- Self-hosted cloud agents for enterprise: code never leaves your network

**What Cursor lacks that Anvil can win on:**
- Ugly Electron shell — not native, no macOS materials, no Sonoma/Tahoe feel
- No opinionated workflow — it's still VS Code with AI bolted on
- No ticket-to-agent pipeline built in — they integrate with Linear but don't own the workflow
- No multi-project manager — you switch repos by reopening the app

---

### Windsurf Cascade (Electron, cross-platform)
**What they do brilliantly:**
- Background planning agent: continuously refines long-term plan while short-term model executes
- Live todo list tracking: Cascade shows you the plan and auto-updates it as it discovers new info
- Named checkpoints: snapshot any state, revert to any point
- Queued messages: type your next instruction while Cascade works — it queues and executes sequentially
- "Continue" command: Cascade maintains real-time awareness of your actions, no context re-injection needed
- Write mode vs Chat mode: one toggles edits, one discusses — Cmd+L activates

**What Windsurf lacks:**
- Same Electron problem as Cursor
- No Mac-native feel
- Cascade is powerful but lives in a sidebar — no mode-level integration

---

### Zed (Native, Rust + GPUI, macOS/Linux)
**What they do brilliantly:**
- True native performance — fastest text rendering in class
- Slash commands with folded text: `/file`, `/tab`, `/terminal`, `/diagnostics` insert context as collapsible blocks
- Multi-buffer editing: excerpts from multiple files in one view, editable, for true multi-file refactors
- ACP (Agent Client Protocol): any AI agent plugs into Zed — same protocol Anvil uses
- Claude Code integration via ACP (beta)
- Inline transformation: `Ctrl+Enter` streams token-by-token with custom diff protocol
- Branch diff @-mention: `@branch-diff` inserts all changes since main as context (0.228.0)
- Git badge on sidebar: numeric count of uncommitted changes
- Per-tool permission regexes: control which terminal commands auto-allow
- Collaboration + Follow Mode: real-time shared editing, track a teammate's navigation
- BYOK 1M context window for Claude Opus/Sonnet

**What Zed lacks:**
- No ticket/project management (they're a code editor, not a dev environment)
- No agent autonomy slider — you're either in full agent mode or not
- No native shipping workflow (Ship mode equivalent)
- Collaboration is real-time pairing, not async multi-agent

---

### VS Code + GitHub Copilot (Electron)
**What they do brilliantly:**
- Agent mode GA with built-in tools: `#fetch`, `#usages` (find all refs + implementations + definitions)
- "Thinking tool": model thinks between tool calls on complex tasks
- Unified Chat: Ask / Edit / Agent modes in one panel, switch mid-conversation
- Tool approval memory: remember approvals at session / workspace / app level
- Multiple simultaneous agent sessions + pop-out to new windows
- Restore past sessions via "Show Chats"
- Dual-model architecture: foundation model generates, speculative decoding applies efficiently
- Project Padawan (coming): assigns GitHub issues, produces fully tested PRs in cloud sandbox
- `#codebase` and `#searchResults` as context anchors

**What VS Code lacks:**
- The whole point is Anvil — opinionated workflow, native Mac, ACP as first-class infrastructure

---

### Warp Terminal (Native, Rust + Metal, macOS)
**What they do brilliantly:**
- Oz Agent: #1 Terminal-Bench, #5 SWE-bench — best-in-class terminal agent
- Full terminal use: agents run interactive commands (not just shell scripts)
- Computer use: agents verify changes by looking at the UI
- WARP.md: project-level agent config (compatible with claude.md, agents.md)
- MCP server integration: Linear, Figma, Slack, Sentry out of the box
- Rich context prompting: @ for file search, image uploads, URL attachments in terminal input
- Voice transcription via Wispr Flow integration
- Agents 3.0: multiple agents with central tracking and oversight dashboard
- Drive: centralized knowledge base for agents and teammates
- Multi-repo change optimization
- Built-in code editor with LSP, file tree, code review with line comments
- Configurable autonomy: step-by-step approval to full autonomy
- Zero Data Retention option — trust signal for enterprise

**What Anvil can learn from Warp:**
- The "@ for file/image/URL context" pattern in any input field
- Central agent oversight dashboard (multiple agents tracked in one place)
- Project-level config files (WARP.md → ANVIL.md concept for project-level agent behavior)
- Tool permission configurability — don't auto-approve destructive commands
- Voice input as first-class citizen

---

### Linear (Web + Electron)
**What they do brilliantly:**
- Keyboard-first to the core: `G then X` for archives, `W then O` for coding tools, chord navigation everywhere
- Linear Agent via `Cmd+J`: synthesizes workspace context, takes action from comments/Slack/Teams/automations
- Speed as identity: everything is instant, no loading states, optimistic updates
- Triage → backlog → cycle → ship as first-class state machine
- Advanced `AND/OR` filters for any issue stream
- Time-in-status tracking, logarithmic timing charts
- Nested sub-issues, archived teams (historical preservation)
- UI refresh standardizing headers and navigation across all workflows
- External sharing of issues from private teams

**What Anvil can learn from Linear:**
- Chord-based navigation (`G then B` for branches, etc.)
- Agent embedded in every comment/context, not just a dedicated mode
- First-class triage workflow with states as navigation primitives
- Optimistic updates everywhere — never show a spinner where you can guess the outcome

---

### Raycast (Native, Swift + AppKit, macOS)
**What they do brilliantly:**
- Launcher as OS-level tool, not an app — instant global hotkey
- Extension ecosystem in React/TypeScript: any dev can ship a Raycast extension
- AI Quick commands: invoke AI on any selected text, in any app
- Snippets with trigger keywords: type `!pr` and get a PR template
- Clipboard history with fuzzy search
- Window management built-in
- Note capture during flow — non-disruptive
- "Native" as a core value: pure Swift, 99.8% crash-free

**What Anvil can learn from Raycast:**
- The command palette IS the product — make `⌘K` the most polished thing in the app
- Snippet/template system for common agent prompts
- Extensions/plugins that feel native, not webviews
- Speed as a measurable, proud identity — benchmark and publish it

---

### Superhuman (Web)
**What they do brilliantly:**
- `j/k` navigation as first-class: muscle memory transcends the inbox
- Inbox zero as a workflow, not a feature: triage states drive behavior
- Writing AI that adapts to your tone — AI output sounds like you
- Smart follow-up tracking: nothing slips
- 800+ integrations, but always in-context (docs, Jira, calendar in message thread)
- Speed measurement: "4 hours saved per week" — makes speed a claim, not a vibe

**What Anvil can learn from Superhuman:**
- Notifications mode should feel like a Superhuman inbox: `j/k`, triage states, keyboard-only
- "Sounds like you" — agent prompts in Agent mode should adapt to Allie's style over time
- Make speed a marketing claim backed by real UX decisions

---

## Part 2: macOS Tahoe / Liquid Glass Design Patterns

macOS Tahoe (2025) introduced Liquid Glass — a generative material system that replaces traditional frosted glass. Key properties:

### Visual Characteristics
- **Translucency without blur**: content behind shows through with controlled opacity, not gaussian blur
- **Specular highlights**: thin light refraction at edges, as if the UI has physical depth
- **Color responsiveness**: the glass tints slightly based on dominant colors in content beneath
- **Depth stacking**: multiple glass layers interact — deeper layers are more opaque
- **Dark/light adaptive**: glass material inverts appropriately, never looks pasted-on

### SwiftUI Implementation
- `.glassBackgroundEffect()` modifier (Tahoe+): applies liquid glass to any view
- `WindowStyle(.glass)` for windows that float with glass chrome
- `ContainerRelativeFrame` + glass: correct for panels that adapt to window size
- `.materialEffect(.glass)` for custom glass-material views
- Sidebar materials: `NSVisualEffectView` with `.sidebar` or `.headerView` blending modes
- Status bar: `.ultraThinMaterial` or `.regularMaterial` depending on content

### When to Use Liquid Glass in Anvil
- **Command palette**: glass background, floating above content — perfect use case
- **Inspector panel**: glass sidebar when overlapping content (collapsed state)
- **Status bar**: glass tray at bottom — system bar analog
- **Modal overlays**: agent approval dialogs, tool call confirmations
- **Hover tooltips**: glass pill matching Tahoe system tooltips
- **Mode tab bar**: glass tabs that refract the content beneath them
- **Notification badges**: glass background with number

### When NOT to Use Liquid Glass
- Main content area (editor, conversation) — glass would distract from text
- Agent message bubbles — these should be opaque cards
- Code blocks — always opaque with high-contrast background
- Status indicators (green/red dots) — solid color, not glass

### Motion with Liquid Glass
- Glass transitions should use `spring(response: 0.4, dampingFraction: 0.8)` — heavier spring than standard because glass feels physically weighty
- Appearance: glass elements should scale from 0.95 + fade in, not slide
- Collapse: use opacity + scale, not clip-to-bounds slide

---

## Part 3: The 50+ Features Anvil Should Have

Prioritized: **P0** = must have for v0.2, **P1** = should have, **P2** = nice to have

---

### AGENT MODE

**P0 — Slash Command Framework**
Type `/` in the agent input and get a contextual menu of commands. Each command inserts context or invokes a behavior. Essential commands:
- `/file [path]` — attach a file to context (folded, collapsible like Zed)
- `/diff` — attach current git diff
- `/branch-diff` — all changes since main (Zed 0.228.0 pattern)
- `/terminal` — attach last N terminal outputs
- `/ticket [id]` — attach a Linear/Jira ticket
- `/pr [number]` — attach a PR description and comments
- `/error [id]` — attach a Sentry/observability error
- `/test [file]` — attach test file output
- `/schema [table]` — attach database schema
- `/docs [url]` — fetch and attach URL content
- `/clear` — clear context window

**P0 — @ Reference Autocomplete**
Typing `@` in any agent input opens a floating picker showing:
- Files in current project (fuzzy search)
- Symbols (functions, classes, types)
- Branches
- Tickets
- Team members (for context: "assigned to @name")
- Previous agent sessions
References collapse to a chip in the input field and expand in the prompt to the agent.

**P0 — Autonomy Slider**
Three settings visible in agent input toolbar:
1. **Ask** — agent plans and asks before each tool call
2. **Review** — agent executes but shows diffs for approval before applying
3. **Auto** — agent executes with post-hoc review only (like Cursor full agent)

Setting persists per-session. Status bar shows current autonomy level with icon.

**P0 — Named Checkpoints** (from Windsurf)
Button in agent toolbar: "Create Checkpoint". Saves current worktree state with a name. Visible in Inspector panel as a timeline. One-click revert to any checkpoint. Keyboard: `⌘⇧S` create, `⌘⇧Z` revert to last.

**P0 — Queued Messages**
While agent is running, the input field stays active. Typed messages queue and display as "queued" below the running conversation. When agent finishes, queued message executes automatically. Visual indicator: "1 message queued" with pulsing dot.

**P0 — Live Todo Tracking** (from Windsurf)
When agent starts a multi-step task, it produces a todo list that appears as a pinned card at the top of the conversation. As agent completes steps, items check off in real time. User can edit the todo mid-run to redirect agent.

**P1 — Agent Oversight Dashboard**
Multiple agent sessions running simultaneously? A new "Agent HQ" view (in Agent sidebar) shows all active sessions with:
- Status (running / waiting / complete / error)
- Current action (file being edited, command running)
- Cost so far
- Time elapsed
- Quick "stop" and "continue" controls
Pattern from Warp's Agents 3.0.

**P1 — Background Planning Agent**
Like Windsurf Cascade: a lightweight planning agent runs concurrently with the execution agent. It reads ahead in the todo list and pre-caches relevant files, pre-indexes symbols, pre-fetches PR metadata. User never sees it working — they just notice things load instantly.

**P1 — Inline Edit Streams**
From any file in the Editor mode: select code, press `⌘I` (inline assist), type a prompt. The agent streams changes token-by-token with a custom diff overlay showing additions in green, deletions in red. Accept with `Tab`, reject with `Esc`, cycle alternatives with `⌘]` / `⌘[`. Pattern from Zed's inline transformation.

**P1 — Tool Call Visualization**
When agent calls a tool (read_file, run_command, edit_file), show it in the conversation as a collapsible card:
```
▶ read_file("src/auth/middleware.ts")  [342 lines]
```
Expanded shows file contents. Running tools pulse with purple animation. Failed tools show in red with error detail. Mirrors Codex UI / ChatGPT desktop pattern.

**P1 — Context Window Indicator**
Pill in agent input toolbar showing: `4.2k / 200k tokens`. Clicking opens a context inspector showing every item in context with token count and a remove button. Filling past 80% triggers amber warning, 95% triggers red warning.

**P2 — Voice Input** (Warp/Wispr pattern)
Microphone button in agent input. Hold to record, release to transcribe via system speech recognition (no external API needed on Mac). Transcription appears in input field for editing before send.

**P2 — Prompt Templates / Snippets** (Raycast pattern)
Type `!` in agent input to trigger snippet autocomplete. Pre-defined templates:
- `!review` → "Review the following code for correctness, performance, and maintainability..."
- `!test` → "Write comprehensive tests for the following, covering happy path, edge cases, and error handling..."
- `!explain` → "Explain this code as if I've never seen this pattern before..."
User can create custom snippets via Settings → Agent → Snippets.

**P2 — Tone Learning** (Superhuman pattern)
Agent learns from accepted vs rejected messages. After 10+ interactions, it adjusts output style: more terse vs verbose, more code-heavy vs more explanatory, function names style. Tracked per-project.

---

### INTENT MODE (Tickets / Project Management)

**P0 — Multi-Project Sidebar**
Left sidebar shows a project switcher at the very top: avatar + project name + dropdown arrow. Clicking opens a popover with all projects, recent projects, and "Open Project..." option. Keyboard: `⌘⇧P` to switch projects. Project metadata persists between launches (path, provider, recent files).

**P0 — Ticket → Agent Pipeline**
On any ticket in Intent mode: press `⌘↵` or click "Start Agent" button. This:
1. Creates a new git worktree for the ticket (named from ticket ID)
2. Switches to Agent mode
3. Pre-populates the agent input with the ticket title, description, and acceptance criteria as context
4. Sets autonomy to "Review" by default
5. Links the session to the ticket (visible in Inspector)

**P0 — Kanban + List Toggle**
Intent mode sidebar can switch between:
- **List** — Linear-style flat list with `j/k` navigation and keyboard actions
- **Board** — Kanban with status columns, drag-and-drop
- Toggle with `⌘⇧B` (board) / `⌘⇧L` (list)

**P1 — Chord Navigation** (Linear pattern)
Two-key navigation shortcuts throughout Intent mode:
- `G then B` — go to board
- `G then T` — go to triage
- `G then M` — go to my issues
- `G then A` — go to all issues
- `G then C` — go to current cycle
- `C` — create issue (when list focused)
- `E` — edit selected issue title (inline)
- `P` — change priority of selected
- `S` — change status of selected

**P1 — Triage Inbox**
Separate triage section in Intent sidebar: unassigned issues without cycles appear here. Keyboard-first triage: `j/k` to navigate, `A` to assign to me, `C` to set cycle, `P` to set priority, `E` to skip/archive. Goal: clear the triage inbox in under 60 seconds.

**P1 — Time-in-Status Tracking**
Each ticket tracks how long it's been in each status. Visible as small chips on the ticket detail: "In Progress: 3d". Alerts (configurable) when tickets sit in any status beyond a threshold.

**P2 — AI Issue Decomposition**
On any epic/large ticket: "Decompose" button. Agent reads the ticket and suggests 3–8 sub-tickets with titles and descriptions. User reviews, edits, and accepts. Creates them with one click. Uses the project's ticket provider (Linear/Jira).

---

### REVIEW MODE (PRs / Code Review)

**P0 — PR Inbox with Badge Count**
Review mode sidebar shows all open PRs requiring action, grouped by status:
- Assigned to me
- My PRs (waiting for review / failing CI)
- All open (for visibility)
Badge count in mode tab bar = number of PRs needing action from you.

**P0 — AI Review Checklist**
On any PR: "AI Review" button runs the agent against the diff and produces:
- Correctness issues (bugs, edge cases)
- Performance concerns
- Security flags
- Test coverage gaps
- Style/convention violations
Results appear as a checklist in the Inspector panel. Each item links to the relevant line in the diff.

**P1 — Inline Comment Composer**
In diff view: click any line to open a comment composer inline. Agent can be invoked from the comment box with `@agent` to auto-draft a comment about the selected line. Submit comment goes to GitHub/GitLab.

**P1 — CI Status Live Feed**
Inspector panel in Review mode shows CI status for the selected PR as a live feed:
- Job names with status (pending / running / passing / failing)
- Click to expand log output
- "Re-run" button for failed jobs
- Streaming log output when running (SSE or polling)

**P2 — Reviewer Load Balancing**
When assigning reviewers: the picker shows each potential reviewer's current review load (# of open PRs assigned to them). Helps avoid piling reviews on one person.

---

### GIT / SOURCE CONTROL

**P0 — Branch Graph Visualization**
In Git section of sidebar: visual branch graph showing:
- Current branch (highlighted)
- Remote branches
- Divergence from main (commits ahead/behind)
- Merge commits shown as nodes
- Click branch to switch (with confirmation if dirty worktree)

**P0 — Numeric Badge on Git Icon**
Sidebar git section icon shows badge with uncommitted change count (Zed 0.229.0 pattern). Zero = no badge. Red badge for merge conflicts.

**P0 — Worktree Manager**
Each agent session that touches code gets its own worktree (already in spec). The UI should show all active worktrees:
- Worktree name (ticket ID or branch name)
- Status (clean / modified / conflict)
- Active agent session if running
- Last commit
- "Switch to" and "Delete" actions

**P1 — One-Click Commit + PR**
In any dirty worktree: `⌘⇧G` opens a quick commit panel. Agent auto-drafts a commit message from the diff. User edits, presses `⌘↵` to commit. Follow-up option: "Push + Open PR" which:
1. Pushes the branch
2. Agent drafts a PR title and description from ticket + diff
3. Opens PR creation in Review mode

**P1 — Blame Annotations**
In Editor mode: `⌘⇧B` toggles git blame inline annotations on every line. Shows: author avatar, commit message preview, date. Click annotation opens commit detail in Inspector.

**P2 — Conflict Resolution UI**
When a merge/rebase conflict exists: a dedicated conflict resolution view shows the three-way diff (base / ours / theirs). Agent can be invoked to suggest resolution. "Accept ours", "Accept theirs", "Accept agent suggestion", "Edit manually".

---

### TERMINAL

**P0 — Real zsh with Shell Integration**
Terminal mode must run actual zsh (not a fake subprocess). Shell integration markers (like Warp's) enable:
- Command blocks: each command + its output is a discrete block
- Block selection and copy
- Exit code display per block (green checkmark / red X)
- Execution time display per block

**P0 — @ Context in Terminal Input**
In terminal input: `@` opens context picker for file paths, allowing quick file path insertion without typing. Image attachment for visual context (Warp pattern).

**P1 — Agent-in-Terminal**
`⌘I` in terminal opens agent input inline. Agent can suggest terminal commands with explanations. One click to execute. Per-command approval before execution. "Dangerous" commands (rm -rf, git reset --hard) require explicit confirmation.

**P1 — Command History with Semantic Search**
`↑` cycles through history (standard). `⌘F` opens history search with semantic matching — "that command that installed the package last week" works. History persists per project.

**P2 — Split Terminal Panes**
`⌘\` splits terminal horizontally, `⌘⇧\` splits vertically. Each pane is independent zsh session. Panes can be dragged to reorder.

---

### NOTIFICATION / INBOX

**P0 — Unified Notification Inbox** (Superhuman pattern)
Notifications mode = a proper inbox. Items arrive from:
- CI failures (your PRs)
- PR review requests (assigned to you)
- PR comments mentioning you
- Agent session completions
- Ticket status changes
- Build/deployment events
- Merge conflicts

Each notification is an actionable item, not just a log entry. `j/k` to navigate, `↵` to open, `E` to dismiss, `⌘↵` to act (e.g., reply to PR comment, re-run CI).

**P0 — Badge Count Cascade**
- Each mode tab shows badge count for items needing action in that mode
- App dock icon shows total unread count
- Status bar notification count = total across all modes
- Badges clear when item is actioned or dismissed

**P1 — Notification Groups**
Notifications grouped by source + time window. "3 CI failures in the last hour on feature/auth-refactor" is one group, not three items.

**P2 — Do Not Disturb**
`⌘⇧D` toggles DND. In DND: no badge updates, no notification sounds, notifications queue for review later. DND state shows in status bar.

---

### COMMAND PALETTE

**P0 — First-Class ⌘K Palette** (Raycast pattern)
The command palette is the soul of the app. It must:
- Open in < 50ms from anywhere
- Fuzzy search across: commands, files, tickets, branches, agent sessions, settings, docs
- Show recent items at top without search
- Support chord suffixes: type `file ` to filter to file-only results
- Show keyboard shortcut for each result
- Support multi-step actions: "Create ticket" → type title → select priority → confirm

**P0 — Context-Aware Results**
Palette results change based on current mode and selection:
- In Agent mode: first results are slash commands and @ references
- In Review mode: first results are PR actions
- In Intent mode: first results are ticket actions
- In Editor mode: first results are file symbols

**P1 — Action Shortcuts in Palette**
Any action available in palette can be assigned a keyboard shortcut from within the palette itself. Press `⌘K` on a result → assign shortcut dialog. Settings → Keyboard is just a list view of the same data.

---

### EDITOR

**P0 — File Tree in Editor Sidebar**
Standard file tree with:
- Collapse / expand directories
- New file / folder buttons
- Git status indicators (M / A / D / ?) on each file
- Search to filter tree
- Right-click context menu: rename, delete, copy path, reveal in Finder

**P0 — Tab Management**
`⌘T` new tab, `⌘W` close, `⌘⇧[` / `⌘⇧]` switch tabs. Tabs show:
- File name (truncated if needed)
- Modified indicator (dot)
- Close button on hover
- Drag to reorder
- Drop to split

**P1 — Symbol Outline** (already in codebase as SymbolOutline.swift)
Tree of symbols in current file: functions, classes, types, constants. Clicking navigates to line. Fuzzy search within outline. Keyboard: `⌘⇧O` to focus outline, then type to search.

**P1 — Minimap**
Right-side minimap showing scaled-down view of file. Highlighted region = current viewport. Click to jump. Color coding matches syntax highlighting. Optional (toggle with `⌘⇧M`).

**P2 — LSP Integration**
Hover for type info, go-to-definition, find-all-references, rename symbol. These require language server integration (future AnvilEditor package). Lay the port/protocol groundwork now.

---

### MULTI-PROJECT / MULTI-REPO

**P0 — Project Switcher**
The top of the sidebar is a project switcher (not buried in a menu). Shows:
- Current project avatar + name
- Dropdown with recent projects (up to 5)
- "Open Project" to browse filesystem
- "Clone Repository" to clone via URL

**P0 — Per-Project Agent Config (ANVIL.md)**
Each project can have an `ANVIL.md` in its root. This file configures:
- Default agent instructions
- Approved tools (auto-allow specific commands)
- Blocked tools (never run without confirmation)
- Project context (tech stack, conventions, key files)
- Snippet overrides
When agent starts a session, it reads ANVIL.md and uses it as system-level context.

**P1 — Workspace (Multi-Repo)**
A Workspace is a collection of projects. Workspaces appear in project switcher alongside single projects. In a workspace:
- All projects' file trees available in Editor sidebar
- Agent can read/write across all workspace repos
- Git operations available for each repo independently
- Tickets can span workspace repos

**P2 — Cross-Repo Search**
`⌘⇧F` in a workspace searches across all repos simultaneously. Results grouped by repo. Used by agent for cross-repo symbol lookup.

---

### TESTING

**P1 — Test Runner UI** (Testing mode)
A Test mode (new auxiliary mode) shows:
- Test file tree on left
- Test results on right: passing (green), failing (red), skipped (gray)
- Failed test shows: assertion, expected vs actual, file:line link
- "Run All", "Run File", "Run Selected" buttons
- Re-run on file save (watch mode toggle)

**P1 — Agent-Driven Test Writing**
From any function in Editor: right-click → "Write Tests". Agent generates test file with:
- Happy path tests
- Edge case tests
- Error/failure tests
Based on function signature, docstrings, and types.

**P2 — Test Coverage Overlay**
In Editor: toggle coverage overlay showing line-level hit/miss. Uncovered lines highlighted in amber. Coverage % shown in status bar when overlay is active.

---

### STATUS BAR (make it alive)

**P0 — Live Agent Status**
Status bar center shows:
- When idle: provider icon + model name (e.g., "claude-sonnet-4-6")
- When running: animated purple pulse + "Agent working..." + elapsed time
- When complete: "Done in 12s" fading to normal after 3s
- When error: "Agent failed" in red, click to see error

**P0 — Real Branch + Dirty State**
Status bar left shows: `⎇ feature/auth-refactor ●3` meaning 3 uncommitted changes. Click to open git panel. `●` turns red if conflicts exist.

**P1 — Cost Tracker**
Status bar right shows: `$0.42 session / $2.31 today`. Click opens cost breakdown:
- By session
- By model
- By day/week/month
Budget alerts configurable in Settings.

**P1 — Clock + Pomodoro**
Status bar far right shows current time. Click to see:
- Today's focus time (time Anvil was frontmost + active)
- Pomodoro timer option (25m work / 5m break)
- "Focus mode" toggle

---

### DESIGN POLISH (make it feel alive)

**P0 — Liquid Glass Command Palette**
The command palette uses `glassBackgroundEffect()` over a dark blur. Floating, not a sheet. Scale-in animation from 0.95 with spring. This is the signature moment of every Anvil interaction.

**P0 — Purple ACP Ambient Indicator**
Any surface powered by ACP has a subtle purple ambient glow when active. Agent running = subtle purple breathing animation on the agent mode tab. Background planning = dim purple shimmer on status bar center. This makes AI feel like electricity, not a spinner.

**P0 — Mode Transition Animation**
Switching modes should cross-fade in 120ms (per SPEC). Add: mode tab selection should animate with a sliding indicator (not a jump). The selected tab's underline slides to the new position, like a scrollable segmented control.

**P1 — Skeleton Loading States**
Never show empty content before data loads. Skeleton screens (gray animated placeholders matching the real layout) appear immediately. When data arrives, content fades in over the skeleton.

**P1 — Optimistic Updates** (Linear pattern)
Any action that succeeds 99% of the time should update the UI immediately, before network confirmation. Ticket status change → UI updates, request fires. If it fails, revert with a toast notification.

**P1 — Presence Awareness**
If Anvil gets collaboration features: show who else is in the same file/ticket/session. Colored avatar rings on files in the tree, on tickets in the list. Pattern from Zed's collaboration + Linear's shared projects.

**P2 — Ambient Sound Mode**
Optional: background sound while agent is running (white noise, rain, lo-fi). Controlled from status bar icon. Sounds stop when agent completes. Makes long agent runs feel active rather than anxious.

---

## Part 4: Design Principles for Anvil v0.2

### 1. Speed is the feature
Every interaction has a target response time. Command palette: < 50ms. Mode switch: < 150ms. File open: < 200ms. Agent first token: < 500ms. These are engineering targets as much as design ones. Publish them. Hold to them.

### 2. AI is ambient, not modal
The agent shouldn't feel like a feature you invoke. It should feel like a colleague who's always present. The purple glow, the background planning, the context that's always up to date — these communicate that AI is in the room, not on the phone.

### 3. Every pixel is a verb
Stolen from the SPEC and worth repeating: Anvil is for commanding things, not reading things. Every UI element should make it obvious what you can do with it. No decorative elements. No info without action.

### 4. Trust through transparency
Tool calls visible. Context window visible. Cost visible. Autonomy level visible. When users can see what the agent is doing and why, they trust it more and intervene more accurately. Black-box agents create anxiety. Transparent agents create flow.

### 5. The keyboard is the mouse
Every single action should be reachable by keyboard. Not as an afterthought (adding `accessibilityLabel`), but as the primary design constraint. Mouse is for discovery; keyboard is for mastery. Ship both.

### 6. Native is a feature
SwiftUI + AppKit interop + Liquid Glass + SF Symbols = an app that feels like it came pre-installed. Don't apologize for this. Lean into it. Every time an Electron app would show a webview, Anvil shows a real SwiftUI component.

### 7. Opinionated workflow > infinite configurability
Anvil has four modes. Not twelve. Not a plugin system that lets users build their own workflow. The modes are the product. Users may grumble at first and then wonder how they ever worked without them.

---

## Part 5: What's Already Built (Do Not Re-Build)

Based on codebase analysis, the following exists and should be iterated, not replaced:
- `SlashCommandMenu.swift` — exists, needs real commands wired up
- `AtReferencePopup.swift` — exists, needs real file/symbol/ticket data
- `AgentViewModel.swift` / `ConversationView.swift` — exists, needs tool call visualization
- `ModeTabBar.swift` — exists, needs animated selection indicator
- `InspectorPanel.swift` — exists, needs contextual content per mode
- `TerminalPanel.swift` — exists as embedded panel, needs real zsh
- `SymbolOutline.swift` — exists, needs LSP or TreeSitter backing
- `NotificationsMode/` — full structure exists, needs real data
- `ReviewMode/` — full structure exists, needs real GitHub data
- `IntentMode/` — full structure with ticket detail, needs real provider data
- Design system (`Colors`, `Typography`, `Spacing`, `Animations`) — solid foundation, add Liquid Glass

---

## Part 6: Priority Roadmap for v0.2

### P0 — Must ship for v0.2 (core loop must work)
1. Slash command framework with real commands (`/file`, `/diff`, `/ticket`)
2. @ reference with real file + symbol lookup
3. Autonomy slider (Ask / Review / Auto)
4. Named checkpoints
5. Queued messages while agent runs
6. Live todo tracking
7. Multi-project sidebar + project switcher
8. Ticket → Agent pipeline (⌘↵ from ticket)
9. Real zsh terminal with command blocks
10. Branch graph + numeric git badge
11. PR inbox with badge count
12. Worktree manager UI
13. Liquid Glass command palette
14. Purple ACP ambient indicator
15. Mode transition sliding animation

### P1 — Should have for v0.2 (makes it shippable and impressive)
16. Agent oversight dashboard (multiple sessions)
17. Background planning agent
18. Inline edit streams in editor
19. Tool call visualization in conversation
20. Context window indicator
21. Kanban + List toggle in Intent mode
22. Chord navigation in Intent mode
23. One-click commit + PR
24. Blame annotations
25. Agent-in-terminal with ⌘I
26. Unified notification inbox (Superhuman-style)
27. Badge count cascade
28. Context-aware command palette results
29. AI review checklist on PRs
30. ANVIL.md per-project config
31. Skeleton loading states
32. Optimistic updates

### P2 — Nice to have (v0.3+)
33. Voice input
34. Prompt templates / snippets
35. Tone learning
36. Workspace (multi-repo)
37. Cross-repo search
38. LSP integration
39. Test runner UI
40. Agent-driven test writing
41. Test coverage overlay
42. Conflict resolution UI
43. CI log streaming in Inspector
44. Reviewer load balancing
45. AI issue decomposition
46. Time-in-status tracking
47. Minimap
48. Split terminal panes
49. Presence awareness
50. Ambient sound mode
51. Pomodoro timer
52. Do Not Disturb mode

---

## Appendix: Reference Apps Summary

| App | Best lesson for Anvil | Their gap |
|-----|----------------------|-----------|
| Cursor | Autonomy slider, cloud agents, plugin ecosystem | Electron, no opinionated workflow |
| Windsurf Cascade | Background planning, checkpoints, queued messages | Electron, sidebar-only AI |
| Zed | Slash commands with folded text, branch-diff context, ACP, native performance | No workflow/project management |
| VS Code + Copilot | Tool approval memory, multi-session, #usages tool | Electron, no opinionated workflow |
| Warp | @ context in any input, agent oversight, WARP.md, native Metal | Terminal-only, not a full dev environment |
| Linear | Chord navigation, triage inbox, agent in every context, optimistic updates | Web/Electron, no code integration |
| Raycast | Command palette as product identity, snippets, native only | Launcher only, no coding workflow |
| Superhuman | j/k inbox, triage states as first-class, speed as identity | Email only |

---

*Document generated 2026-03-27. Update when competitive landscape shifts or v0.2 scope changes.*
