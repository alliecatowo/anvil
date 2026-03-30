# Shell Vocabulary North Star

**Status:** Canonical
**Scope:** Shell hierarchy, top-level naming, workspace labels, pane vocabulary, and user-facing grouping.

This document is the ground truth for how Anvil names its structural concepts.
If another doc disagrees with this one, this one wins.

## Direct Answer

The live shell spaces are `Plan`, `Build`, `Review`, `Operate`, and `Library`.

`Intent`, `Agent`, `Ship`, `Editor`, `Database`, `Terminal`, `Docs`, `Chat`, `Notifications`, `Testing`, and `Extensions` do **not** all make sense as peer "workspaces" in the final product vocabulary.

They are current implementation labels and transitional product labels, not the final shell language.

The canonical model is:

- `Workspace` = the current project/repo/root context
- `Space` = a top-level destination in the shell
- `Sidebar` = the current space's navigation surface
- `Canvas` = the main content surface
- `Inspector` = the selection-driven detail surface
- `Utility Deck` = docked utilities like terminal/logs/problems/notifications

## Why This Matters

Anvil currently mixes three incompatible ideas:

- `Workspace` as a project/root context
- `Workspace` as a top-level shell destination
- `Mode` as a temporary state toggle

That overload makes the shell harder to understand and makes hidden or half-wired UI feel acceptable because the labels themselves are ambiguous.

The fix is to reserve one word for one job:

- `Workspace` means the current repo/project context
- `Space` means the major shell destination the user is in
- `Mode` should be treated as an implementation term, not the user-facing shell model

## Comparison To Other IDEs

### Xcode

Xcode uses nouns that describe what the area contains or does:

- `Navigator`
- `Editor`
- `Inspector`
- `Toolbar`
- `Utility area`

Xcode is selection-driven. The navigator chooses things, the editor shows the primary artifact, and the inspector shows selection detail.

### VS Code

VS Code keeps the structural contract explicit:

- `Activity Bar`
- `Primary Side Bar`
- `Secondary Side Bar`
- `Editor`
- `Panel`
- `Status Bar`

The important distinction is that the icon strip is not the sidebar. The icon strip selects the sidebar.

### JetBrains

JetBrains uses:

- `Tool windows`
- `Editor`
- `Layouts`

Tool windows are task surfaces, not primary app chrome. Layouts are saved and restored.

## Canonical Anvil Model

### Top-Level Spaces

The stable top-level spaces should be:

- `Plan`
- `Build`
- `Review`
- `Operate`
- `Library`

These are persistent destinations, not transient toggles.

### Recommended Mapping From Current Labels

- `Intent` -> `Plan`
- `Agent` -> `Build`
- `Review` -> `Review`
- `Ship` -> `Operate`
- `Docs` -> `Library`
- `Extensions` -> `Library`
- `Terminal` -> `Utility Deck`
- `Database` -> `Build`
- `Editor` -> `Build`
- `Chat` -> `Library`
- `Notifications` -> `Library` or the global `Inbox`
- `Testing` -> `Review` or `Utility Deck`, depending on whether it is validating work or running tools

### Why `Intent` And `Agent` Should Not Stay As Peer Workspaces

`Intent` and `Agent` are both real parts of the product, but they do not describe stable shell destinations well enough to remain peer workspace names.

`Intent` is a workflow phase for defining and organizing work. That is the `Plan` space.

`Agent` is an execution surface for work. That belongs inside `Build`, because it lives alongside file editing, code generation, terminal commands, and local project state.

Keeping them as peer workspaces makes the app feel like a pile of related features rather than a coherent environment.

### Why `Ship` Is Transitional

`Ship` is the legacy implementation label for the live `Operate` space.
It describes deployment, but Anvil's actual operating surface includes:

- deployments
- environments
- logs
- alerts
- incidents
- operational messaging

`Operate` is the broader and more durable user-facing category.

### Why `Library` Should Exist

`Library` is the stable home for:

- docs
- chat
- snippets
- extensions
- provider configuration
- rules
- references
- reusable knowledge

It is not a tool surface. It is the place where the app's reusable knowledge lives.

## Canonical Shell Hierarchy

```
App
├── Toolbar (three zones)
│   ├── Left: [📁 Project ▾] [🔀 Branch] (context anchor, branch Build-only)
│   ├── Center: Space · Navigator ▾ (Space Compositor with navigator dropdown)
│   │   Examples: "Build · ⊕ Sessions ▾", "Review · Changes ▾"
│   └── Right: [⌘K] [🔔] [ℹ️] [✨] (fixed panel controls)
│
└── Space (Plan, Build, Review, Operate, Library)
    ├── Sidebar (pure content — NO chrome, no navigator picker)
    │   └── Items for the active navigator
    ├── Canvas
    │   └── Views / detail routes
    ├── Inspector
    │   └── selection-driven metadata and quick actions
    ├── Agent Sidebar (sparkles panel — universal AI, contextual per space)
    └── Utility Deck (bottom, always available across all spaces)
        └── Terminal / Problems / Output
```

### Navigators

A **Navigator** is a collection type within a Space. Navigators are selected
via the center toolbar dropdown (the Space Compositor), NOT the sidebar.
The sidebar shows only content for the active navigator — no intra-view chrome.

Per-space navigators:
- **Plan**: No navigator (single view: Tickets). Center shows sprint context.
- **Build**: Sessions, Files, Data, Tests
- **Review**: Changes, Branches, Pull Requests
- **Operate**: Deploy, Monitor
- **Library**: Docs, Rules, Extensions, Inbox, Chat, Schedule

Terminal is NOT a navigator — it lives in the Utility Deck.

### Glass and Materials

Anvil uses solid backgrounds, not translucent materials:
- **Window**: `NSColor.windowBackgroundColor` (solid dark, adapts to appearance)
- **Sidebar + Rail**: `NSColor.controlBackgroundColor` (subtle tone difference from canvas)
- **Canvas**: Inherits window background
- **Toolbar**: Native macOS Tahoe Liquid Glass on toolbar items (automatic)

No `.regularMaterial` or `.ultraThinMaterial` on structural surfaces.
Glass is only on toolbar pills/buttons where macOS applies it natively.

### Agent Sidebar

The Agent Sidebar (sparkles icon, ✨) is the universal AI interaction surface.
It is contextual to the current space:
- In **Plan**: ticket operations, planning conversations
- In **Build**: code sessions, agent chat
- In **Review**: diff explanations, review conversations
- In **Operate**: deployment assistance
- In **Library**: reference queries

The Agent Sidebar is NOT Build-specific. It is the single most important
interaction point in the AIDE and should adapt to whatever the user is doing.

### Toolbar Zones

The toolbar has three stable zones:

- **Left zone** (context anchor): Project dropdown + branch pill (Build-only).
  Answers "where am I working." Project is a Menu with Switch Project and Command Palette.
  Branch pill only appears in the Build space.
- **Center zone** (Space Compositor): `Space · Navigator ▾` dropdown.
  Shows the space name (static) + active navigator name with dropdown to switch.
  Plan shows sprint context instead of a navigator dropdown.
- **Right zone** (panel controls): Fixed set, never changes per space.
  ⌘K, Notifications, Inspector, Agent Sidebar (sparkles).

### Status Bar

The Status Bar is **Build-only**. It shows editor context (cursor position,
encoding, line ending, cost) only when the user is in the Build space.
Other spaces do not render a status bar.

### Per-Space Accent Colors

Each space has a semantic accent color used for toolbar glass tinting,
rail active state, and navigator picker active icon:
- Plan: blue
- Build: green
- Review: orange
- Operate: purple
- Library: gray

### Semantic Rules

- `Toolbar` owns global scope, project/branch context, and per-space orientation.
- `Sidebar` owns navigation via the Navigator Picker and entity selection.
- `Canvas` owns the primary collection view or full-page detail route.
- `Inspector` owns secondary context and quick actions only.
- `Agent Sidebar` owns all AI interaction, contextual to the current space.
- `Utility Deck` owns persistent operational panes (Terminal, Problems, Output).
- `Status Bar` owns editor-level status (Build-only).

## Current Conflicts To Eliminate

- `Workspace` is currently overloaded across the repo.
- `Mode` implies a temporary toggle, which is the wrong mental model for persistent destinations.
- `Panel` is used too loosely for bottom utilities, inspector-like surfaces, and content regions.
- `Sidebar` is sometimes used as a content surface instead of a navigator.
- `Intent` currently mixes scope, collection browsing, and detail in ways that feel like parallel half-features.

## Final Naming Rules

- Use nouns for persistent destinations.
- Use verbs only for actions.
- Reserve `Workspace` for project/root context.
- Use `Space` for top-level shell destinations.
- Use `Canvas` for the primary center surface.
- Use `Inspector` for selection-driven secondary detail.
- Use `Utility Deck` for bottom utility surfaces.
- Use `Connection` in UI copy for provider/service relationships.
- Use `Provider` in code and architecture, not as default user-facing copy.

## Implementation Rule

Any new shell or navigation work must first map to this vocabulary before code or pixels are added.

If the app cannot name a thing clearly, the app should not ship it as a first-class shell element yet.
