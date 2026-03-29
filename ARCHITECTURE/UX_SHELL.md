# UX Shell

Canonical shell vocabulary lives in [`ARCHITECTURE/SHELL_VOCABULARY.md`](/Users/allie/Develop/anvil/ARCHITECTURE/SHELL_VOCABULARY.md). This document defines the shell contract that implements that vocabulary.

This document defines the shell contract for the entire app.
The shell is the outer structure that holds spaces, sources, detail panes, utilities, and provider setup.

## Core Pattern

- Root the app in `NavigationSplitView`.
- Use a leading rail for workspace and source navigation.
- Use a content column for the selected collection or list.
- Use a trailing detail column for the active workspace, inspector, or editor.
- Keep utility panes docked, not floating as fake app chrome.
- Keep shell responsibilities separate: navigation in the sidebar, commands in the toolbar, details in the inspector, and work in the content/detail areas.

## Hierarchy Model

Use these layers consistently:

1. `Spaces`
- User-facing destinations such as Plan, Build, Review, Operate, and Library.

Note:
- `Intent` and `Agent` are current implementation names and transitional labels, not the canonical user-facing shell vocabulary.

2. `Sources`
- Collections inside a workspace, such as projects, sessions, tickets, PRs, channels, environments, tables, runs, docs, or plugins.

3. `Objects`
- The selected entity, such as a ticket, session, PR, deploy, file, table, test, channel, notification, or plugin.

4. `Operations`
- Real actions that mutate or query the selected object.

5. `History`
- Recent items, runs, logs, command history, query history, or prior selections.

6. `Utilities`
- Search, settings, project switcher, command palette, terminal, and other transient surfaces.

7. `Providers`
- Setup, connection, and capability configuration.

## Space Sidebar Templates

Every workspace should expose useful sidebar sections, even when collapsed. The exact sections vary by workspace, but the pattern should stay legible.

Recommended templates:

- `Plan`: `Projects`, `Boards`, `Sprints`, `Tickets`, `Filters`, `History`, `Utilities`
- `Build`: `Sessions`, `Plans`, `Runs`, `Memory`, `Tools`, `History`, `Utilities`
- `Review`: `Repositories`, `Pull Requests`, `Files`, `Checks`, `Comments`, `History`, `Utilities`
- `Operate`: `Environments`, `Deployments`, `Services`, `Variables`, `Logs`, `History`, `Providers`
- `Library`: `Libraries`, `Documents`, `Chat`, `Rules`, `History`, `Utilities`, `Extensions`
- `Editor`: `Files`, `Symbols`, `Problems`, `Search`, `History`, `Utilities`
- `Database`: `Connections`, `Schemas`, `Tables`, `Queries`, `History`, `Export`, `Providers`
- `Terminal`: `Sessions`, `Splits`, `Profiles`, `History`, `Actions`
- `Docs`: `Libraries`, `Documents`, `Outline`, `History`, `Utilities`
- `Chat`: `Channels`, `Threads`, `DMs`, `History`, `Inspector`, `Utilities`
- `Notifications`: `Sources`, `Filters`, `Inbox`, `History`, `Inspector`, `Utilities`
- `Extensions`: `Categories`, `Installed`, `Updates`, `History`, `Utilities`

Do not force every workspace to use every section. Do require the sections that are meaningful for that workspace.

## Collapsed Sidebar Rule

- Collapsing the sidebar must not reduce the app to one icon.
- The collapsed state should remain a navigable icon rail with section structure, tooltips, and badges where appropriate.
- Hidden labels may collapse, but meaning must not collapse.
- The user must still be able to reach all important workspaces and key sources from the collapsed state.
- Use grouped glyphs for sections when the sidebar is collapsed so the user can still tell where navigation, history, utilities, and providers live.

## Native Shell Ownership

- The toolbar owns global actions like search, new item, project switching, provider switching, and inspector toggles.
- The sidebar owns navigation, not actions that only make sense in the current detail pane.
- The inspector owns metadata, configuration, and secondary controls.
- The detail pane owns the main editable or interactive surface.

## Interaction Naming

- Use nouns for navigation.
- Use verbs for actions.
- Use section names that explain the concept, not the implementation.

Good section names:

- `Spaces`
- `Projects`
- `Sources`
- `Objects`
- `History`
- `Runs`
- `Connections`
- `Environments`
- `Diagnostics`
- `Utilities`

Avoid sections that are just a mirror of internal code or a grab bag of every possible control.

## Reference Patterns

- Xcode: navigator/content/inspector with toolbar-owned global actions.
- JetBrains IDEs: tool window bars, compact icon rails, and named tool windows that remain legible when collapsed.
- Raycast: keyboard-first global actions with a strong distinction between launcher and workspace.

## Shell Rules

- A sidebar row that appears selectable must select real content.
- A toolbar item that appears available must execute a real command.
- A workspace that appears empty must say why it is empty and what unblocks it.
- If a section only contains placeholders, it should not be shown as primary navigation.
- If a workspace has both source navigation and object navigation, keep them visually separate.
- If a surface is only a command launcher, do not present it as primary navigation.

## Restoration

- Sidebar collapse, selected workspace, selected source, selected object, and inspector state should restore when that improves continuity.
- Restoration should not resurrect stale or invalid provider state without a clear fallback.
