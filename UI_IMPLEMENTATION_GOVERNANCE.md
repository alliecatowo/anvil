# UI Implementation Governance

This document governs every UI and interaction change in Anvil.
If a change touches a visible control, a keyboard shortcut, a sidebar row, a command, an overlay, or a state transition, it is in scope.

## Non-Negotiables

- No stubs.
- No fake affordances.
- No duplicated state ownership.
- No provider lock-in in shared shells.
- No feature work that deepens shell debt.
- No custom chrome where a native macOS primitive already exists.
- No visible control without a real handler.
- No shortcut label without a real command.
- No workspace sidebar that collapses into a single ambiguous icon.
- No shared sidebar surface may depend on one-off per-mode chrome when a reusable section/row primitive can express the same concept.

## Required Layering

- `Domain` defines primitives, value objects, and capability contracts.
- `Application` defines workflows, orchestration, and policy.
- `Infrastructure` implements provider adapters and persistence.
- `UI` binds application state to native macOS controls.

## Surface Scope

This policy covers every user-facing surface:

- toolbar items
- sidebar rows
- collapsed rail items
- command palette rows
- menu commands
- inspector controls
- empty states
- overlays
- sheets and popovers
- context menus
- keyboard shortcuts
- status items
- search and filter surfaces
- docked utility panes

## Shell First

- If a feature needs navigation, selection, search, history, inspector content, or provider setup, the shell contract must be implemented first or in the same PR.
- Feature work may not add a new custom top bar, fake segmented header, or embedded navigation surface to avoid dealing with shell structure.
- If the app needs a new concept in a sidebar, the concept model must be defined before the pixels.
- If the shell cannot represent the concept cleanly, the concept needs a shell design pass before feature work continues.
- If the app changes the shell vocabulary or workspace hierarchy, [`ARCHITECTURE/SHELL_VOCABULARY.md`](ARCHITECTURE/SHELL_VOCABULARY.md) must be updated in the same change.
- New shell concepts must match [`ARCHITECTURE/SHELL_VOCABULARY.md`](ARCHITECTURE/SHELL_VOCABULARY.md) before they are implemented or renamed in UI.

## Interaction Truth

- Every visible control must map to a real handler recorded in `TRUTH_MATRIX.md`.
- Every displayed shortcut must resolve to a real command or be removed.
- Every command palette item must execute a real handler.
- A control may be disabled only when the UI says why it is disabled and what unblocks it.
- No row may look clickable if it is not actionable.
- No status text may claim support that the code path does not implement.
- No provider field may be shown in shared UI unless the current workspace truly depends on that provider.

## Native Primitive Preference

Prefer these primitives first:

- `NavigationSplitView`
- `List(selection:)`
- `Table`
- `Toolbar`
- `Inspector`
- `Form`
- `Menu`
- `confirmationDialog`
- `popover`
- `sheet`
- `ContentUnavailableView`

Custom UI is allowed only when the native primitive cannot express the interaction clearly.

## Honest States

- Loading, empty, setup-required, error, offline, and demo states must be explicit.
- No sample fallback may ship in a production workflow unless it is clearly labeled `Demo`.
- Setup-required states must name the missing dependency and the next action.
- Empty states must distinguish between "nothing exists yet" and "nothing is connected yet."

## Whole-App Truth

- The same action must behave the same way in the toolbar, sidebar, command palette, keyboard shortcut, and context menu.
- Project, session, provider, and navigation state must have one owner.
- If a surface says something can happen, it must be possible right now in code.
- If a surface cannot be made real yet, the surface must not be presented as available.
- If the app needs a new affordance, the affordance must be added to `TRUTH_MATRIX.md` in the same change.
- If the app needs a new shell concept, `ARCHITECTURE/SHELL_VOCABULARY.md` must be updated in the same change.
- If the app needs a new provider capability, `ARCHITECTURE/PROVIDER_MODEL.md` must be updated in the same change.
- If the app adds or changes deterministic visual regression scenarios, they must be driven by `ANVIL_UITEST_SCENARIO` and the scenario names must stay aligned with the seeded screen model.

## Review Gate

Before merge, verify:

- `TRUTH_MATRIX.md` was updated for any user-facing affordance change.
- `ARCHITECTURE/SHELL_VOCABULARY.md` and `ARCHITECTURE/UX_SHELL.md` were updated for any navigation or shell change.
- `ARCHITECTURE/PROVIDER_MODEL.md` was updated for any provider or capability change.
- `docs/pr-checklists/native-ui.md` was completed for any UI change.
- `docs/pr-checklists/feature-completeness.md` was completed for any feature change.
- Visual regression coverage must seed the app through `ANVIL_UITEST_SCENARIO` or an equivalent deterministic launch contract; it may not depend on manual menu-click setup.
