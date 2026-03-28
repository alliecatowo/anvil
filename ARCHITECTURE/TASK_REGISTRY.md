# Anvil Task Registry

Last updated: 2026-03-28

This is the master catalog of all work needed to make Anvil a world-class agent-native macOS IDE. Tasks are organized by category. Each task has a one-line description and a priority.

Priority definitions:
- **P0** — Blocks basic credibility. Developers cannot adopt Anvil without this. Ship in days.
- **P1** — Core differentiator or competitive parity. Ship in weeks.
- **P2** — Quality, depth, and completeness. Ship in months.

This registry is additive — completed tasks from `TASKS.md` are not re-listed. This is what remains to be built.

---

## Terminal

| # | Task | Description | Priority |
|---|---|---|---|
| T-01 | Real PTY terminal via SwiftTerm | Replace fake terminal UI with a real PTY using SwiftTerm or libssh2. Zsh shell integration, input/output, resize, ANSI escape codes. | P0 |
| T-02 | Multiple terminal tabs | Tab bar for terminal sessions, Cmd+T new tab, Cmd+W close, Cmd+Shift+[ / Cmd+Shift+] to switch. | P1 |
| T-03 | Terminal split panes | Horizontal and vertical terminal splits, each with its own PTY session. | P1 |
| T-04 | Terminal profiles | Named profiles with custom shell, working directory, env vars, font, and color scheme. | P1 |
| T-05 | Command history browser | Ctrl+R history search with fuzzy matching. Separate command history browser panel with timestamps and rerun. | P1 |
| T-06 | AI command suggestions in terminal | Type `?` prefix for inline AI-powered command suggestions based on current task context. | P1 |
| T-07 | Terminal context as agent input | Last N terminal commands and output automatically available as implicit context in agent sessions. No copy-paste required. | P1 |
| T-08 | Link detection in terminal output | Detect URLs, file paths, and error references in terminal output. Clickable URLs open browser. File paths open in editor. | P1 |
| T-09 | Terminal session metadata | Track CWD, exit code, running state per session. Surface in sidebar and status bar. Allow rename and restart. | P1 |
| T-10 | Terminal layout persistence | Restore terminal tab layout, splits, working directories, and active session per project across restarts. | P1 |
| T-11 | Terminal color themes | Apply editor color theme to terminal. Support additional terminal-specific themes (Solarized, Dracula, etc.). | P2 |
| T-12 | Terminal + editor side-by-side | Pin a terminal pane alongside the editor split without entering full terminal mode. | P2 |
| T-13 | Per-terminal env var management | Set and override environment variables per terminal session from a UI without editing shell profiles. | P2 |
| T-14 | Terminal resize with proper reflow | Handle window resize and pane resize with correct terminal reflow, no garbled output. | P1 |
| T-15 | Copy/paste with proper selection | Text selection via click/drag in terminal, copy with Cmd+C, paste with Cmd+V, correct escape handling. | P0 |
| T-16 | Kill and restart terminal | Kill running process, restart session, and clear terminal from the toolbar or context menu. | P1 |
| T-17 | Terminal context menu | Right-click in terminal: Copy, Paste, Clear, Select All, Open in Finder (for paths), Open in Editor (for file paths). | P1 |
| T-18 | Docked terminal + full terminal unification | The terminal bottom panel and the Terminal workspace must share one presenter model, not two separate implementations. | P1 |

---

## Editor

| # | Task | Description | Priority |
|---|---|---|---|
| E-01 | LSP client — autocomplete | Implement LSP textDocument/completion. Surface completions as a native popup list. Accept with Tab or Enter. | P0 |
| E-02 | LSP client — diagnostics + squiggles | Implement LSP textDocument/publishDiagnostics. Show red/yellow squiggles on error/warning lines. | P0 |
| E-03 | LSP client — go to definition | Implement LSP textDocument/definition. Cmd+Click and F12 navigate to symbol definition. | P0 |
| E-04 | LSP client — hover documentation | Implement LSP textDocument/hover. Show API docs and type info on cursor hover or Cmd+hover. | P1 |
| E-05 | LSP client — find references | Implement LSP textDocument/references. Show all usages in a results panel. | P1 |
| E-06 | LSP client — rename symbol | Implement LSP textDocument/rename. Rename a symbol across the entire project. | P1 |
| E-07 | LSP client — code actions | Implement LSP textDocument/codeAction. Surface quick fixes and refactors from the gutter. | P1 |
| E-08 | LSP client — inlay hints | Implement LSP textDocument/inlayHint. Show parameter names and type hints inline. | P2 |
| E-09 | LSP client — folding ranges | Implement LSP textDocument/foldingRange as the source for code folding regions. | P1 |
| E-10 | Code folding | Collapse/expand code blocks. Triangles in gutter. Preserve fold state per file across sessions. | P1 |
| E-11 | AI ghost text completion | Inline multi-token AI completions shown as ghost text. Accept with Tab. Dismiss with Escape. | P0 |
| E-12 | Tree-sitter syntax highlighting | Replace any ad-hoc highlighting with Tree-sitter grammars. Support Swift, TypeScript, Python, Rust, Go, JSON, YAML, Markdown. | P1 |
| E-13 | Multi-cursor editing | Cmd+Click adds a cursor. Cmd+D selects next occurrence. Each cursor supports independent insert, delete, movement. | P1 |
| E-14 | Editor minimap | Scaled pixel representation of the full file in a right-side gutter. Visible viewport highlighted. Click/drag to jump. | P2 |
| E-15 | Bracket matching and auto-close | Highlight matching bracket on cursor. Auto-close `(`, `[`, `{`, `"`, `'`. | P1 |
| E-16 | Problems/diagnostics panel | Panel listing all LSP errors and warnings across the project. Click to navigate to file+line. | P0 |
| E-17 | Per-file error indicators in file tree | Red/yellow dot on file tree rows for files with LSP errors or warnings. | P1 |
| E-18 | Large file handling with virtualized rendering | Files over 1MB should not lock the editor. Virtualize line rendering. Disable expensive features for large files. | P1 |
| E-19 | Diff editor for comparing two files | Open two files side-by-side in a standard diff view outside of the git/review context. | P1 |
| E-20 | Code snippets library | Named code snippet collection. Insert snippet at cursor from command palette or tab-completion trigger. | P2 |
| E-21 | Extract function/variable refactoring | Select code, choose "Extract Function" or "Extract Variable." AI-assisted if LSP does not provide it. | P2 |
| E-22 | Debug launch configurations | Per-project debug configuration (like VS Code launch.json). Store targets, arguments, env vars. | P2 |
| E-23 | Breakpoint management UI | Set, clear, enable, disable breakpoints from the gutter. Breakpoint list panel. Conditional breakpoints. | P2 |
| E-24 | Debug variable inspector | When debugging, show local variables and their current values. Expandable for structs/objects. | P2 |
| E-25 | Debug call stack | Show the current call stack when paused at a breakpoint. Click stack frame to navigate. | P2 |
| E-26 | Multi-buffer view | Show excerpts from multiple files in one editable view for multi-file refactors (Zed-style). | P2 |
| E-27 | Font picker with preview | Choose editor font family and size from a picker. Live preview. Default SF Mono. | P2 |
| E-28 | Theme editor and picker | Choose color theme. Live preview. Support community themes. Custom token color overrides. | P2 |
| E-29 | Rename refactoring across project | Rename a symbol and have all references updated. Backed by LSP or AI fallback. | P1 |
| E-30 | File context menu operations | New file, rename, delete, reveal in Finder, copy path, copy relative path — all from right-click in file tree. | P1 |

---

## AI / Agent

| # | Task | Description | Priority |
|---|---|---|---|
| A-01 | @Recommended auto-context inference | Automatically score and inject the most relevant project files as implicit context before each agent turn. No manual @ required. | P0 |
| A-02 | Parallel agent launch | Launch up to 8 concurrent agent sessions. Each gets an isolated git worktree. | P0 |
| A-03 | Agent management sidebar | First-class sidebar showing all sessions: running, queued, background, completed. Name, status, elapsed time, cost, linked files. | P0 |
| A-04 | Subagent dispatch | Agents can spawn subagents for parallel work. Subagents report back to the parent. UI shows the dispatch tree. | P1 |
| A-05 | Contextual Cmd+K — entity-aware action panel | Cmd+K changes contents based on selected entity (ticket, file, session, PR). Entity-specific actions ranked first. | P0 |
| A-06 | Context assembly transparency | Collapsible "What was sent" section per agent response. Shows active rules, injected memories, auto-context files, slash command payloads, system prompt. | P1 |
| A-07 | Two-tier memory: auto-memories + project rules | Auto-generate memories from notable session events. Separate `.anvil/rules.md` for version-controlled team rules. Rules editor in Library workspace. | P1 |
| A-08 | Real-time action tracking as implicit context | `ActionObserver` records files opened/edited, terminal commands run, navigation changes. Passes last 20 actions as implicit context per turn. | P1 |
| A-09 | Session search across all conversations | Full-text search across all session messages and metadata. Backed by SQLite FTS5. Available in command palette and Agent sidebar. | P1 |
| A-10 | Slash commands for context assembly | /file, /tab, /selection, /diff, /branch, /ticket, /error inject referenced content as context. Preview before send. | P1 |
| A-11 | Conversation forking | Branch a new session from any message in an existing session. Original session preserved. | P1 |
| A-12 | System prompt editor per session | Expose and allow editing of the full system prompt per session. Show a diff of changes from defaults. | P1 |
| A-13 | Image and screenshot attachment | Attach images to agent messages. Paste from clipboard. Drag and drop from Finder. | P1 |
| A-14 | Voice input in agent conversations | Microphone input with transcription. Hold-to-record or toggle. | P2 |
| A-15 | Conversation templates | Pre-built templates ("Fix bug in {file}", "Review PR #{num}", "Write tests for {function}"). Accessible from command palette. | P2 |
| A-16 | Per-model routing mid-session | Switch AI provider or model mid-conversation without losing context. Planning model vs execution model routing. | P1 |
| A-17 | Agent work-in-progress timeline | Chronological panel of all active agent steps across sessions. What is every agent doing right now? | P1 |
| A-18 | Adversarial review agent | Dispatch a "critic" agent against a working agent's output. Surfaces issues before the developer reviews. | P2 |
| A-19 | Conflict detection for concurrent agents | Warn when two running agents have modified the same file. Show conflict before merge. | P1 |
| A-20 | Session sharing and linking | Share a session URL with a teammate. Deep link from notification/PR/ticket to a specific session. | P2 |
| A-21 | Multi-session resource dashboard | View cost, token usage, and worktree state across all running sessions in one panel. | P1 |
| A-22 | Reusable agentic workflows | Markdown-formatted `.anvil/workflows/*.md` files that define reusable agentic procedures. Version-controlled, team-shared. | P1 |
| A-23 | MCP tool/skill install flow | UI to install MCP tools as skills for an agent session. Per-session skill configuration. | P1 |
| A-24 | Agent synthesis room | Shared canvas where multiple agents post findings. Orchestrator agent consolidates. | P2 |
| A-25 | Background agent auto-PR | When a background agent session completes, offer one-click PR creation linked back to the session. | P1 |
| A-26 | Natural language command invocation | Type natural language in command palette. AI routes to the correct command or action. | P2 |
| A-27 | Chained palette workflows | Multi-step actions from a single palette entry: "create ticket, open agent, link to branch" as one workflow. | P2 |

---

## Git / Source Control

| # | Task | Description | Priority |
|---|---|---|---|
| G-01 | Merge conflict resolution UI | Three-panel conflict resolver: base, ours, theirs. Accept ours / accept theirs / keep both / manual per block. Conflicted files badged in sidebar. | P0 |
| G-02 | Unified source control navigator | Consolidate branches, remotes, tags, stashes, and local changes into one source list. Match Xcode's source control navigator model. | P1 |
| G-03 | History inspector for selected file | File commit history shown in the inspector panel when a file is selected. No mode switch required. | P1 |
| G-04 | Real git operations via CLI or libgit2 | All git operations (commit, push, pull, fetch, branch, merge, rebase, cherry-pick, revert, stash) backed by real git, not simulated. | P0 |
| G-05 | Interactive git rebase UI | Reorder, squash, fixup, edit, and drop commits in a visual list. Wire to `git rebase -i`. | P2 |
| G-06 | Git blame in editor | Show commit and author for each line in the editor gutter. Click to see full commit detail. | P1 |
| G-07 | Diff against any branch or commit | Open a diff view comparing the current file or full working tree against any branch, tag, or commit SHA. | P1 |
| G-08 | Stash with name and preview | Named stashes. Preview stash contents before applying. Apply, pop, or drop from UI. | P1 |
| G-09 | Submodule management | View submodule list. Update, init, deinit submodules from UI. Status indicators per submodule. | P2 |
| G-10 | Cross-repo / monorepo support | View and navigate multiple repos or monorepo workspaces within one Anvil project. | P2 |
| G-11 | Git LFS support | Handle large file storage objects correctly in diff, blame, and history views. | P2 |
| G-12 | Commit signature verification | Show GPG/SSH signature status on commits in history and graph views. | P2 |
| G-13 | Worktree browser | Show all active git worktrees. Navigate to a worktree's directory or open in editor. Create and delete worktrees from UI. | P1 |
| G-14 | Auto-commit message polish | AI commit message generation that respects conventional commits format. Configurable per project. | P1 |

---

## Review

| # | Task | Description | Priority |
|---|---|---|---|
| R-01 | Inline comments on specific lines | Click a diff line to start a comment thread. Thread shows inline below the line. | P0 |
| R-02 | Suggested changes in review | Reviewer edits the right side of a diff and proposes it as a commit suggestion. Author applies with one click. | P1 |
| R-03 | AI review with clustering + batch autofix | AI reviews the full diff, clusters findings by type (bug, style, architecture, security), and offers batch apply per cluster. | P1 |
| R-04 | Review summary generation | "Review with AI" button in PR detail. Returns summary paragraph, ranked findings, and approve/request-changes recommendation. | P1 |
| R-05 | Review checklist (customizable) | Per-project checklist that appears in every review. Items are checkable. Unchecked items block merge. | P1 |
| R-06 | Review against any base | Pick any branch or commit as the base for a diff review, not just the default base. | P1 |
| R-07 | File-level approve/reject | Mark individual files as reviewed/approved within a PR. Track coverage across the PR. | P1 |
| R-08 | Code owners and auto-reviewer assignment | Read CODEOWNERS file. Auto-suggest reviewers based on changed files. | P1 |
| R-09 | Review request notifications | Notify the user when a review is requested on a PR they own. Action button in notification to open review. | P1 |
| R-10 | Review templates | Pre-filled review comment templates per project (security review, API review, performance review). | P2 |
| R-11 | Batch review across multiple PRs | Select multiple PRs, review them in sequence. Track completion across the batch. | P2 |
| R-12 | Coverage overlay on diff | Overlay test coverage data on diff lines. Lines without coverage highlighted. | P2 |
| R-13 | Review statistics dashboard | Time to first review, time to merge, comment density per PR. Per-reviewer stats. | P2 |
| R-14 | Linked tickets display in PR | Show the linked tickets and their statuses in the PR inspector. Navigate ticket from PR. | P1 |
| R-15 | Draft PR support | Create, view, and convert draft PRs. Drafts displayed differently in review inbox. | P1 |
| R-16 | PR comment resolution tracking | Track which comment threads are resolved vs. open. Block merge on unresolved required threads. | P1 |
| R-17 | Review history | List of all PRs the user has previously reviewed with their decisions. Quick re-open. | P2 |
| R-18 | Issue-to-PR-to-deploy linked chain | Every entity in the pipeline (ticket → branch → agent session → PR → deploy) linked bidirectionally and surfaced in each detail view. | P1 |

---

## Plan / Tickets

| # | Task | Description | Priority |
|---|---|---|---|
| TK-01 | Ticket comments and activity log | Add comments to tickets. Activity log shows all state changes, comments, branch links, agent sessions. | P1 |
| TK-02 | Sub-tasks and checklists within tickets | Expandable checklist on tickets. Progress indicator on parent. Sub-task completion tracked separately. | P1 |
| TK-03 | Bulk actions for tickets | Multi-select tickets. Bulk change status, assignee, priority, label. | P1 |
| TK-04 | Sprint planning view | Drag tickets from backlog to sprint. WIP limits per column. Sprint start/end dates. | P1 |
| TK-05 | Velocity and burndown charts | Points completed per sprint. Burndown curve. Cycle-over-cycle trend. | P2 |
| TK-06 | Sprint cycle with automated rollover | Incomplete tickets auto-roll to the next sprint. Configurable rollover rules. | P1 |
| TK-07 | Assignee picker with team member list | Autocomplete assignee from team member list. Avatar display. Multi-assignee support. | P1 |
| TK-08 | Saved filters and complex queries | Filter tickets by any combination of status, assignee, priority, label, due date. Save named filter views. | P1 |
| TK-09 | Import from Linear / Jira | Bulk import tickets, boards, and sprints from Linear or Jira. Merge or replace existing. | P2 |
| TK-10 | Custom fields per project | Add arbitrary fields to tickets per project (e.g., "environment," "risk level," "story points"). | P2 |
| TK-11 | Time tracking on tickets | Log time spent. View total logged time per ticket. Week/sprint time report. | P2 |
| TK-12 | Estimation poker / story point voting | Request estimates from team. Reveal simultaneously. Consensus workflow. | P2 |
| TK-13 | AI-powered ticket auto-triage | Assign suggested priority, labels, and assignee based on ticket content. One-click accept. | P1 |
| TK-14 | Ticket search across all projects | Fast full-text search across all tickets in all projects. Scoped and global modes. | P1 |
| TK-15 | Ticket archive and done-state management | Separate archive from active view. Bulk archive completed sprints. Restore archived tickets. | P1 |
| TK-16 | Quick capture to ticket conversion | Convert a quick capture note to a full ticket with one action. Pre-fill title and description. | P1 |
| TK-17 | Note search across quick captures | Full-text search across all quick capture notes. Scoped to project or global. | P1 |
| TK-18 | Screenshot capture in quick capture | Paste or drag a screenshot into quick capture. Store inline. Attach to resulting ticket. | P1 |
| TK-19 | Ticket templates | Pre-filled ticket templates per project type (bug report, feature request, task, spike). | P1 |
| TK-20 | Activity timeline linking all entities | Every domain event (ticket change, agent completed, PR merged, build failed) writes to an activity timeline. Viewable per ticket and across the project. | P1 |

---

## Ship / Deploy

| # | Task | Description | Priority |
|---|---|---|---|
| D-01 | Real Vercel deployment integration | Wire VercelHostingAdapter to real Vercel API. Trigger, monitor, and roll back deployments from Anvil. | P1 |
| D-02 | Real Railway deployment integration | Wire a Railway adapter. Same capabilities as Vercel. | P1 |
| D-03 | Deployment history with rollback | List all past deployments per environment. One-click rollback to any prior deployment. | P1 |
| D-04 | Environment variable comparison | Side-by-side diff of env vars across environments (staging vs production). Highlight mismatches. | P1 |
| D-05 | Deployment log search | Search across deployment logs. Highlight matching lines. Filter by log level. | P1 |
| D-06 | Preview URL inline browser | Open a deployment's preview URL in an embedded browser within Ship mode. | P2 |
| D-07 | Deployment pipeline visualization | Show each step in the CI/CD pipeline as a node graph. Step status, duration, logs on click. | P1 |
| D-08 | Auto-deploy on merge configuration | Configure per-environment auto-deploy rules. Trigger deploy when a PR merges to a specific branch. | P2 |
| D-09 | Deploy locks and freeze indicators | Lock an environment to prevent new deploys. Visual freeze indicator in sidebar. | P2 |
| D-10 | Feature flags integration | View and toggle feature flags from Ship mode. Integrate with LaunchDarkly or Unleash. | P2 |
| D-11 | Deployment approval workflow | Require explicit approval before deploying to production. Approval request → notify → approve/reject. | P2 |
| D-12 | Secrets rotation reminders | Track when secrets were last rotated. Alert when approaching expiry. | P2 |
| D-13 | Multi-service deploy coordination | Coordinate deploys across multiple services. Dependency ordering. Rollback entire stack. | P2 |
| D-14 | Canary and blue-green deployment support | Configure canary traffic split. Monitor error rate. Auto-promote or rollback. | P2 |
| D-15 | Domain management | View and manage custom domains for each environment from Ship mode. | P2 |
| D-16 | Resource usage monitoring | CPU, memory, bandwidth, request rate per environment. Sparkline charts. Alert thresholds. | P2 |
| D-17 | Cost per environment display | Show estimated infrastructure cost per environment per month. Delta from last month. | P2 |
| D-18 | Health checks and uptime monitoring | Per-environment uptime status, incident history, SLA calculation. | P1 |
| D-19 | Deploy notifications integration | Send deploy success/failure to Slack or email. Configurable per environment. | P2 |
| D-20 | Rollback dry-run preview | Show which files and env vars would change if rolling back to a specific deployment. | P2 |

---

## Providers

| # | Task | Description | Priority |
|---|---|---|---|
| PR-01 | Jira provider for tickets | Read and write Jira issues from Intent mode. OAuth flow. Bidirectional sync. | P1 |
| PR-02 | Linear provider for tickets | Full Linear sync beyond current stub. Webhook-based updates. | P1 |
| PR-03 | Notion provider for docs | Read and write Notion pages from Docs mode. OAuth. Search across workspace. | P2 |
| PR-04 | Figma provider for design | Browse Figma files. View design tokens. Navigate frames. Export assets to project. | P2 |
| PR-05 | Vercel provider — full integration | Environments, deploys, domains, env vars, logs, rollback all wired to real Vercel API. | P1 |
| PR-06 | Netlify provider | Same capabilities as Vercel adapter for Netlify customers. | P2 |
| PR-07 | AWS provider — basics | View ECS services, Lambda functions, S3 buckets. Trigger deploys. View logs. | P2 |
| PR-08 | Stripe webhooks | View incoming Stripe webhook events in Observability mode. Filter by event type. | P2 |
| PR-09 | Sentry provider — full integration | Wire SentryObservabilityAdapter to real Sentry API. Error feed, stack traces, error-to-code navigation. | P1 |
| PR-10 | Slack provider — full integration | Wire SlackMessagingAdapter to real Slack API. Channel list, DMs, threads, search, send messages. | P1 |
| PR-11 | GitHub provider — deeper integration | PR reviews, inline comments, suggested changes, code owners, CI status, issue sync. | P1 |
| PR-12 | GitLab provider | PR/MR list, review, CI pipelines, deploy — mirror GitHub adapter for GitLab customers. | P2 |
| PR-13 | Bitbucket provider | PR list, review, pipelines — for Atlassian stack users. | P2 |
| PR-14 | Google Calendar provider | Read Google Calendar events into Schedule mode. Create events with meet links. | P2 |
| PR-15 | Apple Calendar provider | Read Apple Calendar events into Schedule mode. Create events. | P2 |
| PR-16 | Datadog provider | View service metrics, dashboards, and alerts from Observability mode. | P2 |
| PR-17 | Docker provider — full integration | List containers, images, compose stacks. Start/stop/restart/remove containers. View logs. | P1 |
| PR-18 | OpenAI provider — function calling | Wire OpenAI function calling to AnvilACP tool definitions. | P1 |
| PR-19 | Gemini provider | Add Google Gemini to ACP provider list. Model selection, streaming, cost tracking. | P1 |
| PR-20 | Provider status page | Dashboard showing all configured providers, their connection status, last sync time, and errors. | P1 |

---

## Architecture / DDD

| # | Task | Description | Priority |
|---|---|---|---|
| AR-01 | SelectionCoordinator at AppState level | Move selection state (selected session, ticket, file, PR) to a shared coordinator. Selection survives sidebar collapse, inspector toggle, mode switch. | P0 |
| AR-02 | ShellDestination model for navigation | Replace ad-hoc navigation with a typed `ShellDestination` enum. All page-level navigation flows through it. | P1 |
| AR-03 | Typed presentation coordinator | Replace ad-hoc overlay stack with a typed `PresentationCoordinator`. All sheets, modals, and overlays go through it. | P1 |
| AR-04 | Entity deep link routing | Every durable entity (ticket, session, file, PR, deployment) has a stable URL-like identifier. Deep link from notification → entity. | P1 |
| AR-05 | Universal action menu protocol | Every entity type implements `ActionMenuProvider`. `Cmd+K` queries the focused entity's action provider first. | P1 |
| AR-06 | Durable ticket persistence | Remove demo seeding from production startup path. Tickets persist to SQLite. Demo mode is an explicit opt-in. | P0 |
| AR-07 | Activity timeline domain entity | `ActivityTimeline` in AnvilDomain. Domain events write activity entries. Every entity links to its timeline. | P1 |
| AR-08 | Command registry as single source of truth | One `CommandRegistry` used by menu bar, command palette, keyboard shortcuts, and help system. No duplicate command definitions. | P1 |
| AR-09 | Command validity checks in CI | Build fails if a command ID registered in the command registry has no handler. | P1 |
| AR-10 | Navigation validity checks in CI | Build fails if a sidebar row navigates to a placeholder destination with no real content. | P1 |
| AR-11 | CQRS for agent sessions | Separate session read model (list, search, filter) from write model (start, send, stop, cancel). | P2 |
| AR-12 | Domain event replay | Ability to replay domain events for debugging and audit. Store events in append-only log. | P2 |
| AR-13 | Port compliance tests | Compile-time or test-time verification that every concrete adapter satisfies its port protocol fully. | P1 |
| AR-14 | Sendable audit | Automated check that no `@unchecked Sendable` workarounds exist without documented justification. | P1 |
| AR-15 | Workspace state restoration | Restore sidebar selection, inspector state, utility deck layout, and active entity per workspace on relaunch. | P1 |

---

## Tests

| # | Task | Description | Priority |
|---|---|---|---|
| TS-01 | XCUITest: mode switching | Automated click-through of all mode tab switches. Verify content area changes. | P0 |
| TS-02 | XCUITest: command palette | Open palette, search, navigate, execute an action. Verify result. | P0 |
| TS-03 | XCUITest: agent session start | Start a session, send a message, verify streaming response renders. | P0 |
| TS-04 | XCUITest: ticket CRUD | Create, read, update, delete a ticket. Verify persistence and list refresh. | P1 |
| TS-05 | XCUITest: PR review flow | Open a PR, view diff, add a comment, submit review. | P1 |
| TS-06 | XCUITest: sidebar navigation | Click all sidebar rows. Verify each navigates to real content or shows an honest empty state. | P0 |
| TS-07 | XCUITest: keyboard shortcuts | Cmd+1 through Cmd+9 mode switches. Cmd+K palette. All wired shortcuts from TRUTH_MATRIX.md. | P0 |
| TS-08 | XCUITest: inspector toggle | Cmd+Shift+I opens and closes inspector. Inspector content changes with selection. | P1 |
| TS-09 | XCUITest: source control | Stage files, write commit message, commit. Verify status bar update. | P1 |
| TS-10 | XCUITest: terminal session | Open terminal, type a command, verify output renders. | P1 |
| TS-11 | Unit test: AgentSession domain entity | Test all state transitions (idle, running, paused, completed, failed). | P1 |
| TS-12 | Unit test: Ticket domain entity | Test status transitions, relation management, comment append. | P1 |
| TS-13 | Unit test: EventBus | Publish an event, verify all registered handlers are called with correct payload. | P1 |
| TS-14 | Unit test: CommandRegistry | Register a command, look it up by ID, verify action dispatch. | P1 |
| TS-15 | Unit test: ACPCostTracker | Verify token counting and budget enforcement logic per session. | P1 |
| TS-16 | Unit test: WorktreeOrchestrator | Create a worktree for a session, verify isolation, delete on session end. | P1 |
| TS-17 | Unit test: ContextBuilder | Assemble context from files, memories, rules, slash commands. Verify ordering and token limit trimming. | P1 |
| TS-18 | Integration test: AnvilGitHub adapter | OAuth token + real GitHub API. List PRs, fetch diff, post comment (sandbox repo). | P2 |
| TS-19 | Integration test: SQLiteDatabaseAdapter | Connect to SQLite file, list tables, run query, return typed results. | P1 |
| TS-20 | Integration test: ACPClient + AnthropicProvider | Send a message, verify streaming response, verify cost tracking. | P2 |
| TS-21 | Snapshot/regression tests: shell layout | Verify main window layout at default, sidebar-collapsed, and inspector-open states. | P1 |
| TS-22 | Persistence tests: session restoration | Save session state, relaunch, verify selection and scroll position restore. | P1 |
| TS-23 | Performance test: startup time | App launch to interactive under 1.5 seconds on Apple Silicon. Fail CI if over threshold. | P1 |
| TS-24 | Performance test: large file rendering | Open a 10K-line file, measure scroll FPS. Target 60fps. | P1 |
| TS-25 | Accessibility tests: VoiceOver navigation | Verify all interactive elements have accessibility labels. VoiceOver can navigate entire shell. | P1 |

---

## UI / UX

| # | Task | Description | Priority |
|---|---|---|---|
| UX-01 | Fix KeyEventRouter — stop intercepting text fields | Remove single-character interception when a chord is pending. Gate chord matching on text field focus state. | P0 |
| UX-02 | Fix overlay backdrops — stop blocking sidebar | Replace full-screen backdrop tap-capture with focused overlay dismiss that does not intercept sidebar. | P0 |
| UX-03 | Fix auxiliary sidebar tap handlers | `navItem()` in Sidebar.swift must have real `.onTapGesture` or `Button` action wired to navigation. | P0 |
| UX-04 | Single-key action shortcuts per entity | Focused list row: `a` assigns ticket, `p` sets priority, `r` resumes session, `x` cancels, `↵` opens. Gate on no text field focused. | P1 |
| UX-05 | Empty states with forward routing | Every empty state has exactly one next action button. Route to setup, backlog, or configuration. Never dead-end. | P1 |
| UX-06 | Passive background work surfacing | Status bar shows compact spinner + count for running agents/deploys. Click expands to task list. No modal interruptions. | P1 |
| UX-07 | Collapsible context inspection per agent turn | "Context used" section below each agent response. Collapsed by default. Files, memories, rules, slash commands listed. | P1 |
| UX-08 | Consistent row anatomy across all sidebars | Leading icon, primary label, trailing badge, status dot, hover-reveal actions. No row deviates from this grammar. | P1 |
| UX-09 | Selection survives state changes | Sidebar collapse, inspector toggle, utility deck show/hide, mode switch — selection is never lost. | P1 |
| UX-10 | Remove all no-op sidebar rows | Any sidebar row with no real destination gets marked disabled with explanation or removed entirely. | P0 |
| UX-11 | Remove dead shortcut labels | Any shortcut hint in UI that is not wired to a real command must be removed. | P0 |
| UX-12 | Inspector tied to selection | Inspector panel content changes based on what entity is selected in sidebar or main content. Not mode-locked. | P1 |
| UX-13 | VoiceOver accessibility | All interactive elements have accessibility labels. VoiceOver order follows reading order. Tested. | P1 |
| UX-14 | Keyboard navigation completeness | Every list, toolbar, sidebar, and dialog is fully navigable without a mouse. Tab order is correct. | P1 |
| UX-15 | High contrast mode | Full support for macOS Increase Contrast setting. No information conveyed by color alone. | P1 |
| UX-16 | Reduced motion mode | Respect macOS Reduce Motion. Replace animations with instant transitions. | P1 |
| UX-17 | Multiple window support | Open Anvil in multiple windows. Each window has independent workspace/mode/selection state. | P2 |
| UX-18 | Window layout save and restore | Save named window layouts. Restore on relaunch. Layouts include sidebar width, inspector visibility, utility deck state. | P2 |
| UX-19 | Focus mode with distraction blocking | Hide sidebar, utility deck, and notifications. Full-screen or windowed. Timer option. | P2 |
| UX-20 | Contextual toolbar actions | Toolbar actions change based on the active workspace and selected entity. Not a static global toolbar. | P1 |
| UX-21 | Settings import and export | Export and import all Anvil settings as a JSON file. Useful for team onboarding. | P2 |
| UX-22 | Settings search | Type to search settings. Highlight matching settings pages and items. | P1 |
| UX-23 | Per-project settings override | Override global settings per project (indentation, line endings, formatter, provider). | P1 |
| UX-24 | User profile and account page | Display signed-in accounts (GitHub, providers), subscription status, API key management. | P1 |
| UX-25 | Onboarding flow | First-launch wizard: connect GitHub, configure AI provider, open or create a project. | P1 |

---

## Performance

| # | Task | Description | Priority |
|---|---|---|---|
| PF-01 | Startup time target: under 1.5s | Profile cold start on Apple Silicon. Eliminate blocking work from the startup path. Defer heavy services to background. | P1 |
| PF-02 | Memory target: under 200MB idle | Profile memory at idle with a project open. Identify and fix leaks from agent session accumulation. | P1 |
| PF-03 | Rendering at 120fps on ProMotion | Verify all lists, scrolls, and animations hit 120fps on ProMotion displays. No dropped frames on sidebar collapse. | P1 |
| PF-04 | Background task efficiency | Agent sessions and file indexing must not throttle the main UI thread. All heavy work on background actors. | P1 |
| PF-05 | File indexing performance | Index a 100K-file monorepo without blocking the editor or consuming >10% CPU in steady state. | P1 |
| PF-06 | Search response time target | Command palette results appear within 50ms of keystroke for projects under 10K files. | P1 |
| PF-07 | Terminal rendering performance | Terminal output at high throughput (e.g., `find /`) should not drop below 60fps. Virtualize terminal line buffer. | P1 |
| PF-08 | Agent streaming responsiveness | First token appears within 500ms of sending a message. Streaming updates do not stutter the UI. | P1 |
| PF-09 | SQLite query performance | Database query results appear within 200ms for tables under 100K rows. | P1 |
| PF-10 | Diff rendering for large PRs | PRs with 500+ changed files load the file list immediately. Diff content is lazy-loaded per file. | P1 |

---

## Plugin SDK

| # | Task | Description | Priority |
|---|---|---|---|
| PL-01 | Plugin loading and activation system | Load plugins from disk, activate them, wire them into the command registry and sidebar. | P1 |
| PL-02 | Plugin manifest format | Define `plugin.json` manifest: name, version, entry point, permissions, capabilities, icon. | P1 |
| PL-03 | Plugin sandboxing | Run plugin code in a restricted sandbox. Plugins cannot access the filesystem or network outside declared permissions. | P1 |
| PL-04 | Plugin API: command registration | Plugins register commands that appear in the command palette and menu bar. | P1 |
| PL-05 | Plugin API: sidebar panel | Plugins contribute sidebar sections to the Library or a designated workspace. | P2 |
| PL-06 | Plugin API: ACP access | Plugins invoke ACP for AI capabilities without needing their own API keys. | P1 |
| PL-07 | Plugin API: event subscription | Plugins subscribe to domain events (OnPRMerged, OnAgentCompleted, OnTicketStatusChanged). | P2 |
| PL-08 | Plugin API: editor actions | Plugins contribute editor commands (format, lint, transform selection). | P2 |
| PL-09 | Plugin marketplace UI — search and install | Search published plugins. View details. Install with one click. No Xcode/Swift required. | P1 |
| PL-10 | Plugin marketplace — publish flow | CLI tool to publish a plugin. Signing, versioning, and review process. | P2 |
| PL-11 | First-party plugin examples | At least three bundled plugins (e.g., Vercel, Linear, Sentry) implemented entirely via AnvilPluginSDK. | P1 |
| PL-12 | Plugin dependency management | Plugins declare dependencies on other plugins. Conflict detection. Auto-install dependencies. | P2 |
| PL-13 | Plugin update notifications | Notify user when installed plugins have updates. One-click update. Changelog preview. | P2 |
| PL-14 | Plugin permissions UI | Show what each installed plugin can access. Revoke permissions per plugin. | P1 |
| PL-15 | WASM-based plugin sandbox | Explore WASM as an alternative sandbox model for stronger isolation (similar to Zed's extension model). | P2 |

---

## Database

| # | Task | Description | Priority |
|---|---|---|---|
| DB-01 | Live SQLite connection | Wire `SQLiteDatabaseAdapter` to a real file. Browse tables, run queries, view results. | P0 |
| DB-02 | PostgreSQL connection | Add a PostgreSQL adapter behind `DatabasePort`. Connection string or individual field entry. | P1 |
| DB-03 | MySQL connection | Add a MySQL adapter. Same capability set as PostgreSQL. | P2 |
| DB-04 | Connection profiles | Save named connection profiles. Quick switch between connections. Per-project defaults. | P1 |
| DB-05 | Table data browser with pagination | Browse table rows with pagination. Sort columns. Filter rows. | P1 |
| DB-06 | Row-level editing | Edit individual cell values inline in the table browser. Commit or discard changes. | P1 |
| DB-07 | Foreign key navigation | Click a foreign key value to jump to the referenced row in the referenced table. | P2 |
| DB-08 | Query autocomplete from schema | LSP-style autocomplete for SQL queries using the live schema. Table names, column names, function names. | P1 |
| DB-09 | Query history with saved queries | Full query history with timestamps. Star a query to save it. Named saved queries panel. | P1 |
| DB-10 | Result export — CSV and JSON | Export query results to CSV or JSON file. Copy to clipboard option. | P1 |
| DB-11 | ER diagram visualization | Generate an entity-relationship diagram from the live schema. Interactive, filterable by table group. | P2 |
| DB-12 | Query explain plan visualization | Show the database query execution plan as a visual node graph. Highlight bottlenecks. | P2 |
| DB-13 | Index analysis | Show indexes per table. Highlight tables missing indexes on frequently queried columns. | P2 |
| DB-14 | Schema diff between environments | Compare schema between staging and production. Highlight table/column/index differences. | P2 |
| DB-15 | Migration runner | Run database migrations from the UI. Track migration history. Show pending migrations. | P1 |
| DB-16 | AI data seed generation | Ask AI to generate realistic seed data for a table based on its schema. One-click insert. | P2 |
| DB-17 | Multi-query tabs | Open multiple queries as tabs. Each tab has independent history and results. | P1 |
| DB-18 | Schema search | Search across all tables and columns by name. Navigate to table or column from results. | P1 |

---

## Messaging

| # | Task | Description | Priority |
|---|---|---|---|
| MS-01 | Real Slack integration | Wire SlackMessagingAdapter to real Slack API. Read channels, DMs, threads. Send messages. | P1 |
| MS-02 | Thread view with replies | Click a message to open its thread. Reply inline. Collapse threads. | P1 |
| MS-03 | Read/unread tracking | Track read state per channel and message. Unread badge on sidebar rows. Mark all read action. | P1 |
| MS-04 | Channel creation and management | Create, archive, and rename channels from Messaging mode (for providers that support it). | P2 |
| MS-05 | Direct messages | DM list. Open a DM. Send and receive messages. Presence indicator. | P1 |
| MS-06 | Message search | Search message history across channels. Filter by date, channel, or sender. | P1 |
| MS-07 | @mention autocomplete | Type `@` in message compose to autocomplete team member names. | P1 |
| MS-08 | Emoji reactions | Add/remove emoji reactions on messages. Reaction count and reactor list on hover. | P2 |
| MS-09 | File sharing in messages | Drag a file into the message composer to attach. Preview attachments in thread. | P2 |
| MS-10 | Code block sharing with syntax highlighting | Paste code in messages with syntax highlighting applied. Language autodetected. | P2 |
| MS-11 | Message pinning | Pin important messages in a channel. Pinned messages panel accessible from channel header. | P2 |
| MS-12 | Turn message into ticket | Right-click a message to create a ticket with the message content pre-filled. | P1 |
| MS-13 | Presence indicators | Show online/away/offline status for team members in DM list and @mention picker. | P2 |
| MS-14 | Notification integration | Incoming messages surface as Anvil notifications. Click to open message in Messaging mode. | P1 |

---

## Notifications

| # | Task | Description | Priority |
|---|---|---|---|
| NF-01 | Notification grouping by project and type | Group notifications: all PR review requests together, all CI failures together, all ticket assignments together. | P1 |
| NF-02 | Notification snooze | Snooze a notification for 1h, 4h, tomorrow, or a custom time. Snoozed items have a clock badge. | P1 |
| NF-03 | Notification archive | Archive handled notifications. Archived inbox accessible. Auto-archive after 7 days. | P1 |
| NF-04 | AI smart notification triage | AI suggests priority for incoming notifications: "This CI failure likely needs your attention now." | P2 |
| NF-05 | Action buttons on critical notifications | Approve PR, view error, open agent — direct action buttons on notification rows. No context switch required. | P1 |
| NF-06 | Notification deep links to entities | Every notification links to the specific entity (PR, ticket, deployment, error). One click to context. | P1 |
| NF-07 | Badge count in dock and app icon | Unread notification count in dock badge and app icon. Clears when notifications are viewed. | P1 |
| NF-08 | Notification sync state visibility | Show last sync time and provider connection status in notification preferences. | P1 |

---

## Docs

| # | Task | Description | Priority |
|---|---|---|---|
| DOC-01 | Rich markdown editing toolbar | Bold, italic, code, link, heading, blockquote, list — toolbar buttons in docs editor. Keyboard shortcuts. | P1 |
| DOC-02 | Live markdown preview | Toggle between edit and preview. Side-by-side view option. | P1 |
| DOC-03 | Full-text document search | Search across all docs in the project. Highlight matching text in results. Navigate to match. | P1 |
| DOC-04 | Table of contents sidebar | Auto-generated outline from headings. Clicking a heading scrolls to it. Sticky at top of inspector. | P1 |
| DOC-05 | Document versioning backed by git | Every doc save creates a git commit. Restore any prior version. Diff between versions. | P2 |
| DOC-06 | Wiki-style [[link]] syntax | Type `[[` to link to another doc. Autocomplete doc titles. Backlinks panel in inspector. | P2 |
| DOC-07 | External docs browsing | Browse DevDocs, MDN, and Swift documentation without leaving Anvil. Searchable. | P2 |
| DOC-08 | Document templates | Pre-built templates (ADR, runbook, meeting notes, postmortem). Accessible from new-doc flow. | P1 |
| DOC-09 | Image embedding | Drag or paste images into docs. Stored in project assets. Alt text field. | P1 |
| DOC-10 | Code block with syntax highlighting | Fenced code blocks in docs render with syntax highlighting. Language tag autodetected. | P1 |
| DOC-11 | README auto-generation | AI generates a README from the project structure and source code summary. Editable. | P2 |
| DOC-12 | API documentation auto-generation | Extract inline code documentation and generate API reference docs. | P2 |
| DOC-13 | Document export — PDF and HTML | Export any doc to PDF or HTML. Preserve formatting and code block highlighting. | P2 |
| DOC-14 | Personal vs team vs external doc sections | Separate sidebar sections for private notes, team docs, and external documentation links. | P1 |
| DOC-15 | Collaborative editing indicators | Show who else is viewing or editing a doc. Cursor positions of other editors (for team scenarios). | P2 |

---

## Security

| # | Task | Description | Priority |
|---|---|---|---|
| SEC-01 | Keychain for all credentials | All API keys, OAuth tokens, and passwords stored in macOS Keychain via KeychainStore. Zero plaintext secrets on disk. | P0 |
| SEC-02 | Biometric authentication for secret access | Optionally require Touch ID / Face ID before revealing stored secrets or credentials. | P1 |
| SEC-03 | Team permissions model | Define who can access which providers and projects. Role-based: admin, contributor, viewer. | P2 |
| SEC-04 | Audit log | Record all provider API calls, agent tool invocations, and deploy actions with timestamp and actor. Exportable. | P2 |
| SEC-05 | Secret scanning in commits | Scan staged changes for API keys, tokens, and other secrets before commit. Block commit if found. | P1 |
| SEC-06 | Agent tool permission model | Configurable policy per agent session: which tools are allowed, which require approval, which are always denied. | P1 |
| SEC-07 | Provider credential rotation workflow | Guide the user through rotating an expired credential. Show which sessions/integrations are affected. | P2 |
| SEC-08 | Sandboxed agent execution | Agent shell commands run in a sandboxed environment. Configurable filesystem and network access scope. | P2 |

---

## Observability / Monitoring

| # | Task | Description | Priority |
|---|---|---|---|
| OB-01 | Real Sentry integration | Wire SentryObservabilityAdapter to real Sentry API. Error feed, issue detail, stack traces, error-to-code navigation. | P1 |
| OB-02 | Error-to-code navigation | Click a stack frame in an error to open the file at the exact line in the editor. | P1 |
| OB-03 | Error trends over time | Chart showing error volume per day/week. Spike detection. Filter by release or environment. | P2 |
| OB-04 | Error-to-deployment correlation | Show which deployment introduced a given error. Link back to deploy detail. | P2 |
| OB-05 | Alert configuration | Set up alert rules in Observability mode. Notify via Anvil notification, Slack, or email. | P2 |
| OB-06 | Service health map | Visual map of services with health status. Click a service to see its error feed and metrics. | P2 |

---

## Schedule / Calendar

| # | Task | Description | Priority |
|---|---|---|---|
| SC-01 | Real Apple Calendar integration | Read events from Apple Calendar. Show in Schedule mode timeline. | P2 |
| SC-02 | Real Google Calendar integration | OAuth. Read and write Google Calendar events. | P2 |
| SC-03 | Calendar week and month views | Week view: time columns with event blocks. Month view: grid with event count indicators. | P2 |
| SC-04 | Drag-to-create time blocks | Drag on the timeline to create a focus block or meeting placeholder. | P2 |
| SC-05 | Meeting join buttons | Show video call join button (Zoom, Meet, Calendly) on meeting events. | P2 |
| SC-06 | Focus mode from schedule | Block focus time on calendar. Anvil enters focus mode during the block. | P2 |

---

## API Client

| # | Task | Description | Priority |
|---|---|---|---|
| API-01 | HTTP request builder | Compose GET, POST, PUT, PATCH, DELETE requests. Headers, body, auth. | P2 |
| API-02 | Request collection management | Save and organize requests in named collections. Import/export Postman collections. | P2 |
| API-03 | Request history | All past requests with responses stored. Search history. Re-run any prior request. | P2 |
| API-04 | Response viewer | Pretty-print JSON/XML responses. Status code, headers, size, timing displayed. | P2 |
| API-05 | Environment variables for requests | Define variables per environment (base URL, auth token). Switch environments per request. | P2 |
| API-06 | AI request generation | Describe the API call you want to make. AI generates the request from OpenAPI spec or description. | P2 |

---

## Summary Statistics

| Category | Total Tasks | P0 | P1 | P2 |
|---|---|---|---|---|
| Terminal | 18 | 2 | 13 | 3 |
| Editor | 30 | 4 | 16 | 10 |
| AI / Agent | 27 | 5 | 16 | 6 |
| Git / Source Control | 14 | 2 | 8 | 4 |
| Review | 18 | 1 | 12 | 5 |
| Plan / Tickets | 20 | 1 | 14 | 5 |
| Ship / Deploy | 20 | 0 | 8 | 12 |
| Providers | 20 | 0 | 12 | 8 |
| Architecture / DDD | 15 | 2 | 10 | 3 |
| Tests | 25 | 5 | 18 | 2 |
| UI / UX | 25 | 5 | 16 | 4 |
| Performance | 10 | 0 | 10 | 0 |
| Plugin SDK | 15 | 0 | 9 | 6 |
| Database | 18 | 1 | 12 | 5 |
| Messaging | 14 | 0 | 8 | 6 |
| Notifications | 8 | 0 | 7 | 1 |
| Docs | 15 | 0 | 9 | 6 |
| Security | 8 | 1 | 4 | 3 |
| Observability | 6 | 0 | 2 | 4 |
| Schedule / Calendar | 6 | 0 | 0 | 6 |
| API Client | 6 | 0 | 0 | 6 |
| **Total** | **338** | **29** | **194** | **105** |

---

## P0 Quick Reference

These 29 tasks block basic developer adoption and must ship first:

1. T-01 — Real PTY terminal
2. T-15 — Terminal copy/paste
3. E-01 — LSP autocomplete
4. E-02 — LSP diagnostics + squiggles
5. E-03 — LSP go to definition
6. E-11 — AI ghost text completion
7. E-16 — Problems/diagnostics panel
8. A-01 — @Recommended auto-context
9. A-02 — Parallel agent launch
10. A-03 — Agent management sidebar
11. A-05 — Contextual Cmd+K
12. G-01 — Merge conflict resolution UI
13. G-04 — Real git operations
14. R-01 — Inline comments on diff lines
15. TK-06 (AR-06) — Durable ticket persistence
16. DB-01 — Live SQLite connection
17. AR-01 — SelectionCoordinator at AppState
18. AR-06 — Durable ticket persistence (no demo seeding)
19. TS-01 — XCUITest mode switching
20. TS-02 — XCUITest command palette
21. TS-03 — XCUITest agent session
22. TS-06 — XCUITest sidebar navigation
23. TS-07 — XCUITest keyboard shortcuts
24. UX-01 — Fix KeyEventRouter intercepting text fields
25. UX-02 — Fix overlay backdrops blocking sidebar
26. UX-03 — Fix auxiliary sidebar tap handlers
27. UX-10 — Remove all no-op sidebar rows
28. UX-11 — Remove dead shortcut labels
29. SEC-01 — Keychain for all credentials
