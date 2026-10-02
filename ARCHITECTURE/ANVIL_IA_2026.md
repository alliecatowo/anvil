# Anvil Information Architecture — 2026 Proposal

**Status:** Proposal
**Author:** Product Research
**Date:** 2026-03-27
**Scope:** Top-level navigation, semantic hierarchy, naming conventions, tab model, provider naming

**Note:** This is historical research and proposal material. The canonical shell vocabulary and current naming decisions now live in [`ARCHITECTURE/SHELL_VOCABULARY.md`](../ARCHITECTURE/SHELL_VOCABULARY.md).

---

## 1. Research Summary

### 1.1 Xcode

Xcode uses a strict four-area vocabulary that Apple has maintained for over a decade:

- **Navigator area** (left sidebar): Project, Symbol, Find, Issue, Test, Debug, Breakpoint, Report navigators. These are distinct named views, not generic tabs. Each navigator has a purpose named after the domain it exposes.
- **Editor area** (center): Source Editor, Assistant Editor, Canvas (SwiftUI preview). The editor area can be split horizontally and vertically; each split is a peer editor, not a sub-tab.
- **Inspector area** (right): File Inspector, Quick Help Inspector, Accessibility Inspector, Identity/Attributes/Size/Connections Inspectors (Interface Builder context). Inspectors are always tied to the current selection.
- **Toolbar**: Scheme picker, run/stop controls, destination picker, and navigator/inspector toggle buttons. The toolbar owns global actions; the navigator owns navigation; the inspector owns selection detail.
- **Tabs**: Xcode 13+ added window-level tabs at the top. Each tab has its own independent navigator/editor/inspector state. This is distinct from editor splits which share the same tab context.
- **Status bar**: Build progress, warnings, git branch, simulator target.

In Xcode 26, agentic coding integrates through a sidebar pane in the Navigator area — agents appear as an additional navigator view, not as a separate top-level window mode. The transcript and file-change log live in a sidebar panel associated with the active navigator context. Apple kept their existing shell; they extended the navigator with an agent view.

Key semantic principle: Xcode's naming is always a noun describing what the area *contains*, not what the user *does*. "Navigator" navigates. "Inspector" inspects. "Editor" edits. "Canvas" renders. The nouns are stable even when content changes.

### 1.2 OpenAI Codex Mac App

Codex organizes around two top-level concepts: **projects** and **threads**.

- A **project** maps to a repository or working directory.
- A **thread** is a single agent task — a scoped, durable conversation with its own context, model, worktree, and execution history.
- Threads are the primary navigable entity in the sidebar, grouped under their project.
- Multiple threads can run in parallel; each is isolated via git worktree.
- The main area shows the active thread: transcript, tool calls, diffs, status.
- There is no tab model in the traditional sense. The sidebar IS the session list. Switching threads is switching context.
- There is no persistent "mode" toggle — the app has one mode: supervise agents working on tasks.

Key insight: Codex traded breadth for depth. It is a focused command center for agent supervision, not a general IDE shell. It does not need a mode concept because it has exactly one mode. Anvil has ten or more domains of work; it cannot use the same single-purpose shell.

### 1.3 Cursor

Cursor's IA started as a pure VSCode fork. Cursor 2.0 diverged substantially:

- The left sidebar still has the VSCode Activity Bar (Explorer, Search, Source Control, Extensions) but adds an **Agents** entry.
- The **Chat/Composer panel** (Cmd+I) is the primary AI surface. It opened right, then moved to various positions across versions.
- In Cursor 2.0, an **agent sidebar** appears on the right side when in agent-first mode, listing active agents, their states, and progress indicators. Users toggle between Classic Editor layout and Agent layout.
- **Background Agents** (renamed "Cloud Agents" in 2.0) run in isolated cloud environments with their own branch, accessible from a background-agents tab in the sidebar.
- **Plan Mode** is a sub-mode of the Composer — users create a plan, then execute it, optionally with different models per phase.
- **Tabs** are the same as VSCode editor tabs: each open file is a tab at the top of the editor area. Agent conversations also appear as tabs inside the Composer panel.
- What Cursor added vs VSCode: a right-side AI panel, background agent management, codebase indexing infrastructure, and a "rules" system for context.
- What they kept: file explorer, editor group model (splits + tabs), activity bar, status bar, extension marketplace.

Key insight: Cursor shows the tension of grafting an agent workflow onto a file-first IA. The agent pane is a tab *within* a sidebar that is itself a tab in the activity bar. The nesting creates cognitive overhead. The file tree and the agent threads live at different hierarchy levels, which makes it awkward to navigate between them.

### 1.4 VSCode

VSCode's canonical naming (from official extension API docs):

- **Activity Bar**: The leftmost icon strip. Each icon activates a View Container in the Primary Sidebar.
- **Primary Sidebar**: One or more Views (e.g., Explorer, Search, Source Control, Extensions, Run and Debug). Only one View Container is shown at a time.
- **Secondary Sidebar**: Opposite to Primary, usually right-side. Can host any panel moved there by the user.
- **Editor Area**: Center. Contains Editor Groups (tab strips + split panes). Each Editor Group has its own tab bar.
- **Panel**: Bottom area. Houses Terminal, Problems, Output, Debug Console, and any extension-contributed panel views.
- **Status Bar**: Fixed bottom. Branch, errors/warnings, encoding, line/column, notifications.

The "Panel" (bottom) vs "Sidebar" (left/right) distinction is intentional: bottom panels are transient/utility surfaces, while sidebars are persistent navigation surfaces.

Key naming insight: VSCode calls the icon strip the "Activity Bar" and the content it exposes the "Sidebar." These are two concepts, not one. The activity bar icon is NOT the sidebar — it is the selector that opens the sidebar view. Many apps blur this distinction and suffer for it.

### 1.5 Zed

Zed uses three **docks** (left, right, bottom) that contain **panels**. Panel vocabulary:

- **Project Panel**: file tree, left dock.
- **Outline Panel**: symbol outline, right dock.
- **Terminal Panel**: tabbed terminal sessions, bottom dock (can move to sides).
- **Agent Panel**: AI conversation threads, right dock.
- **Git Panel**: source control changes, left or right.
- **Collaboration Panel**: real-time multi-cursor sessions.

Zed's model is strictly dock-and-panel: every tool surface is a named panel that docks to an edge. The center is always the editor pane group. Panels can be toggled, moved, and zoomed. The active panel and its state restore across sessions.

Key insight: Zed proves you can have a fast, native-feeling IDE without a separate "mode" concept. Everything is a panel that docks. The simplicity is a strength. Zed's weakness for Anvil's purposes: it has no concept of workflow phases (Plan, Build, Review, Deploy). It is purely an editor with good tooling panels.

### 1.6 macOS Tahoe / Liquid Glass HIG

From WWDC25 "Build a SwiftUI app with the new design" and the macOS Tahoe release:

- **Liquid Glass** is a new material for sidebars, toolbars, tab bars, and floating controls. Sidebars now float above content rather than being recessed into the window chrome.
- **NavigationSplitView** supports the new floating Liquid Glass sidebar. The sidebar column visually floats; content extends behind it using `backgroundExtensionEffect`.
- **Toolbar items** are automatically grouped into Liquid Glass capsule clusters. The `ToolbarSpacer` API creates explicit group breaks.
- **Tab bars** float above content (on iPhone) or stay at the top with glass material (on macOS).
- **Badges** are a first-class API on toolbar items.
- **GlassEffectContainer** groups multiple glass elements so they share sampling regions (correct refraction when elements are adjacent).

What this means for Anvil's IA:
- The sidebar floating model aligns well with a persistent navigation rail — it can visually recede when content is in focus.
- Toolbar groups should be semantically meaningful, not just visual clusters. Each group should have one purpose.
- The inspector model (right-side detail panel) aligns with the Liquid Glass layering — a secondary glass surface to the right.
- macOS Tahoe does not change the fundamental NavigationSplitView semantics (sidebar, content, detail). It makes the existing hierarchy look better.

---

## 2. Answers to the Five Questions

### Q1: What should Anvil's top-level navigation concept be called?

**Recommendation: "Spaces" — not "Modes", not "Workspaces"**

Rationale:

"Mode" is wrong. A mode is a temporary state toggle — vim has modes, tools have modes. Modes imply you leave one and enter another. Anvil's navigation areas are not toggles; they are persistent destinations with their own sidebar state, history, and selections. "Mode" language actively trains users to think of navigation as transient, which works against Anvil's goal of being a durable development environment.

"Workspace" is almost right but has a collision problem. "Workspace" already means the current project/repo in VSCode, JetBrains, and most developer tooling. Calling Anvil's top-level navigation areas "Workspaces" creates immediate confusion when onboarding developers from those tools. It also collides with the existing `Workspaces` dropdown in Anvil's current toolbar.

"Spaces" is correct. It is:
- Neutral — not overloaded by any other tool
- Spatial — implies persistence ("I'm in my Agent space"), not temporality
- Native-feeling — Xcode calls them areas; macOS itself calls virtual desktops "Spaces"
- Short — fits in collapsed rail tooltips without truncation
- Extendable — "Intent Space", "Agent Space" read naturally

The five top-level spaces should be:

| Space | Current Name | Rationale for Change |
|-------|-------------|---------------------|
| **Plan** | Intent | "Intent" is abstract; "Plan" is a verb-noun that describes what you do here |
| **Build** | Agent + Editor | Collapse agent sessions and editing into one space (agent IS the build tool) |
| **Review** | Review | Keep; it is already correct |
| **Operate** | Ship | "Ship" implies only deployment; "Operate" includes deploy, observability, incidents |
| **Library** | (Docs + Extensions, currently buried) | New; elevates reference material and tooling configuration |

Bottom-of-rail utility anchors (not spaces, just fast-access targets):
- Search (global)
- Terminal (utility deck entry)
- Inbox (notifications, top-level badge)
- Settings

**Tab model within spaces:**

Anvil should NOT have a global tab bar at the top of the window switching between spaces. That is the current "Mode tabs" approach and it has two problems: (1) it puts navigation in the titlebar area, fighting with the window chrome, and (2) it makes the collapsed state confusing (do you switch via icon rail or tab bar?).

Instead:
- The **icon rail** is the primary space switcher (always visible, left edge)
- Within the **Build** space, the editor surface uses standard editor tabs (file tabs, identical to Xcode/VSCode)
- Within the **Build** space, agent sessions are listed in the sidebar — switching sessions is sidebar navigation, not a tab switch
- No global window-level tabs for spaces (unlike Xcode's optional window tabs)

This is Codex's model for sessions (sidebar list, not tab bar) applied to all spaces, combined with VSCode's editor tabs for files.

---

### Q2: What is the correct semantic hierarchy?

**Recommended hierarchy:**

```
App
└── Space (5 top-level: Plan, Build, Review, Operate, Library)
    ├── Sidebar Navigator (space-owned, contains sections)
    │   └── Section (collapsible group of navigable items)
    │       └── Item (selectable entity: ticket, session, PR, deploy, file...)
    ├── Content Area (main surface for the selected item)
    │   └── Editor Tabs (in Build space only, for open files)
    └── Inspector (selection-driven, right side, collapsible)

Utility Deck (independent of space, bottom dock)
└── Pane (Terminal, Output, Problems, Background Tasks)
```

**On mixing Intent and Agent in a flat mode list:**

The current flat list [Intent, Agent, Review, Ship, Editor, Database, Terminal...] is wrong in two ways:

1. Intent and Agent are workflow phases, while Editor, Database, Terminal are tools. Mixing phases and tools in one flat list creates a category error. Users cannot form a mental model: "do I go to Agent mode or Editor mode when I'm editing AI-generated code?"

2. The flat list has no grouping principle, so as features are added, the rail degrades into a long icon strip (see: VSCode's activity bar after installing 20 extensions).

The correct answer is to group by **domain of concern**, not by **feature type**:

- **Plan space**: Everything about defining work — tickets, issues, boards, specs, linked docs. Provider integrations: Linear, Jira, GitHub Issues.
- **Build space**: Everything about creating — editor, agent sessions, database queries, terminal (light). Agent sessions and file editing belong together because agents produce files and developers review/edit agent output in the same workflow.
- **Review space**: Everything about validating — PRs, diffs, test runs, CI status, code threads. Provider integrations: GitHub/GitLab PRs, CI systems.
- **Operate space**: Everything about running — deployments, environments, logs, errors, messaging (team comms around incidents), alerts. Provider integrations: Vercel, Railway, AWS, Slack, PagerDuty.
- **Library space**: Everything about knowing — docs, runbooks, API references, snippets, extensions/plugins, provider configuration. This is where you configure Anthropic, OpenAI, GitHub tokens, etc.

**On the "Project Navigator" question:**

Anvil should NOT have a universal "Project Navigator" that is always visible across all spaces. That is Xcode's pattern because Xcode IS an editor — every view relates back to files. Anvil is not primarily a file editor; files are one artifact among many.

Instead, file navigation belongs in the **Build space sidebar** under a "Files" section. When you are in Plan, you navigate tickets, not files. When you are in Operate, you navigate deployments. The sidebar adapts to the space, just as Xcode's Navigator adapts to which navigator (Project, Source Control, etc.) is selected.

The analog to Xcode's Project Navigator in Anvil is the **Plan space Inbox** — the universal inbox of assigned/pending work items. This is the "home" view because work starts with intent, not with a file tree.

---

### Q3: Provider abstraction naming

**Recommendation: "Connections" in setup/configuration, "Provider" only in technical documentation**

Analysis of how each tool names external services:

- **Xcode**: Does not use a general term. Platform configurations ("scheme"), signing certificates ("account"), and source control remotes ("remote") are each named by their specific domain. There is no general "integrations" concept.
- **VSCode**: Uses "Extensions" for the plugin mechanism. External services are connected through extension settings — there is no first-class "connections" concept in the base app, though extensions like GitHub Copilot call their setup "sign in" and show "GitHub account" in the status bar.
- **Cursor**: Shows provider as model selector (OpenAI, Anthropic, etc.) in a "Model" dropdown. No general "connections" vocabulary.
- **Linear**: Uses "Integrations" for connecting GitHub, Slack, etc. The integrations page lists connected services with status indicators.
- **JetBrains**: Uses "Plugins" for extensions and "Services" for database connections, deployment targets, etc. The Services tool window lists: databases, run configurations, Docker, remote servers.

For Anvil, the correct word depends on the surface:

| Surface | Recommended Word | Rationale |
|---------|-----------------|-----------|
| Library space sidebar section | **Connections** | Describes the relationship (you have a connection to GitHub), not the implementation |
| Setup flow title | **Connect to [Service]** | Action-oriented, matches system patterns ("Sign in with Apple") |
| Status bar active indicator | **[Service name]** (no wrapper word) | "GitHub" not "GitHub Integration" |
| Settings/configuration form | **[Service] Connection** | "GitHub Connection", "Anthropic Connection" |
| AI model selector | **Model** | The choosable thing is the model, not the provider connection |
| In error/empty states | **Not connected** / **Connect [service]** | Clear, actionable |

Do NOT use:
- "Integrations" — sounds like third-party add-ons, which implies Anvil is a host platform for plugins, not an application with provider-agnostic features
- "Sources" — ambiguous (data sources? source control? context sources?)
- "Providers" — too technical; correct internally in code but confusing as UI copy
- "Extensions" — already means plugins in VSCode and Xcode; collision risk

**Recommendation: Use "Connections" in the Library space sidebar. Use "Connect [Service]" in setup flows. Never use "Provider" as user-visible copy.**

---

### Q4: Tab model

**Recommendation: Option (c) — Editor tabs within the Build space only, plus multi-window support**

Full analysis:

Option (a) — No tabs at all (Codex style): Works for a single-purpose agent app. Fails for Anvil because developers legitimately need multiple files open simultaneously while editing AI-generated changes. Codex can get away with no editor tabs because it does not have an editor. Anvil has one.

Option (b) — Persistent window tabs per space (Xcode style): Xcode window tabs create separate window-like contexts. This is appropriate for an IDE where you might want "one window for UI work, one window for networking code." For Anvil, spaces already serve this function. Adding window tabs on top of spaces creates a two-level navigation problem with no clear mental model.

Option (c) — Editor tabs within Build space only: This is correct. Files are the entity that meaningfully benefits from tabs. You open `ContentView.swift`, `APIClient.swift`, and a diff simultaneously. These are document tabs, not space tabs. They live in the editor pane inside the Build space, exactly where Xcode and VSCode put them.

Option (d) — Multi-window support: Should be supported as a secondary capability (Cmd+Shift+N for new window), not as the primary model. Each window would have its own space state.

**Concrete tab rules:**

- File editor tabs: live at the top of the editor pane in Build space. Standard Xcode/VSCode behavior: Cmd+T new file, Cmd+W close, Cmd+Shift+[ / Cmd+Shift+] switch.
- Agent sessions: NOT tabs. Listed in the Build space sidebar under "Sessions". Single-click switches the active session in the content area. This matches Codex's model.
- Terminal sessions: NOT top-level tabs. Listed in the Utility Deck terminal pane as named sessions, switchable via tab strip WITHIN the terminal pane. This is identical to Warp's model.
- Database query tabs: Tabbed within the database pane (query 1, query 2, etc.) in the Build space content area.
- PR diff tabs: The diff viewer in Review space supports multiple file tabs within the diff session.

No global window tabs switching spaces. No mode tab bar at the window titlebar level.

---

### Q5: The "Workspaces" concept — what to rename it

**Recommendation: Eliminate the "Workspaces" dropdown entirely. Replace with space-owned sidebar sections.**

Current state: The toolbar has a "Workspaces" dropdown that opens a popover listing Editor, Terminal, Database, Docs, and other auxiliary mode options. This is wrong for three reasons:

1. "Workspace" already means "project" in most developer tools. Using it for "what surface am I looking at" is a category error.
2. A toolbar dropdown for navigating between major areas is a VSCode/browser-style pattern. macOS applications use a sidebar, not a dropdown menu, for primary navigation.
3. The dropdown implies these are secondary options hidden from the primary rail — but Editor and Terminal are not secondary for a developer. They deserve first-class placement.

**The correct answer:** These tool surfaces belong inside the Build space, not as a separate concept.

The Build space sidebar contains sections for:
- **Sessions** (agent threads)
- **Files** (editor/file tree)
- **Data** (database connections and queries)
- **Terminal** (quick access; full terminal is in the Utility Deck)

Switching between "editor view" and "agent view" in the Build space is done by selecting the appropriate sidebar section or by clicking into the content area — not by a dropdown.

The Utility Deck (bottom dock, JetBrains-style) handles:
- Full-screen terminal pane
- Output/logs
- Problems/diagnostics
- Background task monitor

This replaces the current arrangement where Terminal is both a mode AND a sidebar item AND a panel toggle — three representations of one thing.

**What to call the former "Workspaces":** The concept dissolves. The dropdown disappears. Each surface lives where it belongs:
- Editor tabs live in the Build space content area
- Terminal lives in the Utility Deck
- Database lives in the Build space sidebar
- Docs live in the Library space
- The term "Workspaces" is retired from user-visible text

---

## 3. Proposed IA Diagram

### 3.1 Full Window Layout

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Traffic lights   Project scope    Branch      AI Model      [Search ⌘K]     │
│                   MyProject ▾      main ▾      Claude ▾                      │
├───┬───────────────┬────────────────────────────────────┬──────────────────────┤
│   │               │                                    │                      │
│ R │  Sidebar      │  Content Area                      │  Inspector           │
│ A │  Navigator    │                                    │  (selection-driven,  │
│ I │               │  (changes based on selected        │   toggle ⌘⇧I)        │
│ L │  Sections:    │   sidebar item and space)          │                      │
│   │  [varies by   │                                    │  Shows:              │
│   │   space]      │  In Build/Files: editor with       │  - item metadata     │
│   │               │    file tabs at top                │  - linked items      │
│   │               │  In Build/Sessions: agent          │  - actions           │
│   │               │    conversation + diff viewer      │  - config            │
│   │               │  In Plan: ticket board/list        │                      │
│   │               │  In Review: diff + PR thread       │                      │
│   │               │  In Operate: deploy dashboard      │                      │
│   │               │  In Library: doc browser           │                      │
│   │               │                                    │                      │
├───┴───────────────┴────────────────────────────────────┴──────────────────────┤
│  Utility Deck  [Terminal]  [Output]  [Problems]  [Tasks]                      │
│  (resizable, toggle ⌘J, independent of space state)                          │
├───────────────────────────────────────────────────────────────────────────────┤
│  branch ∙ connection status ∙ agent state ∙ cost ∙ errors ∙ clock            │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Rail Detail

```
┌────┐
│    │  [Plan icon]      — tickets, boards, sprints, specs
│    │  [Build icon]     — agents, editor, database
│    │  [Review icon]    — PRs, diffs, tests
│    │  [Operate icon]   — deploys, logs, messaging
│    │  [Library icon]   — docs, extensions, connections
│    │
│    │  ────────────────
│    │
│    │  [Search]         — global search ⌘K
│    │  [Terminal]       — toggle Utility Deck ⌘J
│    │  [Inbox]  ●3      — notifications with badge
│    │  [Settings]       — app settings
└────┘
```

### 3.3 Build Space Sidebar

```
BUILD
├── Sessions
│   ├── ● fix-auth-flow          (running)
│   ├── ○ add-dark-mode          (queued)
│   └── ✓ update-deps            (done)
├── Files
│   ├── Open Editors (2)
│   ├── File Tree
│   └── Symbols
├── Data
│   ├── main.db (SQLite)
│   └── + Add Connection
└── Search
    └── Find in Project ⌘⇧F
```

### 3.4 Plan Space Sidebar

```
PLAN
├── Inbox
│   ├── Assigned to me (4)
│   ├── Blocked (1)
│   └── Due this week (3)
├── Boards
│   ├── Active Sprint
│   ├── Backlog
│   └── Roadmap
├── Views
│   ├── Board
│   ├── Table
│   └── Timeline
└── Artifacts
    ├── Specs
    └── Meeting Notes
```

### 3.5 Review Space Sidebar

```
REVIEW
├── Changes
│   ├── Uncommitted (3 files)
│   └── Staged (0)
├── Pull Requests
│   ├── Review requested (2)
│   ├── Authored (1)
│   └── All open
├── Checks
│   ├── CI: Passing
│   └── Coverage: 78%
└── History
    └── Recent Reviews
```

### 3.6 Operate Space Sidebar

```
OPERATE
├── Environments
│   ├── production
│   ├── staging
│   └── preview/pr-42
├── Deployments
│   ├── Latest: v1.4.2 ✓
│   └── History
├── Observe
│   ├── Errors (2 new)
│   ├── Logs
│   └── Alerts
└── Comms
    ├── #incidents
    └── Direct Messages
```

### 3.7 Library Space Sidebar

```
LIBRARY
├── Docs
│   ├── Project Docs
│   ├── API References
│   └── Runbooks
├── Assets
│   ├── Snippets
│   └── Templates
├── Extensions
│   ├── Installed (12)
│   └── Updates (2) ●
└── Connections
    ├── AI: Claude (Anthropic)
    ├── Code: GitHub
    ├── Deploy: Vercel
    └── + Add Connection
```

---

## 4. Complete Naming Convention Table

### 4.1 Shell Structure — Canonical Names

| Concept | Name in Code | Name in UI | Notes |
|---------|-------------|-----------|-------|
| Left icon strip | `AnvilRail` | — (no visible label) | Never called "Activity Bar" — confusing VSCode overlap |
| Top-level navigation area | `AnvilSpace` | "Plan", "Build", "Review", "Operate", "Library" | Replaces `AnvilMode` enum |
| Left content list | `AnvilSidebar` | — | Contains sections and items for current space |
| Sidebar section | `SidebarSection` | "Sessions", "Files", "Inbox", etc. | Nouns only, space-specific |
| Main content surface | `ContentArea` | — | No visible UI label needed |
| Right detail panel | `Inspector` | — (toggle button label: "Inspector") | Matches Xcode/Apple HIG naming |
| Bottom tool pane area | `UtilityDeck` | — (tab strip shows pane names) | Replaces "Auxiliary mode" concept |
| Individual bottom pane | `UtilityPane` | "Terminal", "Output", "Problems", "Tasks" | Matches VSCode Panel names |
| Toolbar scope cluster | `ScopeBar` | — | Shows: Project, Branch, AI Model |
| Global search / command | `CommandPalette` | — (trigger: ⌘K) | Keep current name, it is industry-standard |

### 4.2 Space Names — Old vs New

| Old Name | New Name | Rationale |
|----------|---------|-----------|
| Intent | **Plan** | Concrete noun; describes what you find here |
| Agent | merged into **Build** | Agent is a tool inside Build, not a peer to Review |
| Review | **Review** | Keep; already correct |
| Ship | **Operate** | Broader; encompasses deploy + observe + comms |
| Editor (auxiliary) | merged into **Build** | Editor is a surface inside Build |
| Database (auxiliary) | merged into **Build** | Database is a surface inside Build |
| Terminal (auxiliary) | moved to **Utility Deck** | Terminal is a utility pane, not a space |
| Docs (auxiliary) | moved to **Library** | Docs is a section inside Library |
| Messaging (auxiliary) | moved to **Operate > Comms** | Messaging around incidents belongs in Operate |
| Notifications (auxiliary) | **Inbox** in rail + all spaces | Notifications surface in the rail, not a space |
| Testing (auxiliary) | surfaced in **Review** | Tests are part of the review/validation workflow |
| Extensions (auxiliary) | moved to **Library > Extensions** | Extensions are a library concept |

### 4.3 Entity Names — Cross-Space

| Entity | Name | Used In |
|--------|------|---------|
| Work to be done | **Work item** | Plan sidebar, Plan content |
| Agent execution unit | **Session** | Build > Sessions |
| Source code PR | **Pull Request** | Review sidebar |
| Running environment | **Environment** | Operate sidebar |
| Deployment event | **Deployment** | Operate sidebar |
| External service link | **Connection** | Library > Connections |
| Terminal instance | **Terminal session** | Utility Deck |
| Database query history | **Query** | Build > Data |
| Documentation page | **Doc** | Library > Docs |
| Extension/plugin | **Extension** | Library > Extensions |
| AI provider | **Connection** (UI) / `Provider` (code) | Library > Connections |

### 4.4 Provider / Connection Naming

| Context | Use | Example |
|---------|-----|---------|
| User-facing setup | "Connect to [Service]" | "Connect to GitHub" |
| Library sidebar section header | "Connections" | "CONNECTIONS" |
| Status bar / scope bar | "[Service]" alone | "GitHub", "Claude" |
| Error state | "Not connected" / "Reconnect [Service]" | "Reconnect GitHub" |
| Settings form title | "[Service] Connection" | "Anthropic Connection" |
| Internal code (protocols, types) | `Provider` | `AIProvider`, `GitProvider` |
| Never in UI | "Provider", "Integration", "Source", "Extension" (for connections) | — |

---

## 5. What to Remove or Retire

### 5.1 The Mode Tab Bar

The current `ModeTabBar` rendered at the top of the window listing [Intent, Agent, Review, Ship, ...] should be removed.

Replace with: the rail on the left edge. The rail is always visible, has badge support, supports keyboard navigation, and does not compete with the window titlebar.

If a compact mode indicator is needed in the toolbar for orientation, a single non-interactive badge showing the current space name ("BUILD") is acceptable — but it should not be a tab strip.

### 5.2 The "Workspaces" Dropdown

Remove the "Workspaces ▾" toolbar button and popover.

Each surface that lived in it moves to: Build space sidebar (Editor, Database), Utility Deck (Terminal), Library space (Docs, Extensions).

### 5.3 "Auxiliary" Concept in Code

`AnvilMode.auxiliaryModes`, `AuxiliarySidebar`, and the auxiliary/core mode split in `AppState` should be removed. There is no auxiliary/core distinction in the user model — only five spaces and a utility deck.

### 5.4 "coreModes" / "workspaceModes" / "contextModes" Groupings

These are implementation accidents. They exist because the current enum has too many things in it. With the five-space model, the enum has exactly five cases and these groupings disappear.

---

## 6. What to Keep

### 6.1 The Inspector

The right-side inspector panel with `⌘⇧I` toggle is correct and should stay. The name "Inspector" is right (matches Apple HIG). The behavior of being selection-driven and collapsible is right. The current 320px default width is right.

What to fix: the inspector should actually reflect the current selection. Today it is largely a placeholder. But the structural concept is sound.

### 6.2 The Status Bar

The bottom status bar is well-designed. Keep: branch, provider status, agent state, cost, errors, clock. The status bar content should reference "Connection" status, not "Provider" status, when surfacing external service state.

### 6.3 The Command Palette (⌘K)

The command palette / global search surface is correct. Keep the `⌘K` shortcut. Keep the concept. It is universally understood in developer tooling (VSCode, Raycast, Linear, Arc) and is a strong differentiator for keyboard-first users.

### 6.4 The j/k Keyboard Navigation

Vim-style list navigation in sidebars is worth keeping. It differentiates Anvil from Cursor (which doesn't have it) and aligns with the Raycast/Linear reference set.

### 6.5 The Inspector Toggle Shortcut

`⌘⇧I` for the inspector. Keep; it matches Xcode.

---

## 7. Implementation Sequence

The IA changes described here touch nearly every file in AnvilUI. The recommended migration order minimizes breakage:

**Phase 1 — Rename without restructure (safe, low-risk)**
1. Rename `AnvilMode` enum to `AnvilSpace` with new case names: `.plan`, `.build`, `.review`, `.operate`, `.library`
2. Update all references to `currentMode`, `switchMode`, `coreModes` etc.
3. Remove the `ModeTabBar` component; update `MainWindow` to not render it
4. Rename `AuxiliarySidebar` to `GenericSpaceSidebar` as a temporary holding type

**Phase 2 — Collapse auxiliary modes into spaces (medium)**
5. Merge Editor, Database into Build space sidebar sections
6. Move Terminal to UtilityDeck (new component at bottom dock)
7. Move Docs, Extensions into Library space sidebar
8. Move Messaging, Notifications into Operate space and rail-level inbox

**Phase 3 — Add missing surfaces (feature work)**
9. Build the Utility Deck component with pane management
10. Implement Library space with Connections section
11. Implement Operate space with Comms and Observe sections
12. Wire real provider/connection state into Library > Connections

**Phase 4 — Polish and integration (last)**
13. Remove "Workspaces" dropdown from toolbar
14. Add scope bar with Project / Branch / Model selectors
15. Apply Liquid Glass materials to rail and sidebar per Tahoe HIG
16. Wire inspector to real selection state across all spaces

---

## 8. Decision Rationale Summary

| Question | Decision | One-Line Reason |
|----------|---------|----------------|
| What to call top-level navigation | "Spaces" | Spatial, non-overloaded, implies persistence |
| Whether to keep "Modes" | No | "Mode" implies temporary state toggle, not a persistent destination |
| Semantic grouping | 5 spaces: Plan/Build/Review/Operate/Library | Workflow phases plus a reference library; tools collapse into phases |
| Project Navigator concept | No universal navigator; each space has its own sidebar | Anvil is not file-primary; the sidebar adapts to the space |
| Mixing Intent and Agent | No — merge Agent into Build | Agent sessions are a tool, not a workflow phase parallel to planning |
| Provider naming in UI | "Connections" | Non-technical, relationship-describing, avoids "Provider"/"Integration" overload |
| Tab model | Editor tabs in Build space only; sessions via sidebar list | Separates document tabs (files) from session navigation (sidebar) |
| Workspaces dropdown | Remove it | Surfaces move to correct spaces and Utility Deck |
| "Workspaces" term | Retire from UI copy | Overloaded by VSCode/JetBrains to mean "project"; creates confusion |
| Multi-window | Support but not primary | Cmd+Shift+N new window; spaces provide sufficient context isolation |

---

## Sources

- Apple Developer: [Configuring the Xcode project window](https://developer.apple.com/documentation/xcode/configuring-the-xcode-project-window)
- Apple WWDC25: [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- Apple: [macOS Tahoe — New Features](https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf)
- Apple Newsroom: [Apple introduces a delightful and elegant new software design](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- Apple Newsroom: [Xcode 26.3 unlocks the power of agentic coding](https://www.apple.com/newsroom/2026/02/xcode-26-point-3-unlocks-the-power-of-agentic-coding/)
- OpenAI: [Introducing the Codex app](https://openai.com/index/introducing-the-codex-app/)
- OpenAI Developers: [Codex App](https://developers.openai.com/codex/app)
- IntuitionLabs: [OpenAI Codex App: A Guide to Multi-Agent AI Coding](https://intuitionlabs.ai/articles/openai-codex-app-ai-coding-agents)
- Cursor: [Changelog 2.0](https://cursor.com/changelog/2-0)
- Cursor: [Background Agent](https://docs.cursor.com/en/background-agent)
- VS Code Docs: [User interface](https://code.visualstudio.com/docs/getstarted/userinterface)
- VS Code Docs: [Activity Bar UX guidelines](https://code.visualstudio.com/api/ux-guidelines/activity-bar)
- VS Code Docs: [Panel](https://code.visualstudio.com/api/ux-guidelines/panel)
- Zed Blog: [Introducing Zed's new panel system](https://zed.dev/blog/new-panel-system)
- DeepWiki: [Zed Workspace](https://deepwiki.com/zed-industries/zed/3.1-workspace)
- MacRumors: [Xcode 26.3 With Support for AI Agents](https://www.macrumors.com/2026/02/26/apple-releases-xcode-26-3/)
