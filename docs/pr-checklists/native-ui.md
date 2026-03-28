# Native UI PR Checklist

Use this for any PR that changes UI, navigation, commands, or interaction structure.

## Shell

- [ ] The new surface uses a native primitive before a custom replacement.
- [ ] `NavigationSplitView`, `List(selection:)`, `Table`, `Toolbar`, `Inspector`, `Form`, `Menu`, `popover`, `sheet`, or `confirmationDialog` was preferred where appropriate.
- [ ] The collapsed state still preserves meaning and navigation.
- [ ] The toolbar owns global actions instead of an extra custom top bar.
- [ ] The inspector owns secondary controls instead of a custom right rail.
- [ ] Sidebar sections are meaningful and named by concept, not implementation.
- [ ] Collapsed sidebar sections remain understandable through icons, grouping, badges, or tooltips.

## Interaction Truth

- [ ] Every visible control has a real handler.
- [ ] Every displayed shortcut is wired.
- [ ] No row or button looks clickable if it is inert.
- [ ] No command palette item is a placeholder.
- [ ] Any disabled action explains what is missing.
- [ ] Any stale shortcut label was removed or corrected.
- [ ] Any changed label appears in `TRUTH_MATRIX.md`.

## Layout

- [ ] The hierarchy is clear: workspace, source, object, operation, history, utility.
- [ ] The empty state is honest.
- [ ] The setup state is honest.
- [ ] Demo content is labeled `Demo` if it exists.
- [ ] The UI does not create duplicate navigation for the same concept.
- [ ] The UI does not split the same concept across two different sidebars or two different chrome systems.

## Accessibility

- [ ] Focus order is sensible.
- [ ] Keyboard navigation works end to end.
- [ ] VoiceOver labels make sense.
- [ ] The UI remains usable with the sidebar collapsed.

## Docs

- [ ] `TRUTH_MATRIX.md` was updated.
- [ ] `ARCHITECTURE/UX_SHELL.md` was updated if the shell changed.
- [ ] `ARCHITECTURE/PROVIDER_MODEL.md` was updated if provider behavior changed.
- [ ] `README.md` was updated if the workflow changed.
- [ ] `UI_IMPLEMENTATION_GOVERNANCE.md` was updated if rules changed.
