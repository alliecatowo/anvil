# Feature Completeness PR Checklist

Use this for any PR that adds or expands a feature.

## Truth

- [ ] The feature has a real data path.
- [ ] The feature has a real action path.
- [ ] The feature has a real empty state.
- [ ] The feature has a real loading state if needed.
- [ ] The feature has a real error state.
- [ ] The feature has a real setup state if it depends on a provider or account.
- [ ] The feature does not silently fall back to sample data unless the UI says `Demo`.
- [ ] Every visible state explains what is happening and what the user can do next.

## No Stubs

- [ ] There are no no-op buttons, rows, or menu items.
- [ ] There are no fake shortcuts.
- [ ] There are no placeholder flows presented as complete.
- [ ] There is no silent fallback to sample data unless the UI says `Demo`.
- [ ] A missing capability is shown as missing, not as fake UI.
- [ ] No sub-flow hides a stub behind another button, drawer, or inspector pane.

## State

- [ ] The state lives in the correct owner.
- [ ] Selection restores correctly or is intentionally ephemeral.
- [ ] The feature does not duplicate existing state in a second place.
- [ ] Cross-surface actions work the same in toolbar, sidebar, palette, and context menu.
- [ ] The feature does not invent a second shell for the same object or concept.

## Provider Awareness

- [ ] Provider names only appear where setup or provider detail is expected.
- [ ] The feature branches on capability, not on a brand string.
- [ ] Multiple providers can be added later without rewriting the shell.
- [ ] The current provider is persisted or restored if the feature needs it.
- [ ] Provider-specific UI is isolated from shared shell UI.
- [ ] The feature still reads correctly when more than one provider exists.

## Verification

- [ ] The truth matrix was updated.
- [ ] The relevant architecture doc was updated.
- [ ] The code builds.
- [ ] The feature can be demonstrated end to end without explanation of hidden behavior.
- [ ] The PR reviewer can click through every visible affordance without finding an inert surface.
