# Competitive IA Research 2026

Last updated: 2026-03-27

This document synthesizes current information architecture patterns from Xcode, VS Code, JetBrains IDEs, Cursor, Claude Code, Codex, and Raycast, then turns them into a concrete next-gen hierarchy proposal for Anvil.

The goal is not to clone any one tool. The goal is to combine their strongest patterns into a native macOS development environment that can replace the current pile of editor, terminal, chat, deploy, and review tools.

Decision framing:
- Prefer native shell structure over local per-feature chrome.
- Prefer durable entities over one-off views.
- Prefer provider-neutral information architecture with provider-specific configuration and actions.
- Prefer selection-driven detail and inspector flows over stacked sidebars full of mixed responsibilities.

## Research Summary

### Apple / Xcode

Relevant references:
- [Apple HIG: Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars?changes=_9)
- [WWDC23: Inspectors in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10161/?time=234)
- [WWDC24: Xcode essentials](https://developer.apple.com/videos/play/wwdc2024/10181/?time=2141)

What matters:
- Apple explicitly positions the sidebar as a broad, flat navigation surface across peer areas, not as a dumping ground for random actions.
- Apple’s `inspector` API is a structural detail surface tied to selection, not a fake third sidebar.
- Xcode’s navigator, editor, utility area, jump bar, and test/report flows reinforce one principle: selection drives the rest of the window.

Takeaway for Anvil:
- The app should have a real navigation scaffold: rail -> sidebar -> detail -> inspector.
- Sidebars should primarily navigate. Tool actions belong in the toolbar, action menus, contextual menus, or inspector.
- Selection must be first-class and stable across the shell.

### VS Code

Relevant references:
- [VS Code: User interface](https://code.visualstudio.com/docs/getstarted/userinterface?from=20423&from_column=20423)
- [VS Code: Activity Bar UX guidelines](https://code.visualstudio.com/api/ux-guidelines/activity-bar)
- [VS Code: Copilot workspace context](https://code.visualstudio.com/docs/copilot/reference/workspace-context)

What matters:
- VS Code cleanly separates `Activity Bar`, `Primary Side Bar`, `Secondary Side Bar`, `Panel`, `Editor`, and `Status Bar`.
- Views are movable, persistent, and state-restored.
- Workspace context is explicit infrastructure for codebase-aware AI.

Takeaway for Anvil:
- A collapsed state should still expose the full set of major destinations, not just one icon.
- Utility panes like terminal, output, problems, and notifications should be structurally separate from navigation.
- Agent/codebase context should be treated as workspace infrastructure, not just chat UI.

### JetBrains

Relevant references:
- [IntelliJ IDEA: Tool windows](https://www.jetbrains.com/help/idea/tool-windows.html?keymap=secondary_macos_system_shortcuts)
- [IntelliJ IDEA: Tool window layouts](https://www.jetbrains.com/help/idea/tool-window-layouts.html)

What matters:
- Tool windows are task surfaces, not primary navigation.
- Some windows are permanent; others appear only when relevant.
- Layouts are saveable, movable, and restorable.

Takeaway for Anvil:
- Terminal, testing, logs, notifications, and find/results should behave like utility panes.
- The shell should support saved layouts and focus modes.
- Not every concept deserves a permanent sidebar row.

### Cursor

Relevant references:
- [Cursor: Tabs](https://docs.cursor.com/en/agent/chat/tabs)
- [Cursor: Codebase Indexing](https://docs.cursor.com/chat/codebase)

What matters:
- Cursor treats each agent tab as a scoped task with its own context, model, and title.
- It makes codebase indexing explicit and configurable.
- It supports multi-root workspaces.

Takeaway for Anvil:
- Agent work should be task-scoped, not mixed into a single endless conversation stream.
- Codebase understanding should be visible infrastructure, not hidden magic.
- Multi-repo and multi-context work needs first-class modeling.

### Claude Code

Relevant references:
- [Claude Code: Overview](https://docs.anthropic.com/en/docs/claude-code/overview)
- [Claude Code: Common workflows](https://docs.anthropic.com/en/docs/claude-code/tutorials)

What matters:
- Claude Code centers workflow around project-root context, slash commands, file references, subagents, plan mode, and parallel worktrees.
- It is strong at task delegation and codebase operations, but weak as a full native app shell.

Takeaway for Anvil:
- Subagents, plans, worktrees, and command-driven workflows should remain core primitives.
- They should live inside a stronger GUI IA rather than remaining terminal metaphors pasted into panels.

### Codex App

Relevant references:
- [OpenAI: Introducing the Codex app](https://openai.com/index/introducing-the-codex-app/)
- [OpenAI: Introducing Codex](https://openai.com/index/introducing-codex/)
- [OpenAI Help: ChatGPT macOS app release notes](https://help.openai.com/en/articles/9703738-desktop-app-release-notes)

What matters:
- Codex frames the app as a command center for multiple agents, long-running tasks, isolated environments, and progress review.
- The macOS app release notes show repeated emphasis on native toolbar behavior, keyboard focus correctness, background notifications, conversation search, draft restoration, and app integrations.

Takeaway for Anvil:
- Agents should be treated as supervised workers in a broader operating environment.
- Long-running work needs durable status surfaces, not transient cards.
- Native desktop quality is largely won or lost in focus, toolbar, restoration, and interaction correctness.

### Raycast

Relevant references:
- [Raycast Manual: The Basics](https://manual.raycast.com/the-basics)
- [Raycast Manual: Search Bar](https://manual.raycast.com/search-bar)
- [Raycast Manual: Action Panel](https://manual.raycast.com/action-panel)
- [Raycast Blog: How the Raycast API and extensions work](https://www.raycast.com/blog/how-raycast-api-extensions-work)

What matters:
- Raycast has a crisp model: root search, focused command views, and a universal action panel.
- It treats extensions as first-class native citizens instead of second-class mini web apps.
- It keeps global entry fast and context actions discoverable.

Takeaway for Anvil:
- Every selected entity should expose a consistent action menu.
- Global search and command execution should be a first-class shell primitive.
- Extension/provider contributions must render inside the same native shell contract.

## Synthesis: What Anvil Should Become

Anvil should not be “a better editor with AI”.

It should be a **developer operations environment** with four structural layers:

1. `Workspace Rail`
2. `Workspace Sidebar`
3. `Primary Detail Surface`
4. `Inspector + Utility Deck`

That gives the app a stable shell while letting features grow without adding local chrome debt.

## Native macOS Feel Guardrails

This proposal only works if the information architecture is paired with native interaction rules.

Required shell rules:
- The window chrome owns global navigation, scope, and app-level actions.
- The sidebar is navigation first, not a button farm.
- The content header is content-scoped, not a second app toolbar.
- The inspector is tied to selection and can be toggled without changing content layout semantics.
- The utility deck is resizable, dismissible, and restorable independently of sidebar state.
- Hover-only affordances should be additive, never required for discoverability.
- Lists, split views, toolbars, menus, search fields, inspectors, badges, and materials should use AppKit or SwiftUI-native components whenever possible.

Things to explicitly avoid:
- Nested fake toolbars inside the content surface.
- A web-style tab strip pretending to be top-level app navigation.
- Sidebar rows that mix navigation, status, setup, and destructive actions with no hierarchy.
- “Stub affordances” that appear interactive but do not produce state changes or real workflows.

## Proposed Concept Model

### Top-Level Concepts

These should replace the current flat “mode” mindset.

- `Workspace`
  - The user’s current major domain of work.
- `Scope`
  - The current project, repo, branch, provider, environment, or codebase context.
- `Entity`
  - A durable thing the user can select, inspect, act on, and deep-link to.
- `Session`
  - An execution context for work: agent run, terminal session, query tab, test run, deploy run.
- `Utility`
  - A dockable tool pane: terminal, logs, notifications, problems, output.

### Durable Entity Taxonomy

These should become cross-mode concepts throughout the app.

- `Work Item`
  - ticket, issue, task, review request, deploy request, alert
- `Code Resource`
  - file, symbol, branch, diff, commit, PR
- `Runtime Resource`
  - environment, deployment, provider connection, database connection, service
- `Knowledge Resource`
  - doc, note, snippet, search result, prior session
- `Execution Session`
  - agent session, terminal session, query session, test run, build run

These are more stable than the current mode list and give the app a cleaner interaction language.

## Ownership Model

The shell should make ownership obvious. Each region of the window has one job.

| Surface | Owns | Should Not Own |
| --- | --- | --- |
| `Workspace Rail` | top-level workspace switching, global badges, utility entry points | setup forms, inline action clusters, secondary navigation trees |
| `Workspace Sidebar` | entity trees, saved views, scoped navigation, filters relevant to the current workspace | unrelated utilities, one-off action buttons, duplicated content toolbars |
| `Primary Detail Surface` | the selected artifact or workflow: board, editor, diff, log stream, conversation, deployment detail | shell navigation, duplicate sidebars, floating random status chrome |
| `Inspector` | metadata, configuration, secondary actions for the current selection | primary navigation, bulk content browsing |
| `Utility Deck` | terminal, tasks, output, notifications, diagnostics, transient execution surfaces | app-wide navigation, provider configuration forms |

This separation is what prevents the app from collapsing back into “one more electron-ish page with random controls”.

## Next-Gen IA Proposal

### 1. Workspace Rail

This is the collapsed form and the permanent app spine.

It should always remain visible and should never collapse to a single icon.

Recommended rail items:
- `Plan`
- `Build`
- `Review`
- `Operate`
- `Library`

Bottom-of-rail utility anchors:
- `Search`
- `Terminal`
- `Inbox`
- `Settings`

Why this grouping:
- `Plan` = Intent, work queue, project notes, roadmap, docs entry points tied to work definition
- `Build` = Editor, Agents, Database, terminal-adjacent creation workflows
- `Review` = Code review, tests, source control, findings
- `Operate` = Ship, environments, observability, messaging, alerts
- `Library` = Docs, snippets, extensions, providers, saved workflows

This is better than exposing 10+ peer icons because it gives the rail a durable mental model while still supporting broad navigation.

Alternative labels worth testing in prototypes:
- `Plan / Build / Review / Operate / Library`
- `Plan / Create / Validate / Operate / Library`
- `Intent / Build / Review / Ship / Library`

Recommendation:
- Keep `Review` and `Library`.
- Move away from `Mode`.
- Prefer `Operate` over `Ship` once observability, incidents, and provider control become real first-class workflows.
- If existing product language matters, `Intent` can survive as a workspace label, but it should still behave like a workspace, not a mode toggle.

### 2. Workspace Sidebar

The sidebar should be workspace-owned, not globally hardcoded by “mode”.

Each workspace gets useful sections that are mostly navigational, not action spam.

#### Plan

Sections:
- `Inbox`
  - Assigned
  - Blocked
  - Due Soon
  - Needs Triage
- `Boards`
  - Active Sprint
  - Backlog
  - Releases
- `Views`
  - Board
  - Table
  - Timeline
  - Dependencies
- `Artifacts`
  - Specs
  - Notes
  - Linked Docs

#### Build

Sections:
- `Agents`
  - Active
  - Queued
  - Background
  - Syntheses
- `Code`
  - Explorer
  - Open Editors
  - Symbols
  - Search Results
- `Data`
  - Connections
  - Objects
  - Queries
  - History
- `Workspaces`
  - Terminal Sessions
  - Query Sessions
  - Scratchpads

#### Review

Sections:
- `Sources`
  - Local Changes
  - Pull Requests
  - Review Queue
- `Files`
  - Changed Files
  - Threads
  - Checks
- `Verify`
  - Test Runs
  - Failures
  - Coverage
- `History`
  - Recent Reviews
  - Saved Layouts

#### Operate

Sections:
- `Deploy`
  - Environments
  - Deployments
  - Rollbacks
- `Observe`
  - Errors
  - Logs
  - Metrics
  - Alerts
- `Comms`
  - Channels
  - Direct Messages
  - Incidents
- `Control`
  - Providers
  - Secrets
  - Policies

#### Library

Sections:
- `Docs`
  - Project Docs
  - Runbooks
  - API References
- `Assets`
  - Snippets
  - Templates
  - Commands
- `Extensions`
  - Installed
  - Available
  - Updates
- `Providers`
  - AI
  - Data
  - Deploy
  - Notifications

### Utility Ownership

The following surfaces should move out of workspace sidebars and into the utility deck or inspector unless they are the main selected artifact:

- `Terminal`
- `Background Tasks`
- `Problems`
- `Notifications`
- `Output / Logs`
- `Search Results`
- `Selection Details`

This is the key correction for the current app. Utility surfaces should support the work, not compete with navigation.

### 3. Primary Detail Surface

This area should host the main content for the current selection:
- table
- board
- conversation
- editor
- diff
- deploy detail
- schema browser
- test report

It should not carry a second fake navigation bar. It can have a content header, but not shell chrome.

### 4. Inspector

The inspector should be selection-driven and mode-aware.

Examples:
- ticket metadata
- agent config
- file symbol detail
- PR checks/owners
- deployment metadata
- database row detail
- doc outline

It should not be a generic placeholder panel.

### 5. Utility Deck

These are docked or floating task surfaces, not workspace destinations:
- Terminal
- Output / Logs
- Problems / Diagnostics
- Notifications
- Background Tasks

This is where JetBrains tool-window thinking should be borrowed directly.

## Naming Recommendations

### Replace “Mode” with “Workspace”

`Mode` reads like a view toggle.
`Workspace` reads like a persistent domain of work with its own navigation model.

### Use these shell terms consistently

- `Rail`
  - icon-only persistent global navigation
- `Sidebar`
  - current workspace navigator
- `Detail`
  - main selected content
- `Inspector`
  - selected-item metadata/actions
- `Utility Deck`
  - docked pane area
- `Action Menu`
  - context-sensitive command surface for selected item

### Avoid these terms except where literally needed

- `Tab` for everything
- `Mode`
- `Panel` for both utility panes and details
- `Tools` as a catch-all sidebar section
- `Auxiliary`

These are too vague and lead directly to IA drift.

## Collapse Behavior

The collapsed state should follow this contract:

1. The full workspace rail remains visible at all times.
2. Selecting a rail item restores that workspace’s prior sidebar state.
3. The sidebar can be:
   - `Expanded`
   - `Icon Rail Only`
   - `Focus Mode` (rail + detail, utility deck hidden)
4. Utility deck state is independent of sidebar collapse.
5. The app remembers last selection per workspace.

This is better than the current behavior because:
- it preserves orientation
- it matches VS Code’s activity-bar logic
- it still feels Mac-native if rendered with native list/toolbar/material conventions

Recommended rail behavior details:
- The selected workspace icon remains highlighted even when the sidebar is hidden.
- Hover reveals tooltips and optional status summaries, but never the only path to an action.
- Right-click on a rail item opens workspace-specific quick actions such as `New Build Session`, `New Query`, or `Open Review Queue`.
- Badges indicate count or urgency only. They should not encode too many states.
- The rail remembers the last selected entity for each workspace and restores it on re-entry.

## Provider Scope Model

Provider choice should not live inside arbitrary content copy.

Instead, the shell should expose provider scope as a consistent selector in toolbar or workspace header.

Recommended scope surfaces:
- Global toolbar scope cluster:
  - `Project`
  - `Branch`
  - `AI Provider`
  - `Data Provider / Connection`
  - `Deploy Provider / Environment`

Rules:
- workspace shells stay provider-neutral
- provider-specific branding appears in setup/configuration and selected-scope labels
- selected provider affects available actions and visible sections

Provider scopes should be orthogonal, not buried inside a single workspace:

- `AI Scope`
  - provider, model family, approval policy, tool policy
- `Data Scope`
  - provider, connection, database/schema, environment
- `Execution Scope`
  - project, repo, branch, worktree, sandbox
- `Delivery Scope`
  - deployment provider, target environment, rollout lane

That lets Anvil support multi-provider composition instead of teaching the user that every feature only has one hidden backend.

Example:
- `Build > Data` can show `SQLite` today
- later the same shell can show `Postgres`, `MySQL`, `Snowflake`
- without changing the structure of the workspace

## Cross-Mode Entity Navigation

Anvil should support stable deep links between entities across workspaces.

Examples:
- ticket -> branch -> agent session -> PR -> deploy -> alert
- PR thread -> file -> test failure -> fix agent -> rerun -> merge
- alert -> deployment -> env var diff -> terminal session -> follow-up doc

To support that, every entity should be:
- selectable
- linkable
- searchable
- inspectable
- action-menu addressable

This is where Anvil can move past “editor + chat” products.

## Micro-Interaction Standards

These should become shell-wide rules:

- Single click selects and opens primary content.
- Secondary click or `⌘K` opens the action menu for the selected item.
- Every sidebar row can have:
  - primary label
  - optional badge/count
  - optional status dot
  - optional trailing recency/dirty marker
- No row should show a shortcut if that shortcut is not wired.
- Empty states must be explicit:
  - `No provider configured`
  - `No active deploys`
  - `No recent query history`
  - never fake sample operational data unless explicitly marked `Demo`
- Background work should have passive surfacing:
  - status pill in toolbar
  - utility deck task list
  - dock/notification handoff when finished
- Search should have two levels:
  - global root search
  - local in-surface filtering/search
- Toolbar actions should degrade cleanly into menu bar commands and contextual menus so keyboard-first and pointer-first flows stay symmetrical.
- Selection should survive sidebar collapse, utility deck toggles, and inspector visibility changes.
- Empty states should route to the next meaningful setup step, not just announce absence.
- When a row or button opens a new workflow, the destination should be explicit: new detail tab, inspector sheet, utility deck item, or modal.

## Where Anvil Should Surpass The Competition

### Beyond Xcode
- unify code, deploy, incidents, docs, and agents under one shell

### Beyond VS Code
- stronger durable task model, less extension-fragmented IA

### Beyond JetBrains
- better agent orchestration and cross-workspace deep linking

### Beyond Cursor
- agents are one workspace primitive, not the product shell

### Beyond Claude Code
- keep the subagent/worktree power, but with GUI-native structure and state restoration

### Beyond Codex App
- combine agent command center with code/data/review/operate workspaces instead of only agent supervision

### Beyond Raycast
- keep action density and root search, but attach it to durable developer state rather than a launcher-only model

## Recommended Migration Sequence

1. Introduce `WorkspaceRail` and replace the current collapsed-sidebar behavior.
2. Replace flat mode mental model with workspace ownership in `AppState`.
3. Move every auxiliary sidebar to workspace-owned useful sections.
4. Separate `Utility Deck` from workspace sidebars.
5. Make `Inspector` real and selection-driven.
6. Introduce provider scope selectors in toolbar for AI/data/deploy.
7. Introduce global entity IDs and deep-link routing.
8. Add universal action menu behavior for selected entities.
9. Add saved layouts and restore previous workspace/sidebar/deck state.
10. Only then keep expanding per-feature depth inside each workspace.

Suggested sequencing inside that migration:

Phase A:
- rename shell vocabulary from `Mode` to `Workspace`
- remove false affordances and duplicated local toolbars
- establish rail/sidebar/detail/inspector/deck ownership rules

Phase B:
- migrate each existing page into one of the five workspace buckets
- move utility content out of sidebars
- wire real selection, deep-linking, and inspector behavior

Phase C:
- add provider scopes, action menu parity, saved layouts, and global entity routing
- only then expand feature depth within each workspace

## Top 10 IA Decisions

1. Anvil should organize around `Workspace`, not `Mode`.
2. The collapsed state must be a persistent icon rail, never a single current-mode button.
3. Sidebars should primarily navigate entities and views, not host random action buttons.
4. Terminal, logs, notifications, and problems belong to a `Utility Deck`, not to top-level navigation.
5. Inspectors must be structural and selection-driven, following SwiftUI’s inspector model.
6. Provider scope must be a shell concept exposed in toolbar/header, not hidden inside per-mode copy.
7. Every durable thing in the app should be modeled as an entity that can be selected, linked, inspected, and acted on.
8. Agents should be a first-class workspace capability, not the entire product shell.
9. Global search plus context-sensitive action menus should become universal shell primitives.
10. Feature expansion should happen inside a fixed native shell contract so the app does not keep regressing into web-style local chrome.

## Sources

- Apple Human Interface Guidelines: [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars?changes=_9)
- Apple Developer: [Inspectors in SwiftUI: Discover the details](https://developer.apple.com/videos/play/wwdc2023/10161/?time=234)
- Apple Developer: [Xcode essentials](https://developer.apple.com/videos/play/wwdc2024/10181/?time=2141)
- VS Code Docs: [User interface](https://code.visualstudio.com/docs/getstarted/userinterface?from=20423&from_column=20423)
- VS Code Docs: [Activity Bar UX guidelines](https://code.visualstudio.com/api/ux-guidelines/activity-bar)
- VS Code Docs: [How Copilot understands your workspace](https://code.visualstudio.com/docs/copilot/reference/workspace-context)
- JetBrains Docs: [Tool windows](https://www.jetbrains.com/help/idea/tool-windows.html?keymap=secondary_macos_system_shortcuts)
- JetBrains Docs: [Tool window layouts](https://www.jetbrains.com/help/idea/tool-window-layouts.html)
- Cursor Docs: [Tabs](https://docs.cursor.com/en/agent/chat/tabs)
- Cursor Docs: [Codebase Indexing](https://docs.cursor.com/chat/codebase)
- Anthropic Docs: [Claude Code overview](https://docs.anthropic.com/en/docs/claude-code/overview)
- Anthropic Docs: [Common workflows](https://docs.anthropic.com/en/docs/claude-code/tutorials)
- OpenAI: [Introducing the Codex app](https://openai.com/index/introducing-the-codex-app/)
- OpenAI: [Introducing Codex](https://openai.com/index/introducing-codex/)
- OpenAI Help: [ChatGPT macOS app release notes](https://help.openai.com/en/articles/9703738-desktop-app-release-notes)
- Raycast Manual: [The Basics](https://manual.raycast.com/the-basics)
- Raycast Manual: [Search Bar](https://manual.raycast.com/search-bar)
- Raycast Manual: [Action Panel](https://manual.raycast.com/action-panel)
- Raycast Blog: [How the Raycast API and extensions work](https://www.raycast.com/blog/how-raycast-api-extensions-work)
