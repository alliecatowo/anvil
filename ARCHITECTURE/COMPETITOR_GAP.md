# Anvil Competitor Gap Analysis

Last updated: 2026-03-28

This document synthesizes fresh competitive research across seven targets — Cursor, Windsurf, Zed, Xcode, Linear, GitHub Copilot, and Raycast — and maps findings directly against Anvil's current capabilities. It is intended to drive concrete prioritization decisions, not to be a catalog of everything every tool does.

Scope: what each competitor does well, what Anvil can steal, a feature gap table, and 20 ranked actionable items.

---

## Executive Summary

The competitive landscape in early 2026 has converged around two clear differentiators: (1) parallel agent execution with git-worktree isolation, and (2) persistent context memory across sessions. Every major AI-first tool has shipped or is shipping both. Anvil has shipped background sessions and session memory already, which puts it ahead of where most competitors were six months ago.

The gap that matters most is not feature count — it is interaction density and honesty. Cursor's agent sidebar is a first-class object in its shell. Windsurf's Cascade tracks every action the developer takes. Zed's inline assistant rewrites selected text in-place with no ceremony. Linear's single-key shortcuts and command surface reduce friction at every step. Raycast turns every selected entity into an immediately actionable surface.

Anvil has all the structural pieces. It is missing the integration quality that makes each piece feel inevitable rather than assembled. The highest-leverage work is: completing the @ context system, shipping parallel agents with a real agent management sidebar, making the command palette the universal action surface it is meant to be, and landing honest LSP-backed editor quality. These four things will close 80% of the perception gap with Cursor/Windsurf.

The native macOS positioning is Anvil's structural moat. None of the competitors (VS Code-based or Electron-based) can match a properly executed SwiftUI/AppKit app on Apple Silicon. That moat is only valuable if the app actually feels native — smooth, fast, keyboard-complete, state-restoring, and accessible. That quality bar must be treated as non-negotiable.

---

## Per-Competitor Analysis

### 1. Cursor

**What Cursor does well**

Cursor 2.0 made agents first-class shell objects rather than a chat panel bolted onto an editor. The dedicated agent sidebar shows every running, queued, and completed agent as a named item with its own status, progress indicators, and output logs. Up to eight agents can run in parallel, each in its own git worktree — automatically created and managed, invisible to the user. The parent agent can continue working while subagents run asynchronously, and subagents can spawn their own subagents, producing a coordinated tree.

The @ reference system is the best in class: @File, @Folder, @Code, @Docs, @Git, @Web, @PastChats, @RecentChanges, @LintErrors, and @Recommended (auto-fetches context in agent mode). These are available in every input surface — Chat, Composer, and ⌘K inline. Composer is the multi-file editing engine: natural language description, cross-file edits generated, visual diffs presented per file with accept/reject/modify per hunk.

Background agents can open PRs for review when finished. The native browser tool lets the agent test its own work and iterate. Model switching is free mid-session between OpenAI, Anthropic, Gemini, and xAI frontends.

Cursor Rules (`.cursorrules`) establish per-project AI conventions that persist across sessions, similar to Anvil's `.anvil/memory.md` but at the project-rules level rather than the memory level.

**What Anvil can take**

- Agent sidebar as a first-class durable object, not just a list that disappears on session switch. Each session is a named entity with status, elapsed time, cost so far, and linked files.
- Parallel agent launch from a single prompt or plan step. Eight concurrent sessions, each in an isolated worktree.
- @Recommended auto-context in agent mode: infer relevant files without requiring manual @ specification.
- Per-model routing mid-session: let the user choose planning model vs. execution model per step.
- Background agent auto-PR: when an agent finishes, offer a one-click PR rather than just showing completion.
- Cursor's "plan first, build second" model: the agent produces a structured editable plan before writing code. Anvil has agent plan view (#354) — this confirms the pattern but the UI needs to be as crisp as Cursor's.

---

### 2. Windsurf (formerly Codeium, now Cognition AI)

**What Windsurf does well**

Windsurf's strongest differentiator is the Cascade context engine's awareness of real-time developer actions. Cascade tracks edits, terminal commands, clipboard content, conversation history, and navigation state — not just what you typed in the chat box. This lets Cascade infer intent without requiring the user to re-explain their context each message.

The Memories system is the second key piece: Cascade auto-generates and stores memories at the workspace level when it encounters facts worth remembering. Users can also write explicit Rules at the global, workspace, or system level. The context assembly pipeline loads rules, loads relevant memories, reads open files, runs codebase retrieval, reads recent actions, and then assembles the final prompt in a weighted merge. This is more structured than any competitor's approach.

Reusable Workflows (markdown-formatted command files) let teams version-control common agentic processes. Terminal snippets and context from the integrated terminal feed directly into Cascade's awareness. Tab + Supercomplete provides fill-in-the-middle multi-line completion including terminal context awareness.

**What Anvil can take**

- Real-time developer action tracking as implicit context: Cascade knows what files you have open, what terminal commands you ran, and what you edited — before you ask it anything. Anvil's agents currently receive only what the user explicitly provides.
- Two-tier memory architecture: auto-generated memories (session-scoped) separate from user-written rules (project-scoped, version-controlled). Anvil has `.anvil/memory.md` but does not distinguish between these two tiers.
- Workflows as markdown command files: reusable, version-controlled agentic procedures that any developer on the team can invoke. This is a natural fit for Anvil's extension system.
- Terminal context as first-class agent input: last N commands and their output automatically available to the agent without user copy-paste.
- Context window assembly transparency: show the user what went into the current prompt (files loaded, memories retrieved, actions included). Builds trust and lets users prune.

---

### 3. Zed

**What Zed does well**

Zed is the closest architectural peer to Anvil: native, high-performance (120fps, 2.58x better power consumption than VS Code), built from scratch. Zed chose Rust + GPUI rather than Swift + SwiftUI, but the product philosophy is similar — native first, speed as a feature, collaborative from day one.

Zed's inline assistant is the most friction-free AI interaction pattern in the market. Select code, press Ctrl+Enter, type a natural language description, and the selection is rewritten in place. No sidebar, no separate chat, no mode switch. It works in the editor, in text threads, in the rules library, in the channel notes, and in the terminal panel.

The slash command system populates context with precision: /file inserts a file, /tab inserts the current tab's content, /selection inserts current selection. The agent panel is a full text editor that exposes the complete LLM request — no hidden system prompt. The user sees and controls every input that shapes the model's response.

Zed's real-time collaboration uses CRDTs for conflict-free multi-user editing with built-in voice chat and screen sharing. This is a feature Anvil has not prioritized but competitors are using to drive team adoption.

Zed's WASM-based extension system supports a growing ecosystem while keeping extensions native in behavior, not electron mini-apps.

**What Anvil can take**

- Inline assistant pattern (Cmd+K already exists in Anvil — push the friction even lower). The Zed model: selection is implicit context, no preamble needed.
- Full system prompt transparency: show the user exactly what is being sent to the model. Currently Anvil's agents are opaque about the constructed prompt.
- Slash commands for context assembly: /file, /tab, /selection, /diff, /branch, /ticket as explicit context builders in the input bar.
- The "no hidden system prompt" principle: Anvil should expose its context assembly in a collapsible inspector, not hide it.
- WASM-based extension sandbox model is worth studying for AnvilPluginSDK isolation.

---

### 4. Xcode

**What Xcode does well**

Xcode defines the gold standard for native macOS IDE shell patterns. The navigator area (Cmd+1 through Cmd+9) gives stable, keyboard-addressable access to project files, source control, find results, tests, and more. The inspector (Cmd+Opt+0) is structurally tied to selection and changes content based on what is selected. History Inspector shows file commit history inline with the current state. The utility area (bottom panel) is resizable, dismissible, and independent of sidebar state.

Xcode 16's Project Navigator now treats folders as real filesystem folders, not arbitrary groups — a correctness improvement that reduces confusion. The Xcode source control navigator shows branches, remotes, tags, stashes, and working copy changes in a single consolidated view. The jump bar (breadcrumb at top of editor) gives exact file location and symbol position.

The File Inspector shows source control status, encoding, line endings, and git blame inline. The Quick Help Inspector shows API documentation for the selected symbol without leaving the editor.

**What Anvil can take**

- Inspector as a structurally first-class surface with exactly one job: show metadata and secondary actions for the currently selected entity. Anvil's inspector is planned (Cmd+Shift+I) but its behavior and content must be rigorously owned by selection state, not by mode.
- Navigator numbering convention: Cmd+1 through Cmd+N for stable workspace destinations. Anvil currently uses Cmd+1–9 for mode switching; the navigator tabs within each mode should also be numbered.
- History Inspector pattern: file commit history visible in the inspector without leaving the editor. Anvil has git decorations in the editor gutter (#33) but not an inline history view for a selected file.
- Source control navigator as the canonical git surface: branches, remotes, tags, stashes, changes, and history unified in one sidebar section rather than scattered across views.

---

### 5. Linear

**What Linear does well**

Linear's March 2026 UI refresh delivered a calmer, more consistent interface built around information density and keyboard-first interaction. The single-key shortcut scheme is the most copied pattern in developer tools: `c` to create issue, `a` to assign, `l` to add label, `p` to set priority, `f` to filter. `Cmd+K` opens a contextual command surface specific to the selected item — moving an issue, changing assignee, changing status — not a global palette.

Linear's Cycles (sprints) use automated rollover of incomplete issues, velocity tracking, and cycle reports. Issues are the atomic unit and everything else (projects, cycles, views, filters) organizes around them. The board, table, and timeline views are all backed by the same underlying model with no data loss on view switch.

Linear Agent (invoked with `Cmd+J`) handles issue creation, triage, and assignment tasks through a conversational interface. Linear's search is fast, scoped by project/team/cycle, and finds issues by ID, title, description content, and assignee.

**What Anvil can take**

- Contextual `Cmd+K` behavior: the palette should change its contents based on what entity is currently selected, not always show the same global list. Clicking on a ticket, file, session, or PR should make `Cmd+K` surface that entity's relevant actions first.
- Single-key navigation within lists: `j/k` is already in the SPEC. Add single-key actions for the most frequent operations per entity type (assign, change status, add label on tickets; stage, unstage, discard on diff hunks; approve, request changes, merge on PRs).
- Cycle/sprint model with automated rollover: Anvil's Intent mode has cycles (#116 pending) but they need velocity tracking and automated incomplete-issue rollover to match Linear's quality.
- Activity timeline that persists and links related entities: ticket modified → branch created → agent session linked → PR opened → deployed. Linear shows this chain on each issue. Anvil needs it cross-workspace.
- Table view for issues as an alternative to the kanban board, backed by the same data model.

---

### 6. GitHub Copilot + Workspace

**What GitHub does well**

GitHub Copilot code review now runs on an agentic tool-calling architecture (generally available March 2026). The review agent gathers broader repository context — directory structure, code references, related files — and surfaces only meaningful findings rather than high-volume noise. In 71% of reviews, Copilot surfaces actionable feedback; in the remaining 29%, it says nothing rather than generating noise. Findings are clustered by error class to reduce cognitive load. Batch autofixes apply an entire class of suggestions at once.

Copilot coding agent works in a GitHub Actions environment: assign an issue to Copilot, it creates a branch, makes commits, opens a draft PR, and pushes updates as it works. You can track it through agent session logs, leave PR review comments asking for changes, and it picks those up automatically and iterates. Integration with Jira is now in public preview — assign a Jira ticket to Copilot to get a draft PR.

The PR workflow itself is the most mature in the market: suggested changes (edit-in-review that generates a commit suggestion), batch suggestion application, discussion resolution tracking, and review request routing. MCP server support and an extensions ecosystem for Copilot are shipping in 2026.

**What Anvil can take**

- AI review quality bar: surface fewer, higher-quality findings rather than comment noise. Anvil's review mode needs AI review summary generation (#69) that clusters by error class rather than adding per-line noise.
- Batch autofix for review findings: accept an entire category of AI suggestions in one action rather than per-comment.
- Draft PR + agent session log linkage: Anvil has auto-PR from agent session (#261 complete) — close the loop by linking the PR back to the session and showing agent session logs inside the PR detail view.
- Issue-to-PR pipeline that tracks through the entire chain: Jira/Linear issue → agent session → branch → draft PR → review → merge → deploy. Each step linked to the next.
- PR suggested changes pattern: reviewer edits code inline in the diff, proposes it as a commit suggestion that the author can accept with one click.

---

### 7. Raycast

**What Raycast does well**

Raycast is the best-executed command palette ecosystem in the macOS developer market. Its model is: root search surface, focused command views, and a universal action panel accessible on any selected item. Extensions are built with React/TypeScript and published to a 1500+ extension store — the developer barrier to entry is low because the API uses common web technologies.

Raycast AI supports 32+ models from a single interface, including BYOK via OpenRouter (added 2025). Extensions can integrate with AI and be invoked with natural language from the main window. Extensions can chain together as part of workflows. Raycast positions itself as "AI middleware" between the user and the fragmented model/provider world.

The action panel pattern is the key interaction primitive: any selected result exposes a consistent set of actions (primary, secondary) accessible via keyboard, with every action labeled and shortcut-hinted. This makes the tool feel predictable regardless of which extension produced the result.

**What Anvil can take**

- Universal action panel for every entity: every selected item in Anvil (ticket, file, session, branch, PR, deployment, message) should expose a consistent contextual action panel at `Cmd+K` or right-click. The actions change by entity type but the interaction pattern is identical everywhere.
- Extension marketplace quality bar: 1500+ extensions means the SDK and store infrastructure worked. AnvilPluginSDK needs a frictionless publish-and-discover cycle, not just a working SDK.
- AI model routing as a first-class shell primitive: the user should be able to switch providers and models from a consistent top-level selector, not dig into session settings. Raycast's 32-model switcher is a UX benchmark.
- Natural language command invocation: from the Anvil command palette, users should be able to type natural language (not just command names) and have the AI route to the correct command or action.
- Chained workflows from palette: multi-step actions triggered from a single palette entry. For example: "create ticket, open agent, link to branch" as one palette workflow.

---

## Feature Gap Table

The following table covers 60 significant features across all research targets. "Has it" means a working, non-stub implementation exists. "Partial" means the architecture or UI shell exists but the implementation is incomplete or missing real provider integration.

| Feature | Cursor | Windsurf | Zed | Xcode | Linear | GitHub | Raycast | Anvil |
|---|---|---|---|---|---|---|---|---|
| Parallel agent execution (up to 8) | Yes | No | No | No | No | Partial | No | Partial |
| Git worktree per agent session | Yes | No | No | No | No | No | No | Yes |
| Agent management sidebar (first-class) | Yes | Partial | No | No | No | No | No | Partial |
| Subagent dispatch (agents spawn agents) | Yes | No | No | No | No | No | No | No |
| Background agents that auto-open PRs | Yes | No | No | No | No | Yes | No | Partial |
| @ context references (files, symbols, docs, git, web) | Yes | Partial | Partial | No | No | Partial | No | Partial |
| @Recommended auto-context in agent mode | Yes | Yes | No | No | No | No | No | No |
| Real-time action tracking as implicit context | No | Yes | No | No | No | No | No | No |
| Two-tier memory (auto-memories + rules) | Partial | Yes | No | No | No | No | No | Partial |
| Reusable agentic workflows (markdown) | No | Yes | No | No | No | No | No | No |
| Terminal context as first-class agent input | Partial | Yes | Partial | No | No | No | No | No |
| Context assembly transparency (show prompt) | No | Partial | Yes | No | No | No | No | No |
| AI ghost text code completion | Yes | Yes | Yes | Yes | No | Yes | No | No |
| LSP-backed autocomplete and go-to-def | Yes | Yes | Yes | Yes | No | Yes | No | No |
| Inline assistant (select + transform in place) | Yes | Yes | Yes | No | No | Yes | No | Partial |
| Slash commands for context assembly | Yes | No | Yes | No | No | No | No | Partial |
| Multi-file edit with per-file accept/reject | Yes | Yes | No | No | No | No | No | Partial |
| Conversation forking (branch from message) | No | No | No | No | No | No | No | No |
| System prompt editor per session | Partial | No | Partial | No | No | No | No | No |
| Context limit visualization | Yes | No | No | No | No | No | No | Yes |
| AI review with clustering + batch autofix | No | No | No | No | No | Yes | No | No |
| Suggested changes (edit in review = commit suggestion) | No | No | No | No | No | Yes | No | No |
| Real-time collaboration (CRDT multi-user editing) | No | No | Yes | No | No | No | No | No |
| Voice chat + screen sharing | No | No | Yes | No | No | No | No | No |
| Contextual Cmd+K (entity-aware actions) | Partial | No | No | No | Yes | No | Yes | No |
| Single-key shortcut scheme for entities | No | No | No | No | Yes | No | No | No |
| Sprint/cycle with velocity + rollover | No | No | No | No | Yes | No | No | No |
| Activity timeline linking all entities | No | No | No | No | Yes | No | No | No |
| Issue-to-PR-to-deploy linked chain | No | No | No | No | Partial | Yes | No | No |
| PR reviewer auto-assignment (code owners) | No | No | No | Yes | No | Yes | No | No |
| Batch review across multiple PRs | No | No | No | No | No | Partial | No | No |
| Inspector tied to selection (not mode) | No | No | No | Yes | No | No | No | Partial |
| History inspector for selected file | No | No | No | Yes | No | No | No | No |
| Navigator keyboard access (Cmd+1..N) | Partial | Partial | Partial | Yes | No | No | No | Partial |
| Universal entity action panel | No | No | No | No | Yes | No | Yes | No |
| Natural language command invocation | Partial | No | No | No | Yes | No | Yes | No |
| Extension marketplace (1000+ extensions) | No | No | Partial | No | No | No | Yes | Partial |
| AI model routing as top-level selector | Yes | Yes | Partial | No | No | Partial | Yes | Partial |
| Real terminal (PTY) | No | No | Yes | No | No | No | No | No |
| Terminal AI command suggestions | Partial | Yes | No | No | No | No | No | No |
| Database connections (Postgres, SQLite) | No | No | No | No | No | No | No | No |
| ER diagram visualization | No | No | No | No | No | No | No | No |
| Deploy provider integration (real deploys) | No | No | No | No | No | Yes | No | No |
| Deployment history + rollback | No | No | No | No | No | Yes | No | No |
| Preview URL inline browser | No | No | No | No | No | Partial | No | No |
| Source control graph (interactive DAG) | No | No | No | Yes | No | Yes | No | Yes |
| Merge conflict resolution UI | No | No | No | Yes | No | No | No | No |
| Debug variable inspector + call stack | No | No | No | Yes | No | No | No | No |
| Breakpoint management UI | No | No | No | Yes | No | No | No | No |
| Code folding | No | No | Yes | Yes | No | No | No | No |
| Editor minimap | No | No | No | Yes | No | No | No | No |
| Tree-sitter syntax highlighting | No | No | Yes | No | No | No | No | No |
| Multi-cursor editing | No | No | Yes | Yes | No | No | No | No |
| Window layout save + restore | No | No | Partial | Partial | No | No | No | No |
| Multiple window support | No | No | Partial | Yes | No | No | No | No |
| Session search across all conversations | No | Yes | No | No | No | No | No | No |
| Codebase Q&A with file citations | Yes | Yes | Yes | No | No | No | No | Yes |
| Quick capture to ticket conversion | No | No | No | No | Yes | No | Yes | No |
| Native macOS feel (non-Electron) | No | No | Yes | Yes | No | No | Yes | Yes |
| BYOK / multi-provider AI | Yes | Yes | Partial | No | No | Partial | Yes | Partial |

---

## Top 20 Actionable Items Ranked by User Impact

These are ranked by the combination of: frequency of user friction (how often a developer hits this in a typical session), competitive parity urgency (everyone has it), and Anvil's structural readiness (how much work remains).

### Priority 1 — Blocks basic credibility (ship in next 2 weeks)

**1. Real PTY terminal (#6, #25)**
Every competitor that embeds a terminal has a real one. Anvil's terminal is currently non-functional. This blocks any workflow that involves running tests, build commands, git operations, or install scripts inside Anvil. A developer who cannot type a shell command cannot adopt Anvil as their primary environment.
Action: Integrate SwiftTerm or libssh2-based PTY. Wire to AnvilTerminal package. Start with basic zsh, add profiles later.

**2. LSP client for autocomplete and diagnostics (#30, #31, #32)**
AI ghost text is irrelevant if the editor cannot show basic autocomplete, go-to-definition, hover documentation, and error squiggles. Every competitor has this. Anvil's editor without LSP is a text file viewer with syntax coloring — not a code editor.
Action: Implement LSP client protocol in AnvilEditor. Wire to clangd/sourcekit-lsp for Swift/C, typescript-language-server for JS/TS. Surface diagnostics in Problems panel.

**3. Contextual Cmd+K — entity-aware action panel**
Currently Anvil's command palette shows a static list regardless of what is selected. Cursor, Linear, and Raycast all surface context-specific actions when Cmd+K is invoked on a selected entity. This is the single highest-leverage interaction pattern in developer tooling today.
Action: Extend CommandRegistry to accept a `selectedEntity: AnvilEntity?` parameter. Each entity type registers its own action set. Palette filters and ranks by entity context before global commands.

**4. AI ghost text completion (#131)**
Every AI-first editor ships inline completions as the baseline experience. This is the feature that hooks developers during a first session. Without it, Anvil feels like it is behind the curve from the first file open.
Action: Implement completion provider in AnvilACP that returns multi-token continuations. Surface as ghost text via SwiftUI text overlay or CodeMirror WebView extension. Accept with Tab.

### Priority 2 — Core differentiator gaps (ship in next 4 weeks)

**5. Parallel agent launch with agent management sidebar**
Cursor's defining 2025-2026 moment was making parallel agents a first-class UI element. Anvil has background sessions (#60 complete) and worktree engine (#345 complete) but lacks the agent sidebar that makes multiple concurrent agents understandable and manageable. Without the sidebar, parallel agents are invisible, which means users cannot trust or use them.
Action: Build AgentDashboardSidebar: a sorted list of all sessions (running, queued, background, completed). Each row shows name, status indicator, elapsed time, cost so far, and linked files. Tapping a row selects and opens that session. Running sessions pulse. Completed sessions show file diff count.

**6. @Recommended auto-context inference**
Cursor's @Recommended automatically fetches relevant files in agent mode without requiring manual @ specifications. This removes the biggest friction point in agent workflows: the user has to think less about context and more about the task. Anvil has manual @ references (#12 complete) but not automatic inference.
Action: Build a relevance engine in AnvilApplication that scores project files against the current agent session's conversation content. Inject the top-N scoring files as implicit context before each turn. Surface the injected files in a collapsible "Context used" section below the input bar.

**7. Two-tier memory: auto-memories + project rules**
Windsurf's most praised feature is Cascade's memory system. Anvil has `.anvil/memory.md` (session memory, #299 complete) but lacks: (a) auto-generated per-workspace memories from notable session facts, and (b) a user-editable project rules file that is version-controlled and shared with the team.
Action: Create `AnvilRules` concept backed by `.anvil/rules.md` in the repo. Expose in a Rules editor in Library workspace. Auto-generate memory entries when agents make significant architectural decisions (model asks agent to record). Surface active rules and memories in session inspector.

**8. Slash commands for context assembly**
Zed's slash command system (/file, /tab, /selection, /diff) makes context-building explicit and keyboard-driven without requiring @ picker navigation. Anvil has a slash command framework (#11 complete) but context-assembly slash commands are not wired.
Action: Register /file, /tab, /selection, /diff, /branch, /ticket, /error as built-in slash commands that inject the referenced content into the agent's context. Show a preview of what will be injected inline before the message is sent.

**9. Real-time action tracking as implicit context (Windsurf-style)**
Windsurf's most technically ambitious feature: Cascade observes every developer action (file open, edit, terminal command, navigation) and maintains a recency-weighted action log as part of the context assembly. This eliminates "I was just looking at X, why doesn't the agent know that?" friction.
Action: Build an `ActionObserver` in AnvilApplication that records: (a) files opened/edited with timestamps, (b) terminal commands run and their exit codes, (c) navigation changes (current file, current selection). Pass the last 20 actions as implicit context in every agent turn, trimmed to fit the context window.

**10. Session search across all conversations (#48)**
Windsurf surfaces this; it is missing from Anvil. Developers accumulate dozens of agent sessions. Finding a prior session where a specific problem was solved is impossible without search.
Action: Index all session messages and metadata (title, date, linked files, model, status) in a local FTS table (SQLite FTS5). Wire to command palette and to a Sessions search view in the Agent workspace sidebar.

### Priority 3 — Interaction quality and polish (next 6 weeks)

**11. Merge conflict resolution UI (#90)**
Source control without conflict resolution forces developers to leave Anvil for another tool at the most stressful moment of a git workflow. Xcode, GitKraken, and VS Code all have this. It is a retention-killer.
Action: Build a three-panel conflict resolver: base, ours, theirs. Wire to git merge driver via AnvilGit. Surface conflicted files in the Source Control sidebar with a conflict badge. Offer "accept ours / accept theirs / keep both / manual" per conflict block.

**12. Activity timeline linking entities across workspaces**
Linear's issue activity log shows every state change, comment, branch creation, PR link, and deployment. This cross-entity linkage is how Anvil's "never leave" promise gets fulfilled. Currently each workspace is isolated — there is no view that says "here is everything that happened for this work item."
Action: Build an `ActivityTimeline` entity in AnvilDomain. Every domain event (OnTicketStatusChanged, OnAgentCompleted, OnPRMerged, OnBuildFailed, etc.) writes an activity entry linked to the relevant work item. Surface as a scrollable timeline in the inspector when a ticket is selected.

**13. Suggested changes in PR review (#119)**
GitHub's suggested change pattern lets the reviewer propose a specific code edit, which the author can accept with one click as a commit. Without this, Anvil's review comments are advisory only — the author has to manually implement every suggestion.
Action: Add a "Suggest Change" mode to the diff editor inline comment flow. The reviewer edits the right-hand side of the diff; the change is packaged as a suggestion diff in the comment body. The author sees a one-click "Apply suggestion" button that applies the diff as a commit.

**14. Code folding in editor (#40)**
Basic editor quality expectation. Missing from Anvil. Every serious code editor has it. Its absence is a red flag for first-time evaluators.
Action: Implement fold regions based on LSP foldingRange provider. Surface as collapse/expand triangles in the editor gutter. Preserve fold state per file across sessions.

**15. AI review summary generation (#69)**
GitHub Copilot's agentic review clusters findings by error class and generates an overall assessment. Anvil's review mode has no AI assist beyond inline comment generation. A PR summary that highlights the three most important issues before the reviewer reads a single line would be a competitive differentiator.
Action: Build a "Review with AI" button in the PR detail view. Trigger an ACP call that receives the full diff plus linked file context and returns: a summary paragraph, a list of significant findings grouped by type (bug, style, architecture, security), and a recommendation (approve / request changes). Display in the PR inspector.

**16. Terminal AI command suggestions (#127)**
Windsurf (Cascade) and Cursor both offer AI-suggested terminal commands based on the current task context. This converts the terminal from a black box into an AI-assisted shell.
Action: Add a `?` command prefix in Anvil's terminal that opens an inline AI prompt: "what command should I run to...?" The agent returns a shell command with explanation. User can run it with Enter or edit first.

**17. Source control: full unified navigator**
Xcode's source control navigator consolidates branches, remotes, tags, stashes, and working copy changes in one sidebar. Anvil's source control is currently spread across multiple sidebar sections and lacks a single authoritative view.
Action: Build a SourceControlNavigator that matches the Xcode model: Local Changes, Branches, Remotes, Tags, Stash — all in a collapsible source list. Wire to the existing AnvilGit primitives. Git graph (#399 complete) should be accessible from this navigator.

**18. Editor minimap (#53)**
A low-cost feature with high signal value for code navigation in long files. Zed and VS Code both have it. Most developers do not use it constantly but its absence reads as incomplete.
Action: Implement a minimap as a fixed-width right-gutter in the editor showing a scaled-down pixel representation of the entire file. The visible viewport is shown as a highlighted region. Click or drag to jump to position.

**19. Multi-cursor editing (#51)**
Basic editor quality expectation for power users. Missing from Anvil. Zed and VS Code both have it. Required before Anvil can position itself as a primary editor.
Action: Implement multi-cursor via Cmd+Click (add cursor) and Cmd+D (select next occurrence). Each cursor supports independent text insertion, deletion, and movement. Wire to Anvil's editor text engine.

**20. Context assembly transparency**
Zed exposes the full LLM request in the agent panel — no hidden system prompt. Anthropic's Claude Code does the same. Developers who use AI tools daily want to understand why the model made a decision. Hiding the context is a trust deficit.
Action: Add a collapsible "What was sent" section below each agent response. It shows: active rules, injected memories, auto-context files (with scores), slash command contents, and the system prompt. Collapsed by default. Expanded on click. This turns a black box into a debuggable, understandable tool.

---

## UI/UX Patterns to Implement Immediately

These are interaction primitives that cut across multiple features and should be codified as shell-wide rules before more feature work lands.

### Pattern 1: Entity-aware Cmd+K

`Cmd+K` behavior today: opens the global command palette with a static list.

Target behavior: when a ticket is focused, Cmd+K shows ticket actions first (change status, assign, link, open agent). When a file is focused, Cmd+K shows file actions first (open, blame, copy path, find references). When a PR is focused, Cmd+K shows review actions (start review, request changes, approve, open in browser). Global commands appear after entity-specific ones.

Implementation anchor: `CommandRegistry.swift`. Add `func actions(for entity: AnvilEntity) -> [Command]` that each entity type implements.

### Pattern 2: Single-key actions on focused list rows

Linear's single-key shortcut scheme works because the focused row has implicit selection. When a ticket row is focused (not necessarily selected), pressing `a` assigns, `p` sets priority, `l` adds label. This requires no modifier key — the action is scoped to the focused row.

For Anvil: tickets get `a`, `p`, `l`, `e` (edit), `→` (open agent). Files get `o` (open), `b` (blame), `r` (rename). Sessions get `r` (resume), `s` (stop), `x` (cancel). Diff hunks get `↵` (approve), `x` (reject), `c` (comment).

This requires that `KeyEventRouter.swift` understands the concept of a "focused entity type" and routes single-key presses accordingly, only when no text field is focused.

### Pattern 3: Passive background work surfacing

Running background agents, ongoing deploys, and queued CI jobs should surface passively in the status bar — not via modal interruptions. The status bar item should show a compact spinner with a count ("2 running") that expands on click to a list of active background tasks. When one completes, the badge updates and a transient notification appears in the top-right corner (not a modal).

This mirrors VS Code's status bar indicators and avoids the "keep checking the terminal" pattern.

### Pattern 4: Empty states that route forward

Every empty state in Anvil should have exactly one next action. "No provider configured" shows a "Connect provider" button that opens the correct settings pane. "No active agent sessions" shows a "Start session" button. "No tickets in this sprint" shows "Add from backlog." "No deployment history" shows "Configure provider."

Empty states that just say "Nothing here yet" are interaction dead-ends. They should be eliminated systematically before any new feature surface is built.

### Pattern 5: Collapsible context inspection

Agent conversations should show a "Context used" section that lists all files injected, memories retrieved, rules active, and slash command payloads for each turn. Collapsed by default to not clutter the conversation. Expanded by clicking the section header. Syncs with the inspector when the session is selected.

This pattern builds trust with advanced users and makes debugging agent behavior possible without leaving Anvil.

### Pattern 6: Selection survives state changes

Selection state (which session, ticket, file, branch, or PR is selected) must survive: sidebar collapse, inspector toggle, utility deck show/hide, mode switch, and window resize. Currently selection is fragile across these transitions.

Implementation: move selection state into a `SelectionCoordinator` at the AppState level. Each workspace reads from and writes to this coordinator rather than maintaining local `@State` selection variables.

### Pattern 7: Consistent row anatomy

Every sidebar row across all workspaces should follow the same visual grammar:
- Leading: icon (16pt, semantic color) or avatar
- Primary label: truncated, 14pt medium
- Trailing: badge (count or status dot), then optional shortcut hint (only if wired)
- Hover: reveals additional actions (delete, duplicate, pin) as trailing icon buttons
- Selection: system accent fill, not a custom tint

No row should ever show a shortcut hint for a shortcut that is not registered. The UI governance rule from `UI_IMPLEMENTATION_GOVERNANCE.md` already states this — it needs enforcement.

---

## Sources

- [Cursor Features](https://cursor.com/features)
- [Cursor 2.0 Announcement](https://cursor.com/blog/2-0)
- [Cursor Parallel Agents Docs](https://cursor.com/docs/configuration/worktrees)
- [Cursor @ Symbols Overview](https://docs.cursor.com/context/@-symbols/overview)
- [Windsurf Cascade Docs](https://docs.windsurf.com/windsurf/cascade/cascade)
- [Windsurf Memories Docs](https://docs.windsurf.com/windsurf/cascade/memories)
- [Windsurf Review 2026](https://vibecoding.app/blog/windsurf-review)
- [Zed AI Overview](https://zed.dev/docs/ai/overview)
- [Zed Inline Assistant](https://zed.dev/docs/ai/inline-assistant)
- [Zed AI Blog](https://zed.dev/blog/zed-ai)
- [Zed IDE Guide 2026](https://agmazon.com/blog/articles/technology/202603/zed-ide-complete-guide-en.html)
- [GitHub Copilot Code Review Agentic Architecture](https://github.blog/changelog/2026-03-05-copilot-code-review-now-runs-on-an-agentic-architecture/)
- [GitHub Copilot Coding Agent Overview](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)
- [GitHub Copilot Coding Agent GA](https://github.blog/news-insights/product-news/github-copilot-meet-the-new-coding-agent/)
- [Linear UI Refresh March 2026](https://linear.app/changelog/2026-03-12-ui-refresh)
- [Linear Issue Tracking Guide](https://everhour.com/blog/linear-issue-tracking/)
- [Raycast AI](https://www.raycast.com/core-features/ai)
- [Raycast in 2026 Review](https://dev.to/dharanidharan_d_tech/raycast-in-2026-the-mac-launcher-that-replaced-4-apps-in-my-dev-workflow-3pka)
- [Xcode Release Notes 16](https://developer.apple.com/documentation/xcode-release-notes/xcode-16-release-notes)
- [Xcode Source Control Docs](https://developer.apple.com/documentation/xcode/configuring-source-control-in-xcode)
