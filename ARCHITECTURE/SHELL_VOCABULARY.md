# Shell Vocabulary North Star

**Status:** Canonical
**Scope:** Shell hierarchy, top-level naming, workspace labels, pane vocabulary, and user-facing grouping.

This document is the ground truth for how Anvil names its structural concepts.
If another doc disagrees with this one, this one wins.

## Direct Answer

`Intent`, `Agent`, `Review`, `Ship`, `Editor`, `Database`, `Terminal`, `Docs`, `Chat`, `Notifications`, `Testing`, and `Extensions` do **not** all make sense as peer "workspaces" in the final product vocabulary.

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

### Why `Ship` Should Become `Operate`

`Ship` is too narrow. It describes deployment, but Anvil's actual operating surface includes:

- deployments
- environments
- logs
- alerts
- incidents
- operational messaging

`Operate` is the broader and more durable category.

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
└── Space
    ├── Sidebar
    │   └── Sections
    │       └── Items
    ├── Canvas
    │   └── Views / detail routes
    ├── Inspector
    │   └── selection-driven metadata and quick actions
    └── Utility Deck
        └── Terminal / logs / problems / notifications / background tasks
```

### Semantic Rules

- `Sidebar` owns navigation, scope, saved views, and entity selection.
- `Canvas` owns the primary collection view or full-page detail route.
- `Inspector` owns secondary context and quick actions only.
- `Utility Deck` owns transient operational panes.
- `Toolbar` owns global scope and app-level actions.
- `Status Bar` owns persistent low-level status.

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
