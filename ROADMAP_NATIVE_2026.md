# Anvil Native Roadmap 2026

Last updated: 2026-03-27

This is the canonical execution roadmap and status source of truth.
It supersedes stale completion claims in older audit/task docs.

Execution rule:
- Shell and UI structure land before or with feature breadth.
- Any new visible affordance must be recorded in `TRUTH_MATRIX.md`.
- Any new provider capability must be described in `ARCHITECTURE/PROVIDER_MODEL.md`.
- Any shell or navigation change must be reflected in `ARCHITECTURE/UX_SHELL.md`.
- Feature PRs do not get to introduce custom chrome to avoid shell work.

## Principles
- Native-first macOS UX: `NavigationSplitView`, `List(selection:)`, `Table`, `Toolbar`, `Inspector`, `Form`.
- No fake affordances: no clickable rows that do nothing.
- One command truth: menu, palette, shortcuts, help text all backed by the same action graph.
- One state truth: project/session/navigation state must not be duplicated.
- One shell truth: the same workspace must not have both a native shell path and a parallel custom chrome path.
- One provider truth: shared surfaces speak in capabilities, not provider brands.

## 100-Task Execution Backlog

### Phase 1: Shell Integrity (1-10)
Shell/UI track: highest priority. No feature expansion before shell truth.
1. Replace fake in-content mode chrome with toolbar-driven mode navigation.
2. Introduce `ShellDestination` model for all page-level navigation.
3. Refactor main shell to `NavigationSplitView`.
4. Replace collapsed sidebar single-icon mode with icon rail navigation.
5. Remove all no-op sidebar rows or mark unavailable.
6. Build unified command registry used by menu + palette + shortcuts.
7. Remove dead shortcut labels not wired to real actions.
8. Move project selector and branch context into toolbar.
9. Unify terminal docked/full presentations under one model.
10. Add shell state restoration (sidebar, inspector, destination, terminal layout).

### Phase 2: Truthful UX and Input Model (11-20)
Shell/UI track: command, shortcut, and presentation honesty.
11. Unify project-open state to one controller shared by `AppState` and container.
12. Remove sentinel file-open path hacks and use real file palette actions.
13. Audit command palette for placeholder commands and replace/remove all.
14. Ensure every sidebar shortcut hint maps to an actual command.
15. Remove unreachable bare-key bindings from surfaced keymaps.
16. Add command validity checks in CI (fail build on dead command IDs).
17. Add navigation validity checks in CI (fail build on no-op nav rows).
18. Replace ad hoc overlay stack with typed presentation coordinator.
19. Convert status bar to contextual mode-driven items.
20. Add telemetry for dead-end clicks and command failures.

### Phase 3: Intent Native Rebuild (21-30)
Feature track: intent UX must use the shell contract above, not parallel chrome.
21. Convert Intent shell to sidebar/content/detail split architecture.
22. Replace ticket list renderer with native macOS `Table`.
23. Move ticket metadata editing to inspector.
24. Consolidate filters to one shared filter model.
25. Add saved filter views (Mine, Blocked, Due Soon, Sprint).
26. Add multi-select bulk edit actions.
27. Add WIP limits and overflow indicators for board columns.
28. Add durable ticket persistence (no init demo seeding by default).
29. Add explicit demo dataset toggle separate from real data mode.
30. Add activity timeline that persists and links to related entities.

### Phase 4: Agent Native Rebuild (31-40)
Feature track: agent UX must share the same shell and command model.
31. Convert Agent sidebar to native source list selection model.
32. Split Agent view into conversation + inspector architecture.
33. Move session config (model/autonomy/budget/guardrails) into inspector.
34. Reduce conversation header to essential actions only.
35. Rebuild session dashboard as sortable table/list hybrid.
36. Add grouped/filtered session views (running, done, critiqued, linked).
37. Persist synthesis/critique artifacts in durable model.
38. Add explicit provider setup vs empty-session states.
39. Standardize agent toolbar actions with command registry.
40. Add reliable session deep-link routing from notifications/review/intent.

### Phase 5: Review Native Rebuild (41-50)
Feature track: review UX must own honest diff, navigation, and command surfaces.
41. Split Review into explicit sources: local, GitHub PRs, inbox.
42. Rebuild review sidebar as source list + repository scope picker.
43. Remove sample git graph fallback and use honest empty/setup states.
44. Add file/thread navigator for PR reviews.
45. Unify local and GitHub comment thread models.
46. Persist hunk decisions and comment drafts across view switches.
47. Promote merge/update/check actions to always-visible toolbar.
48. Replace fake keyboard hints with wired command actions.
49. Add review detail inspector (checks, owners, linked tickets, CI status).
50. Add review workspace state restoration per PR/review session.

### Phase 6: Ship Native Rebuild (51-60)
Feature track: provider-driven workflows must stay provider-agnostic in shared shells.
51. Separate Ship demo mode from real provider mode explicitly.
52. Add provider connection/setup workflow with clear status.
53. Convert Ship shell to native sidebar/content/detail layout.
54. Replace custom tab strip with toolbar segmented control.
55. Rebuild environment/deploy list as native source list with context menu.
56. Replace faux console logs with searchable structured log view.
57. Add deployment detail pane (checks, logs, artifacts, rollback path).
58. Add health check drilldown and refresh controls.
59. Rebuild env var manager as list + detail inspector.
60. Add env var audit history and change attribution.

### Phase 7: Editor + Database Core (61-70)
Feature track: editor and database need separate shell definitions, not shared placeholder chrome.
61. Rebuild Editor shell on native split/sidebar/inspector primitives.
62. Replace manual file tree with hierarchical `List(children:)`.
63. Add file context menu operations (new/rename/delete/reveal/copy path).
64. Replace custom editor tab chrome with native-feeling tab model.
65. Separate editor document model from pane model for robust splits.
66. Add durable dirty-buffer and save/save-all/revert flows.
67. Move symbol outline to inspector-driven presentation.
68. Rebuild Database mode as source list + query workspace + detail.
69. Replace fake results grid with native `Table` or `NSTableView`.
70. Add multi-query tabs, history, schema search, and export flows.

### Phase 8: Terminal + Testing Core (71-80)
Feature track: terminal and testing must unify docked and full-window behaviors.
71. Unify terminal bottom panel and full mode with one presenter.
72. Add explicit terminal split model (orientation, active pane, close/merge).
73. Add terminal context menus and standard edit actions.
74. Add session metadata (cwd, exit code, running state, rename/restart).
75. Add command history browser/re-run UI.
76. Add terminal layout/session persistence per project.
77. Rebuild Testing mode around durable run model.
78. Improve parser coverage for XCTest and Swift Testing outputs.
79. Add package/target/suite/case scoped runs and run history.
80. Add test log pane and click-through failure navigation to editor.

### Phase 9: Docs + Messaging + Notifications + Extensions (81-90)
Feature track: each auxiliary workspace needs real sections, not one undecorated list.
81. Rebuild Docs as native doc browser/editor/inspector workflow.
82. Fix docs model identity/content separation and add search/outline.
83. Add doc file operations (create/rename/move/delete) with error handling.
84. Rebuild Messaging with source list, transcript, thread/detail inspectors.
85. Add messaging service abstraction and durable draft/message state.
86. Rebuild Notifications as list/detail triage workflow.
87. Add snooze/archive/grouping and sync-state/error visibility.
88. Rebuild Extensions as category sidebar + list/detail settings.
89. Add persistent extension registry with install/update/failure states.
90. Add permissions/capabilities + dependency/conflict handling for plugins.

### Phase 10: Quality Gates + Docs Governance (91-100)
Governance track: docs, matrix, and automated checks become release gates.
91. Add UX lint checks for no-op actions and dead command references.
92. Add snapshot/regression tests for shell layout and mode transitions.
93. Add keyboard/command integration tests for all surfaced shortcuts.
94. Add persistence tests for project/session/layout restoration.
95. Add `Truth Matrix` doc mapping UI affordances to real handlers.
96. Add docs ownership table and update cadence policy.
97. Add `staleness banner` policy for generated audit docs.
98. Add release checklist requiring docs + command map sync before merge.
99. Add roadmap progress board (task state + links to PRs/issues).
100. Add weekly architecture review note to keep native direction consistent.

## Current Tranche (In Progress)
- Tranche A quick wins:
- Remove misleading no-op auxiliary sidebar actions.
- Remove inaccurate shortcut hints.
- Unify immediate terminal action behavior.
- Refresh canonical roadmap/docs ownership.
