# Mac Native UI Direction

This document defines the UI direction for Anvil as a real macOS app, not a web app in a window.
It is a rulebook. If a PR violates these rules, the PR is wrong even if the mockup looks polished.

## Enforcement Rules

- Visible controls must have real handlers.
- Visible shortcut labels must map to real commands.
- Clickable rows must not be inert.
- Shared shell UI must describe capabilities, not provider brands.
- The collapsed sidebar must remain a grouped icon rail, not collapse into one ambiguous icon.
- Demo content must be labeled `Demo`.
- If the code path cannot do the thing, the UI must not claim that it can.

## Canonical Shell Vocabulary

Use these names consistently across docs, code, and UI.

- `Workspaces`: top-level app areas such as Intent, Agent, Review, Ship, Editor, Database, Terminal, Docs, Messaging, Notifications, Extensions.
- `Sources`: collections inside a workspace, such as projects, sessions, repositories, environments, databases, channels, or filters.
- `Objects`: the selected entity, such as a ticket, PR, file, session, deployment, query, thread, or notification.
- `Operations`: actions that mutate or query the selected object.
- `History`: previous selections, runs, searches, logs, or command history.
- `Utilities`: transient surfaces such as search, settings, palette, terminal, and switchers.
- `Providers`: setup, connection, and capability configuration for external integrations.

## Sidebar Hierarchy

Every workspace sidebar should have meaningful sections, not one mixed list of everything.

Use this pattern where it fits:

- `Overview`
- `Sources`
- `Objects`
- `Operations`
- `History`
- `Utilities`
- `Providers`

Recommended workspace section sets:

- Intent: `Projects`, `Boards`, `Sprints`, `Tickets`, `Filters`, `History`
- Agent: `Sessions`, `Plans`, `Runs`, `Memory`, `Tools`, `History`
- Review: `Repositories`, `Pull Requests`, `Files`, `Checks`, `Comments`, `History`
- Ship: `Environments`, `Deployments`, `Services`, `Variables`, `Logs`, `Providers`
- Editor: `Files`, `Symbols`, `Problems`, `Search`, `History`
- Database: `Connections`, `Schemas`, `Tables`, `Queries`, `Export`, `Providers`
- Terminal: `Sessions`, `Splits`, `Profiles`, `History`, `Actions`
- Docs: `Libraries`, `Documents`, `Outline`, `History`, `Utilities`
- Messaging: `Workspaces`, `Channels`, `Threads`, `DMs`, `History`
- Notifications: `Sources`, `Filters`, `Inbox`, `History`, `Utilities`
- Extensions: `Categories`, `Installed`, `Updates`, `History`, `Utilities`

Do not force every section into every workspace. Do require the sections that are meaningful for that workspace.

## Native Surface Rules

Prefer native macOS primitives first:

- `NavigationSplitView`
- `List(selection:)`
- `Table`
- `Toolbar`
- `Inspector`
- `Form`
- `Menu`
- `popover`
- `sheet`
- `confirmationDialog`
- `ContentUnavailableView`

Use custom chrome only when a system primitive cannot express the interaction clearly.

Rules for shell layout:

- Navigation lives in the sidebar.
- Primary commands live in the toolbar.
- Metadata and secondary configuration live in the inspector.
- The main work surface lives in the content or detail column.
- Utility surfaces stay docked or transient, not as fake app chrome.

## Collapsed Sidebar

The collapsed sidebar should still make the app legible.

- Keep the collapsed state as a structured icon rail.
- Preserve section meaning through icons, badges, and tooltips.
- Separate navigation, history, utilities, and provider setup where those groups exist.
- If collapsing destroys orientation, the design is wrong.

## Reference Patterns

Use these products as design references:

- Apple SwiftUI and macOS docs for native split views, inspectors, lists, and toolbars.
- Xcode for navigator/content/inspector structure and unified toolbar behavior.
- JetBrains IDEs for dense tool-window layouts and compact rail navigation.
- Raycast for a focused launcher that stays separate from the main shell.

The point is not to copy any one product. The point is to combine their best structural ideas into one app that still feels like a Mac app.

## Anti-Patterns

Do not ship these patterns:

- Custom top bars that duplicate the toolbar.
- Fake segmented headers that act like a second navigator.
- Provider names in shared shell labels when the user is not in provider setup.
- Single-icon collapse states that hide all meaning.
- Clickable rows that do nothing.
- Shortcut hints that do not map to commands.
- Sample data without an explicit `Demo` label.
- A second sidebar or second shell for the same concept.

## Decision Rule

When in doubt, ask:

1. Is there a native macOS primitive that already solves this?
2. Can the action live in the toolbar, sidebar, or inspector instead of a custom chrome layer?
3. Does the label describe the user-facing concept, not the code structure?
4. If collapsed, is the UI still understandable?

If the answer to any of these is no, the design needs another pass before implementation.
