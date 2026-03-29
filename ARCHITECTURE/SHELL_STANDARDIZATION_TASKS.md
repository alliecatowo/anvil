# Shell Standardization Tasks

**Status:** Draft
**Approximate Task Count:** 266
**North Star:** [`ARCHITECTURE/SHELL_VOCABULARY.md`](/Users/allie/Develop/anvil/ARCHITECTURE/SHELL_VOCABULARY.md)

This backlog is the migration plan from the current mixed shell vocabulary to the canonical shell model.

Recent completed wave on `shell-vocabulary-migration`:

- `90c56f4` `Place chat in Library and tighten shell contract`
- `f480478` `Harden app launch for UI automation`
- `7bd103f` `Continue shell contract migration`
- `6cd556a` `Refine plan/build shell labels and selectors`

That wave established the canonical shell vocabulary, moved `Chat` into Library as a toolspace, tightened the `Plan` and `Build` user-facing labels, and hardened the raw/default accessibility selectors.

The target shell model is:

- `Workspace Rail` = top-level workspace switcher
- `Sidebar` = navigation
- `Canvas` = primary content
- `Inspector` = selection-driven secondary detail
- `Utility Deck` = terminal/logs/problems/notifications
- `Toolbar` = global actions
- `Status Bar` = compact state and context

## 1. Vocabulary And Governance

- [ ] S-001 Audit all user-facing `Workspace` copy and classify it as project context or shell destination.
- [ ] S-002 Replace shell-destination `Workspace` copy with `Space` across docs.
- [ ] S-003 Reserve `Workspace` for project/repo/root context only.
- [ ] S-004 Replace user-facing `Mode` labels with canonical `Space` names where possible.
- [ ] S-005 Define a single canonical mapping table for current labels to future labels.
- [ ] S-006 Mark `ARCHITECTURE/SHELL_VOCABULARY.md` as the authoritative source in every shell doc.
- [ ] S-007 Add a short vocabulary note to `README.md`.
- [ ] S-008 Add a short vocabulary note to `CLAUDE.md`.
- [ ] S-009 Add a shell vocabulary link to `UI_IMPLEMENTATION_GOVERNANCE.md`.
- [ ] S-010 Mark historical IA reports as historical, not current truth.
- [ ] S-011 Remove contradictory shell terminology from onboarding docs.
- [ ] S-012 Standardize internal doc references to `Space`, `Workspace Rail`, `Sidebar`, `Canvas`, `Inspector`, `Utility Deck`, `Toolbar`, and `Status Bar`.
- [ ] S-013 Define one canonical noun for each top-level shell region.
- [ ] S-014 Define one canonical noun for each durable entity type.
- [ ] S-015 Define one canonical noun for each docked utility surface.

## 2. Shell Scaffold

- [ ] S-016 Replace any mode-tab style top navigation with the rail-driven space switcher.
- [ ] S-017 Ensure the rail always stays navigable when collapsed.
- [ ] S-018 Make the rail own only top-level space switching and utility anchors.
- [ ] S-019 Remove duplicate primary navigation from the titlebar.
- [ ] S-020 Keep the toolbar for global actions only.
- [ ] S-021 Keep the inspector toggle as a structural control, not a mode switch.
- [ ] S-022 Keep the utility deck separate from space navigation.
- [ ] S-023 Make the shell layout restore rail, sidebar, canvas, inspector, and utility deck state.
- [ ] S-024 Ensure no shell region silently collapses into a single ambiguous icon.
- [ ] S-025 Ensure every visible shell control maps to a real handler.
- [ ] S-026 Ensure every shell label reflects its actual purpose.
- [ ] S-027 Remove any fake nested toolbar chrome inside content surfaces.
- [ ] S-028 Keep content headers content-scoped, not global-app-scoped.
- [ ] S-029 Keep the current space highlighted even when the sidebar is collapsed.
- [ ] S-030 Add a durable breadcrumb or scope indicator if the rail alone is not enough.

## 3. Plan Workspace

- [ ] S-031 Rename the current Intent concept to `Plan` in user-facing copy.
- [ ] S-032 Keep tickets as the primary entity type in Plan.
- [ ] S-033 Make the Plan sidebar own scope, filters, and saved views.
- [ ] S-034 Remove duplicate ticket detail chrome from the Plan sidebar.
- [ ] S-035 Keep the Plan canvas as the primary ticket collection surface.
- [ ] S-036 Keep ticket detail promotable into the Plan canvas, not only the inspector.
- [ ] S-037 Keep the inspector as lightweight ticket metadata and quick actions.
- [ ] S-038 Add explicit full-page detail entry and exit in Plan.
- [ ] S-039 Ensure list and board presentations share the same selection model.
- [ ] S-040 Ensure saved filters and groups mutate the same underlying collection query.
- [ ] S-041 Add obvious empty states for unassigned, blocked, and due-soon work.
- [ ] S-042 Keep plan navigation stable when selection changes.
- [ ] S-043 Keep plan filters from hiding the only visible path to a ticket.
- [ ] S-044 Add clear affordances for opening a ticket in the main canvas.
- [ ] S-045 Ensure the Plan space works without seeded demo data.

## 4. Build Workspace

- [ ] S-046 Merge Agent and Editor semantics under the Build space.
- [ ] S-047 Keep agent sessions as a Build sidebar section, not a peer space.
- [ ] S-048 Keep files and editor tabs inside the Build canvas.
- [ ] S-049 Keep databases as a Build section when they are part of build work.
- [ ] S-050 Keep build tools discoverable from the Build sidebar.
- [ ] S-051 Keep the Build inspector focused on session/configuration state.
- [ ] S-052 Move session configuration controls into inspector or toolbar.
- [ ] S-053 Ensure switching sessions is sidebar navigation, not a global mode switch.
- [ ] S-054 Ensure file tabs behave like editor tabs, not workspace tabs.
- [ ] S-055 Ensure agent turns, diffs, and file edits share one build narrative.
- [ ] S-056 Add a clear bridge from agent output to editable files.
- [ ] S-057 Keep Build content in a stable split between session/chat and editor/file surfaces.
- [ ] S-058 Remove any duplicate agent/sidebar panels that shadow the canvas.
- [ ] S-059 Ensure build search, codebase Q&A, and command execution remain Build-adjacent utilities.
- [ ] S-060 Make Build the primary home for creating, editing, and applying agent output.
- [ ] S-061 Add explicit empty states for no sessions, no files, and no database connection.
- [ ] S-062 Make Build support both raw project mode and seeded/demo mode.
- [ ] S-063 Keep Build navigation coherent even when no agent provider is configured.
- [ ] S-064 Make Build surface editor, agent, and database as sibling sections only inside the space.

## 5. Review Workspace

- [ ] S-065 Keep Review as a first-class space name.
- [ ] S-066 Make the Review sidebar own review queues, branches, PRs, and checks.
- [ ] S-067 Keep Review selection state persistent across reloads.
- [ ] S-068 Ensure review rows are real buttons or real selection targets.
- [ ] S-069 Keep worktree reloads tied to the actual repository context.
- [ ] S-070 Keep branch, PR, and local change flows distinct but linked.
- [ ] S-071 Make review diff, file detail, and comment threads obvious in the canvas.
- [ ] S-072 Keep review inspector for metadata, quick actions, and review state.
- [ ] S-073 Add explicit “Start Review” and “Refresh” affordances where appropriate.
- [ ] S-074 Add clear empty states for no PRs, no branch diffs, and no review activity.
- [ ] S-075 Make “browse reviews” a real workflow, not a dead sidebar label.
- [ ] S-076 Ensure changes to repo/worktree context invalidate stale review data.
- [ ] S-077 Make review selection visibly obvious in both list and board views.
- [ ] S-078 Ensure review actions are consistent across sidebar, canvas, inspector, and command palette.
- [ ] S-079 Keep the review workspace useful without seeded data.

## 6. Operate Workspace

- [ ] S-080 Rename Ship semantics to `Operate` in user-facing copy.
- [ ] S-081 Keep deployments as one section of Operate, not the whole space.
- [ ] S-082 Keep environments, logs, health, alerts, and comms inside Operate.
- [ ] S-083 Keep deployment detail visible in the canvas with inspectable summary state.
- [ ] S-084 Make build logs and deployment history read as native macOS content, not web cards.
- [ ] S-085 Keep health checks and runtime status visible without extra clicks.
- [ ] S-086 Make Operate support incident-style messaging and notifications as real workflows.
- [ ] S-087 Add clear empty states for no environments and no deployments.
- [ ] S-088 Keep rollbacks and reruns explicit and truthful.
- [ ] S-089 Ensure Operate does not depend on demo-only data for its core layout.
- [ ] S-090 Make the Operate sidebar a navigational tree, not a command dump.
- [ ] S-091 Keep deployment provider information in connection/configuration surfaces, not everywhere.
- [ ] S-092 Ensure Operate works for more than one hosting provider.
- [ ] S-093 Keep the deploy dashboard and deployment detail consistent across selected items.
- [ ] S-094 Preserve selected environment and deployment state across navigation.

## 7. Library Workspace

- [ ] S-095 Make Library the durable home for docs, extensions, rules, snippets, and connection setup.
- [ ] S-096 Keep docs, rules, and references separated from operational spaces.
- [ ] S-097 Make provider connections live in Library rather than leaking into every space.
- [ ] S-098 Keep extension browsing and installation in Library.
- [ ] S-099 Make rules editable and discoverable through Library.
- [ ] S-100 Keep library search, outline, and browse flows native.
- [ ] S-101 Add clear empty states for missing libraries or disconnected providers.
- [ ] S-102 Keep document browsing and document editing separate but linked.
- [ ] S-103 Ensure library items can open in the editor/canvas when appropriate.
- [ ] S-104 Keep assets, templates, and snippets clearly grouped.
- [ ] S-105 Keep library sidebar rows strictly navigational.
- [ ] S-106 Make library-specific actions explicit in toolbar or inspector, not hidden rows.
- [ ] S-107 Ensure the library space can show provider connections without implying those providers own the whole app.
- [ ] S-108 Keep library and build from stepping on each other for files/docs.
- [ ] S-109 Make the library space useful before any provider is configured.

## 8. Utility Deck

- [ ] S-110 Make Terminal a Utility Deck pane, not a top-level space.
- [ ] S-111 Keep problems, output, logs, and terminal in the same dockable utility vocabulary.
- [ ] S-112 Ensure utility panes can be restored independently of the current space.
- [ ] S-113 Keep utility controls visible but not dominant.
- [ ] S-114 Make utility panes feel like docked tool windows, not a second app.
- [ ] S-115 Keep terminal session naming consistent across dock and sidebar entry points.
- [ ] S-116 Make utility deck visibility and focus state persistent across sessions.
- [ ] S-117 Add explicit empty states for terminal, problems, and logs when none are active.
- [ ] S-118 Keep utility deck actions available from keyboard and toolbar.
- [ ] S-119 Ensure utility deck contents do not duplicate sidebar navigation.
- [ ] S-120 Keep notifications/inbox utility-like where they are not core to the current space.

## 9. Provider And Connection Model

- [ ] S-121 Use `Provider` in code and architecture, not as default user-facing shell copy.
- [ ] S-122 Use `Connection` in UI copy for user-facing integration relationships.
- [ ] S-123 Keep provider configuration in setup and dedicated config surfaces.
- [ ] S-124 Ensure provider state is capability-driven, not brand-driven.
- [ ] S-125 Ensure every provider surface can represent unconfigured, connecting, connected, degraded, disconnected, and error states.
- [ ] S-126 Keep AI model selection distinct from provider connection selection.
- [ ] S-127 Make multi-provider coexistence visible in settings and wherever relevant.
- [ ] S-128 Keep Codex ACP, Anthropic, OpenAI, and local providers on the same abstraction level.
- [ ] S-129 Ensure no shared shell copy assumes Slack-only or Anthropic-only support.
- [ ] S-130 Make provider choice affect capabilities, not shell structure.
- [ ] S-131 Ensure provider setup flows name the missing service and the next action.
- [ ] S-132 Keep provider-specific branding out of shared navigation.
- [ ] S-133 Add provider-specific detail only where the user is configuring that provider.
- [ ] S-134 Make provider restoration part of workspace/session restoration when appropriate.
- [ ] S-135 Ensure new providers can be added without renaming shell concepts.
- [ ] S-136 Keep provider actions in the toolbar, inspector, or setup flow, not sidebar clutter.
- [ ] S-137 Make multi-provider states visible in tests and visual regression scenarios.
- [ ] S-138 Ensure provider model docs and shell vocabulary docs never disagree.
- [ ] S-139 Treat provider support as a capability contract, not a UI naming problem.
- [ ] S-140 Make connection errors actionable and local to the relevant surface.

## 10. Visual And Raw Flow Coverage

- [ ] S-141 Add raw-launch smoke coverage for every core space.
- [ ] S-142 Add deterministic seeded visual scenarios for every core space.
- [ ] S-143 Keep raw-launch smoke paths working without setup wizard detours.
- [ ] S-144 Keep seeded scenarios using `ANVIL_UITEST_SCENARIO`.
- [ ] S-145 Add stable accessibility identifiers for primary navigation controls.
- [ ] S-146 Add stable accessibility identifiers for primary canvases.
- [ ] S-147 Add stable accessibility identifiers for inspector actions.
- [ ] S-148 Add screenshot capture to every canonical visual scenario.
- [ ] S-149 Keep visual tests limited to canonical screens first, then expand.
- [ ] S-150 Make visual tests fail when a canonical heading or control is missing.
- [ ] S-151 Keep raw smoke tests proving discoverability, not only pixel shape.
- [ ] S-152 Add a visual baseline for the unseeded/default journey.
- [ ] S-153 Keep UI tests aligned with the canonical shell vocabulary.
- [ ] S-154 Ensure testing utilities can drive both seeded and raw app starts.
- [ ] S-155 Make smoke failures point at routing or accessibility, not flake.
- [ ] S-156 Keep visual evidence easy to extract from result bundles.
- [ ] S-157 Ensure tests cover workspace switching, sidebar navigation, canvas detail, and inspector toggles.
- [ ] S-158 Make duplicate accessibility labels impossible where they affect core journeys.

## 11. Deprecation And Cleanup

- [ ] S-159 Remove the `Workspaces` dropdown from the toolbar.
- [ ] S-160 Remove any global mode-tab strip that competes with the rail.
- [ ] S-161 Remove `Auxiliary` as a user-facing shell category.
- [ ] S-162 Remove `Mode` from user-facing shell terminology.
- [ ] S-163 Remove any sidebar section that exists only as placeholder chrome.
- [ ] S-164 Remove any button or row that claims an action but has no handler.
- [ ] S-165 Remove duplicate content surfaces that mirror the inspector.
- [ ] S-166 Remove fake navigation rows that do not change selection or state.
- [ ] S-167 Remove the old workspace-vocabulary conflicts from docs.
- [ ] S-168 Remove stale shell language from onboarding and setup docs.
- [ ] S-169 Remove bottom-left utility affordances if they belong in the top-right or utility deck.
- [ ] S-170 Remove the assumption that every tool surface deserves its own top-level space.
- [ ] S-171 Remove one-off chrome where shared primitives now exist.
- [ ] S-172 Remove stale task entries once the canonical vocabulary migration lands.
- [ ] S-173 Remove duplicate state ownership between sidebar, canvas, and inspector.
- [ ] S-174 Remove any layout path that depends on hidden setup-only state to function.

## 12. Final Standardization

- [ ] S-175 Make every new shell change reference `ARCHITECTURE/SHELL_VOCABULARY.md` before implementation.
- [ ] S-176 Ensure all docs that describe the shell point to the north-star vocabulary doc.
- [ ] S-177 Make the repo’s canonical UI docs agree on `Workspace Rail`, `Sidebar`, `Canvas`, `Inspector`, `Utility Deck`, `Toolbar`, and `Status Bar`.
- [ ] S-178 Make `Plan`, `Build`, `Review`, and `Ship` the only top-level user-facing workspaces.
- [ ] S-179 Keep `Intent`, `Agent`, and similar labels only as transitional/internal implementation names until removed.
- [ ] S-180 Ensure the new vocabulary is reflected in task tracking, visual tests, and onboarding.
- [ ] S-181 Update the root task registry to mirror the new shell vocabulary.
- [ ] S-182 Update shell screenshots and marketing copy to match the canonical terms.
- [ ] S-183 Make the canonical hierarchy the default mental model for future features.
- [ ] S-184 Keep new features from introducing a sixth shell layer or a parallel navigation system.
- [ ] S-185 Require new work to state which `Workspace Rail`, `Sidebar`, `Canvas`, `Inspector`, `Utility Deck`, `Toolbar`, or `Status Bar` region it belongs to.
- [ ] S-186 Keep all future provider work within the connection/capability model.
- [ ] S-187 Keep all future workspace work within the canonical shell vocabulary.
- [ ] S-188 Ensure new UI copy is reviewed against the shell vocabulary before merge.

## 13. Workspace Renaming And Legacy Aliases

- [ ] S-189 Audit every remaining user-facing `Intent` label and classify whether it should become `Plan` or an internal alias.
- [ ] S-190 Audit every remaining user-facing `Agent` label and classify whether it should become `Build` or an internal alias.
- [ ] S-191 Audit every remaining user-facing `Ship` label and classify whether it should become `Operate` or an internal alias.
- [ ] S-192 Audit every remaining user-facing `Mode` label and classify whether it should become `Space`, `Canvas`, `Inspector`, or be removed.
- [ ] S-193 Keep implementation types named for now, but separate those names from user-facing shell labels.
- [ ] S-194 Add a single label-mapping table for shell words used in code, docs, UI, tests, and screenshots.
- [ ] S-195 Ensure accessibility identifiers use stable action nouns, not legacy mode labels, when the UI is user-facing.
- [ ] S-196 Ensure command palette labels use canonical space names before legacy mode names.
- [ ] S-197 Ensure sidebar section copy uses canonical shell nouns before legacy terminology.
- [ ] S-198 Add a deprecation list for old shell words that should not appear in new docs or UI.
- [ ] S-199 Make `Plan`, `Build`, `Review`, `Operate`, and `Library` the only allowed top-level shell nouns in new copy.
- [ ] S-200 Keep `Intent`, `Agent`, `Ship`, `Auxiliary`, and `Mode` as transitional labels only until migration completes.
- [ ] S-201 Add an internal glossary for the current-to-canonical mapping in the architecture docs.
- [ ] S-202 Update screenshots, PR templates, and visual-test names to use the canonical shell nouns.
- [ ] S-203 Remove any code comment or TODO that depends on legacy shell labels to explain behavior.
- [ ] S-204 Ensure the migration notes explicitly call out when a legacy label is retained only for compatibility.

## 14. Shell Enforcement And CI Gates

- [ ] S-205 Add a shell vocabulary lint that fails on new legacy shell words in new UI docs.
- [ ] S-206 Add a shell vocabulary lint that fails on new legacy shell words in new user-facing copy.
- [ ] S-207 Add a docs check that `ARCHITECTURE/SHELL_VOCABULARY.md` is referenced by shell docs.
- [ ] S-208 Add a docs check that `ARCHITECTURE/SHELL_STANDARDIZATION_TASKS.md` is referenced by migration plans.
- [ ] S-209 Add a CI gate for stale sidebar controls that do not mutate real state.
- [ ] S-210 Add a CI gate for new controls without accessibility labels.
- [ ] S-211 Add a CI gate for duplicate visible labels on critical journey buttons.
- [ ] S-212 Add a CI gate for raw/default smoke scenarios that miss a canonical heading or primary action.
- [ ] S-213 Add a CI gate for deterministic visual scenarios seeded by `ANVIL_UITEST_SCENARIO`.
- [ ] S-214 Add a CI gate for shell-doc changes that do not update the vocabulary doc.
- [ ] S-215 Add a CI gate for provider changes that do not update the provider model doc.
- [ ] S-216 Add a CI gate for shell changes that introduce custom chrome where native primitives exist.
- [ ] S-217 Add a CI gate for any new sidebar section that is not declared in the shell vocabulary.
- [ ] S-218 Add a CI gate for any new workspace concept that is not mapped to the canonical shell model.

## 15. Migration Coverage And Visual Proof

- [ ] S-219 Add a canonical screenshot for raw Plan (list) with no seeded data.
- [ ] S-220 Add a canonical screenshot for raw Plan (board) with no seeded data.
- [ ] S-221 Add a canonical screenshot for raw Build (session list/conversation) with no seeded data.
- [ ] S-222 Add a canonical screenshot for raw Review (inbox) with no seeded data.
- [ ] S-223 Add a canonical screenshot for raw Operate (dashboard) with no seeded data.
- [ ] S-224 Add a canonical screenshot for raw Library (rules/docs) with no seeded data.
- [ ] S-225 Add a canonical screenshot for seeded Plan with a selected ticket in main-pane detail.
- [ ] S-226 Add a canonical screenshot for seeded Build with the info inspector visible.
- [ ] S-227 Add a canonical screenshot for seeded Review with a branch diff selected and a real start-review action.
- [ ] S-228 Add a canonical screenshot for seeded Operate with deployment detail visible.
- [ ] S-229 Add a canonical screenshot for seeded Library with a real rules editor path.
- [ ] S-230 Add a canonical screenshot for collapsed rail state in each core workspace.
- [ ] S-231 Add a canonical screenshot for inspector-open and inspector-closed transitions.
- [ ] S-232 Add a canonical screenshot for utility deck visible and hidden states.

## 16. Cleanup And Removal

- [ ] S-233 Remove any new shell copy that still says `mode` when `space` is the right concept.
- [ ] S-234 Remove any user-facing `panel` label that should be `inspector`, `canvas`, or `utility deck`.
- [ ] S-235 Remove duplicated navigation rows that mirror canvas content.
- [ ] S-236 Remove any fake empty state that hides a real path to content.
- [ ] S-237 Remove any feature-specific top bar that duplicates the toolbar contract.
- [ ] S-238 Remove any workspace breadcrumb that repeats the rail without adding scope.
- [ ] S-239 Remove any bottom-left utility affordance that should be in the rail, toolbar, or utility deck.
- [ ] S-240 Remove any toolbar item that is only a workaround for a broken sidebar row.
- [ ] S-241 Remove any review/agent/build control that becomes redundant after canonical shell migration.
- [ ] S-242 Remove stale helper names from docs once the canonical shell vocabulary is established.
- [ ] S-243 Remove transitional doc language that describes the old shell as if it were final.
- [ ] S-244 Remove tasks from the backlog only when both the canonical label and the canonical behavior are shipped.
- [ ] S-245 Remove legacy aliases from public screenshots and demos once the new names are ready.
- [ ] S-246 Remove remaining shell debt that would make a fresh app bootstrap feel ambiguous or split-brained.

## 18. Branch Queue

- [ ] S-257 Rerun the default raw smoke journeys and close the remaining automation-mode and routing failures.
- [ ] S-258 Rerun the visual regression suite and record the new canonical baseline for raw and seeded flows.
- [ ] S-259 Finish the visible `Intent -> Plan` rename across remaining shell chrome and docs.
- [ ] S-260 Finish the visible `Agent -> Build` rename across remaining shell chrome and docs.
- [ ] S-261 Keep `Chat` as the canonical Library toolspace label everywhere user-facing messaging copy appears.
- [ ] S-262 Remove any remaining Plan sidebar duplication so the canvas owns full ticket detail.
- [ ] S-263 Finish Review workflow polish around browse/review/start-review feedback and reload state.
- [ ] S-264 Make Build raw/default routing deterministic for sessions, files, and data surfaces.
- [ ] S-265 Add stable accessibility identifiers for the canonical raw/default smoke journeys.
- [ ] S-266 Add canonical screenshots for raw Plan, Build, Review, Operate, and Library states.

## 17. Immediate Execution Queue

- [ ] S-247 Rerun raw smoke suites to completion with fresh bundle paths and close the remaining Build and Intent failures.
- [ ] S-248 Rerun visual regression suites to completion and record the new canonical baseline.
- [ ] S-249 Rename visible workspace labels from `Intent` to `Plan` in the rail, top chrome, and docs.
- [ ] S-250 Rename visible workspace labels from `Agent` to `Build` in the rail, session chrome, and docs.
- [ ] S-251 Standardize `Chat` as the Library toolspace name in UI, docs, tests, and screenshots.
- [ ] S-252 Remove Plan sidebar duplication of ticket detail so the canvas owns the full detail route.
- [ ] S-253 Finish Review workflow polish for browse/review/start-review feedback and context reload.
- [ ] S-254 Make Build raw/default routing deterministic for new sessions, files, and data surfaces.
- [ ] S-255 Add stable accessibility identifiers for canonical raw/default journeys.
- [ ] S-256 Add canonical screenshots for raw Plan, Build, Review, Operate, and Library states.
