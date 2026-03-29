# North Star Shell

This document is the canonical shell model for Anvil.
If a visible UI surface, workspace, or navigation concept conflicts with this file, this file wins.

## Decision

Anvil should use a small, stable shell vocabulary:

- `Workspace Rail`
- `Sidebar`
- `Canvas`
- `Inspector`
- `Utility Deck`
- `Toolbar`
- `Status Bar`

The shell should describe containment and responsibility, not implementation details.
Workspace names should describe user outcomes, not internal code history.

## Recommendation On Workspace Names

`Intent` and `Agent` do not make sense as long-term user-facing workspace nouns.
They are useful internal labels, but they are too implementation-shaped to be the shell's north-star vocabulary.

Use these user-facing workspaces instead:

- `Plan`
- `Build`
- `Review`
- `Ship`

Keep `Intent` and `Agent` as internal identifiers until the migration is complete.
`Review` and `Ship` already work well as workspace names and should remain first-class.

## Shell Model

### Workspace Rail

The leftmost rail switches top-level workspaces.
It may collapse, but it must remain navigable and legible.

The rail answers: "Where am I working?"

### Sidebar

The sidebar owns navigation for the selected workspace.
It contains scopes, saved filters, sources, and entity collections.
It does not own the main artifact itself.

The sidebar answers: "Which collection, source, or filter am I looking at?"

### Canvas

The canvas is the primary working surface in the center.
It shows the active collection view or the full-page detail route.

The canvas answers: "What am I working on right now?"

### Inspector

The inspector is secondary context and quick actions for the focused object.
It is not the only place where an entity can be opened or edited.

The inspector answers: "What do I need to know or tweak about the current thing?"

### Utility Deck

The utility deck contains docked transient tools such as terminal, logs, notifications, problems, and similar surfaces.
It is not a fake app chrome layer and it is not primary navigation.

The utility deck answers: "What supporting tool do I need right now?"

### Toolbar

The toolbar owns global actions: search, provider switching, project switching, create/open commands, inspector toggles, and other app-wide controls.

The toolbar answers: "What global action is available right now?"

### Status Bar

The status bar owns compact state: branch, sync, selection context, task status, encoding, line/column, provider health, and other always-available indicators.

The status bar answers: "What is the app's current state?"

## Canonical Mapping

The current codebase still uses some legacy identifiers. This is the current mapping:

- `Intent` -> `Plan`
- `Agent` -> `Build`
- `Review` -> `Review`
- `Ship` -> `Ship`
- `Editor` -> `Editor`
- `Database` -> `Database`
- `Terminal` -> `Terminal`
- `Docs` -> `Docs`
- `Messaging` -> `Messaging`
- `Notifications` -> `Notifications`
- `Testing` -> `Testing`
- `Extensions` -> `Extensions`

Legacy names may remain in code until the migration is complete, but shared shell copy should prefer the canonical names above.

## What Counts As A First-Class Workspace

A first-class workspace must satisfy all of these:

- It has a stable place on the workspace rail.
- It has a meaningful sidebar model.
- It can be restored directly.
- It owns a real canvas or detail route.
- It has a clear empty/setup state.
- It does not depend on hidden controls to become discoverable.

By that definition:

- `Plan`, `Build`, `Review`, and `Ship` are first-class workspaces.
- `Editor`, `Database`, `Terminal`, `Docs`, `Messaging`, `Notifications`, `Testing`, and `Extensions` are first-class destinations or toolspaces, but not peer product phases.

## Structural Rules

- Sidebar rows must select real content.
- Sidebar filters must change the canvas query, not duplicate the canvas.
- A ticket, PR, session, file, or deployment may open from a sidebar, but the canvas must remain the source of truth for full-page detail.
- Inspector state must never be the only path to important detail.
- Utility surfaces should stay docked and explicit.
- A collapsed sidebar must still be a navigable rail, not a single anonymous icon.
- Provider names should appear in setup and provider detail only, unless the workspace truly depends on that provider.

## How This Fits Other IDEs

Anvil should read like the best parts of the major IDEs, not like a web app with docked panels:

- Xcode: navigator, editor, inspector, toolbar
- VS Code: activity bar, side bar, editor, panel, status bar
- JetBrains IDEs: tool window bars, editor, status bar, tool windows

Those products use nouns for containment and keep navigation separate from the main work surface.
Anvil should do the same.

## Source References

- [Shell contract](./UX_SHELL.md)
- [Architecture overview](./OVERVIEW.md)
- [Provider model](./PROVIDER_MODEL.md)
- [VS Code user interface](https://code.visualstudio.com/docs/getstarted/userinterface)
- [JetBrains IDE toolbar and tool window docs](https://www.jetbrains.com/help/idea/customize-actions-menus-and-toolbars.html)
