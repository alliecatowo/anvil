# Truth Matrix

This is the anti-stub ledger for the whole app.
If an affordance can be clicked, selected, typed into, dismissed, or restored, it belongs here.
If it is not in this matrix, it should not ship.

This file is the merge gate for visible interaction truth.
If a PR changes a visible control, shortcut, label, command, row, or state transition and does not update this file, the PR is incomplete.

Status values:
- `real`
- `demo`
- `disabled`
- `placeholder`
- `removed`

## Required Columns

| Surface | Label | Shortcut | Command ID | Real Handler | Source File | Status |
|---|---|---|---|---|---|---|

## Rules

- Record toolbar items, sidebar items, status items, command palette items, inspector actions, menu commands, context menus, and keyboard shortcuts.
- Update this file in the same PR whenever labels, commands, shortcuts, provider names, or navigation change.
- Use `placeholder` only for surfaces that are visible but explicitly not yet available, and do not leave them visible longer than necessary.
- Use `demo` only when the UI clearly says Demo and the behavior is intentionally simulated.
- Never leave a visible affordance out of this matrix.
- Remove rows when the surface is removed.
- Mark rows `disabled` only when the UI explains why.
- Do not invent shortcut labels in docs or tooltips unless the command exists.

## Maintenance

- Each row should identify one real source of truth in code.
- A row is incomplete until the handler exists, the source file is known, and the status is honest.
- If a user-facing row becomes inert, mark it `disabled` or `removed` immediately.
- If there is more than one plausible owner for a row, the architecture is wrong and the docs need a shell or provider fix.
