# Anvil Competitor Gap Analysis

Last updated: 2026-03-29

This document synthesizes fresh competitive research across seven targets — Cursor, Windsurf, Zed, Xcode, Linear, GitHub Copilot, and Raycast — and maps findings directly against Anvil's current capabilities. It is intended to drive concrete prioritization decisions, not to be a catalog of everything every tool does.

Scope: what each competitor does well, what Anvil can steal, a feature gap table, and 10 ranked actionable items.

---

## Q2 2026 Audit Notes

This is a rolling audit. The previous pass (2026-03-28) captured the state of the market as of early 2026. This pass updates each competitor section with what shipped specifically in Q1 2026 (January–March), revises where Anvil leads and lags based on work completed since the last pass, and replaces the 20-item ranking with a tighter 10-item list focused on the highest user-impact / highest-feasibility work remaining.

### Anvil completed since last audit
The following were marked complete between the last audit and this one, moving Anvil's position significantly:

- Parallel agent launch — up to 8 sessions with isolated git worktrees (#56)
- Agent sidebar — native source list with live session state (#40)
- Session search — FTS5 full-text search across agent conversations (#71)
- Auto-context inference — score and inject relevant files per agent turn (#52, #55)
- Two-tier memory — auto-memories and project rules editor (#64)
- Slash commands — /file /tab /selection /diff /branch /ticket context assembly (#57, #60)
- Contextual Cmd+K — entity-aware action panel (#48)
- Background agent auto-PR — completed sessions trigger draft PR creation (#73)
- Subagent tree view — nested agent hierarchy in conversation (#78)
- Conversation forking — branch off any message (#75)
- Merge conflict resolution UI — three-panel resolver (#43)
- Editor minimap (#74)
- LSP: autocomplete, diagnostics, go-to-def, hover (#36, #42, #49, #70)
- Tree-sitter syntax highlighting (#45)
- Real PTY terminal via SwiftTerm (#46)
- Multiple terminal tabs (#51)
- Unified source control navigator (#58)
- Worktree browser in source control navigator (#67)
- Real git operations (#41)
- Unified command registry (#35)
- Git blame annotations (#50)

This is a significant amount of ground covered. The honest ledger below reflects what remains.

---

## Executive Summary

The Q1 2026 competitive landscape has moved decisively toward **event-driven, always-on agents** and **cross-IDE portability**. Cursor shipped Automations (agents that fire on Slack/GitHub/PagerDuty events without human presence), self-hosted cloud agents, and JetBrains integration via ACP. Windsurf shipped Wave 13 (parallel agents with git worktrees, dedicated terminal, Plan Mode, Arena Mode). Zed shipped an agent panel with background execution, the Zeta open-weight edit-prediction model, and joined Cursor in the ACP consortium. GitHub Copilot added semantic code search to the coding agent and reached GA on Copilot CLI.

Anvil's core agent loop is now **competitive on parity features**: parallel sessions, git worktrees, session memory, auto-context, slash commands, session search, and auto-PR. These were the critical gaps six months ago. They are closed.

The remaining gaps are in three categories:

1. **Always-on / event-driven agents** — Cursor Automations has no equivalent in Anvil. This is the biggest competitive differentiator Anvil lacks as of Q2 2026.
2. **Real AI completions** — Ghost text inline completions remain unshipped. Every competitor has this as baseline. Anvil's LSP completions are present but AI-powered ghost text (the Tab-accept experience) is missing.
3. **Cross-IDE portability via ACP** — Cursor and Zed have committed to Agent Client Protocol, meaning their agents work across JetBrains, VS Code, and each other. Anvil is not yet in this ecosystem.

The native macOS positioning remains Anvil's structural moat. Cursor moved into JetBrains (Electron), Windsurf remains Electron, GitHub Copilot lives in VS Code. None of them ship a SwiftUI/AppKit app. That moat only compounds if the app continues to raise its quality floor — currently in progress with the Tahoe native UI pass (#80).

---

## Per-Competitor Analysis

### 1. Cursor

**What shipped in Q1 2026**

**Cursor Automations (March 5, 2026)** is the most significant new capability in the market this quarter. Automations are always-on agents that execute without the developer present, triggered by external events: Slack message, Linear issue creation, GitHub PR open or push, PagerDuty incident, webhook, or a time-based schedule. When triggered, Cursor spins up a cloud sandbox, executes the configured agent instructions with whatever MCPs are configured, optionally reads memory from prior runs to improve over time, and produces output (usually a PR, a Slack reply, or a fix commit). Template use cases: automated PR risk classification and reviewer assignment, incident response (Datadog + codebase investigation → Slack summary + fix PR), bug triage from Slack (duplicate check, Linear issue, root-cause investigation, reply in thread).

**Self-Hosted Cloud Agents (March 25, 2026)**: Organizations can now run agents on internal infrastructure, keeping code and tool execution entirely within their own network. Removes the data-residency objection for enterprise customers.

**JetBrains Integration via ACP (March 4, 2026)**: Cursor is now available in IntelliJ IDEA, PyCharm, and WebStorm through the open Agent Client Protocol. This is a distribution play — developers who use JetBrains get Cursor's models without switching editors.

**Composer 2 / new frontier model (March 19, 2026)**: A new internal model with frontier-level coding performance, tiered pricing (Standard and Fast tiers).

**Expanded Plugin Marketplace (March 11, 2026)**: 30+ new plugins from Atlassian, Datadog, and GitLab containing MCPs that agents invoke automatically within Automations.

**What Cursor does better than Anvil**

- Automations: event-driven always-on agents. Anvil has no equivalent.
- Self-hosted agent infrastructure for enterprise.
- Cross-IDE portability via ACP.
- AI ghost text inline completion (Tab-accept, multi-token prediction). Still missing from Anvil.
- Subagent dispatch tree (agents spawning agents) — Anvil has UI (#78) but the ACP backend is not wired to real models yet (#86 in progress).
- Plugin marketplace ecosystem depth (30+ new plugins in one month alone).

**What Anvil leads on vs Cursor**

- Native macOS app: no Electron, real SwiftUI, Apple Silicon–native performance.
- Conversation forking from any message — Cursor does not have this.
- Three-panel merge conflict resolver — Cursor defers to the terminal.
- Inspector tied to selection state — Cursor's inspector is mode-driven, not selection-driven.

---

### 2. Windsurf (Cognition AI)

**What shipped in Q1 2026**

**Wave 13 (December 2025 / landing in Q1 2026 workflows)**: The headline update shipped parallel agents with git worktrees. Multiple Cascade instances run simultaneously, each on its own branch in a separate worktree. Users view and interact with them in side-by-side panes. A dedicated zsh terminal profile for each agent session improves reliability of command execution. Also shipped: SWE-1.5 Free (near-frontier performance at no charge), context window indicator, Cascade Hooks (pre- and post-action triggers for linters, policy enforcement, custom scripts), Arena Mode (blind A/B model comparison), and Plan Mode (structured task planning before execution).

**Cognition acquisition context**: Cognition AI acquired Windsurf for ~$250M in December 2025. The stated direction is merging Windsurf's IDE capabilities with Devin for fully autonomous workflows. SWE-1 and SWE-1.5 are Windsurf's native models, benchmarked specifically for software engineering tasks.

**What Windsurf does better than Anvil**

- Arena Mode: blind A/B model comparison within the IDE. No equivalent in Anvil.
- Cascade Hooks: pre/post-action policy triggers for team-enforced coding standards. No equivalent in Anvil.
- Plan Mode: structured task plan before agent execution. Anvil has agent plan view in spec (#A-12) but not shipped.
- Context window indicator — Anvil has context limit visualization in spec but unconfirmed as shipped.
- Real-time developer action tracking — Windsurf tracks every file open, edit, and terminal command as implicit agent context. Anvil has ActionObserver in spec (A-08) but it is not yet shipped.
- SWE-specialized models: SWE-1 and SWE-1.5 are trained specifically for coding agent tasks.

**What Anvil leads on vs Windsurf**

- Native macOS app vs Electron.
- Conversation forking.
- Merge conflict resolver.
- Selection-driven inspector.
- Worktree browser with native source list integration.

---

### 3. Zed

**What shipped in Q1 2026**

**Agent Panel with background execution (shipped as "agentic mode beta")**: Zed's agent panel lets the agent edit multiple files, run terminal commands, search the codebase, access LSP diagnostics, and run in the background. Users are notified on completion. The panel exposes full system prompt transparency — no hidden context.

**Zeta / Zeta2 open-weight edit prediction model**: Zed's own open-source model predicts the next edit the developer will make, beyond simple token completion. Zeta2 powers "Edit Prediction" — intent-level prediction rather than character-level autocomplete.

**ACP participation (January 2026)**: Zed and JetBrains jointly announced the Agent Client Protocol, an open standard for AI agents to work across editors. Zed is both implementing ACP and co-authoring the spec.

**Dev Containers support**: Full support for development containers, closing a gap vs VS Code.

**What Zed does better than Anvil**

- Edit Prediction (Zeta2): predicts the developer's next edit intent, not just the next tokens. Higher signal than ghost text.
- ACP participation: Zed's agents can interoperate with other ACP-compatible tooling.
- Full system prompt transparency: the agent panel exposes the complete LLM request, no hidden system prompt. Anvil has context assembly transparency in spec (A-06) but not shipped.
- Real-time CRDT collaboration: multi-user simultaneous editing with built-in voice chat. No equivalent in Anvil.
- WASM extension sandbox: safe, native-behavior extensions without the Electron mini-app pattern.
- 120fps native rendering: Zed's GPUI achieves 120fps on Apple Silicon. Anvil should match this with SwiftUI.

**What Anvil leads on vs Zed**

- macOS-native app (SwiftUI vs GPUI/Rust — both are native, but SwiftUI integrates with macOS system APIs more deeply).
- Full agent session management with worktrees, parallel launch, sidebar, and auto-PR.
- Intent/project management integration in the same app.
- Review workspace with diff inspector and inline comments.

---

### 4. GitHub Copilot + Codex CLI

**What shipped in Q1 2026**

**Copilot CLI GA (February 25, 2026)**: The terminal-native coding agent reached general availability for all Copilot subscribers. It can plan, build, review, and remember across sessions. Key modes: Plan Mode (Shift+Tab to plan before building), Autopilot Mode (fully autonomous execution). Ships with GitHub's MCP server built in, supports custom MCP servers, and supports markdown-based Skill Files that load automatically when relevant.

**GPT-5.3-Codex GA (February 9, 2026)**: 25% faster than GPT-5.2-Codex on agentic coding tasks. Long-term support announced March 18.

**Claude + Codex agents in Copilot Business/Pro (February 26, 2026)**: Anthropic Claude and OpenAI Codex are now available as distinct coding agent flavors within the GitHub Copilot interface. Users can run Claude Opus 4.6, Claude Sonnet 4.6, GPT-5.3-Codex, or Gemini 3 Pro within GitHub workflows.

**Semantic code search for coding agent (March 17, 2026)**: The coding agent now searches by meaning rather than text match, improving its ability to find relevant context in large repos.

**Agentic code review linking to coding agent**: Code review findings can now be passed directly to the coding agent to generate fix PRs automatically. Review-to-fix pipeline is closed.

**What GitHub Copilot does better than Anvil**

- Skill Files: versioned, markdown-based procedural skills that load automatically when relevant. More composable than Anvil's rules system.
- Copilot CLI: terminal-native agentic coding without an IDE at all. Different use case but real competition for terminal-first developers.
- Review-to-fix pipeline: AI review finding → coding agent → fix PR → auto-merged. End-to-end.
- PR suggested changes (edit in review = commit suggestion). Not yet in Anvil.
- AI review with error-class clustering and batch autofixes.
- The deepest GitHub integration in the market — webhooks, Actions, MCP, issue tracker all first-party.

**What Anvil leads on vs GitHub Copilot**

- Native macOS app (vs VS Code + Electron).
- Intent workspace as a first-class space, not a sidebar on top of GitHub Issues.
- Agent sessions with conversation history, forking, and memory.
- Parallel agents with git worktrees (GitHub Copilot runs one agent in GitHub Actions at a time).

---

### 5. Xcode

No significant new AI-related features shipped in Q1 2026. Xcode 16 remains the baseline. The core Xcode advantages (navigator numbering, inspector tied to selection, source control navigator, debug inspector) are unchanged. The Quick Help inspector and History inspector remain models to emulate.

**Anvil leads on vs Xcode**: Every AI feature. Xcode has no AI agent, no LLM integration, no session memory, no parallel agents.

---

### 6. Linear

The March 2026 UI refresh (changelog 2026-03-12) delivered calmer, more consistent UI focused on information density and keyboard-first interaction. No major new feature surface — primarily polish and consistency improvements. Linear's structural advantages (single-key shortcuts, contextual Cmd+K, activity timeline, cycles with velocity and rollover) are unchanged.

---

### 7. Raycast

No significant Q1 2026 feature releases warranting revision from the prior audit. The universal action panel model, 32-model AI switcher, and 1500+ extension ecosystem remain the reference points. BYOK via OpenRouter (2025) is stable.

---

## Feature Gap Table

The following table covers 60 significant features across all research targets. Status reflects the state as of 2026-03-29. "Yes" means a working, non-stub implementation exists. "Partial" means the architecture exists but implementation is incomplete or missing real provider integration.

| Feature | Cursor | Windsurf | Zed | Xcode | Linear | GitHub | Raycast | Anvil |
|---|---|---|---|---|---|---|---|---|
| Parallel agent execution (up to 8) | Yes | Yes | No | No | No | No | No | Yes |
| Git worktree per agent session | Yes | Yes | No | No | No | No | No | Yes |
| Agent management sidebar (first-class) | Yes | Yes | No | No | No | No | No | Yes |
| Subagent dispatch (agents spawn agents) | Yes | No | No | No | No | No | No | Partial |
| Background agents that auto-open PRs | Yes | No | No | No | No | Yes | No | Yes |
| Always-on event-triggered agents (Automations) | Yes | No | No | No | No | No | No | No |
| Self-hosted cloud agent infrastructure | Yes | No | No | No | No | No | No | No |
| @ context references (files, symbols, docs, git, web) | Yes | Partial | Partial | No | No | Partial | No | Yes |
| @Recommended auto-context in agent mode | Yes | Yes | No | No | No | No | No | Yes |
| Real-time action tracking as implicit context | No | Yes | No | No | No | No | No | No |
| Two-tier memory (auto-memories + rules) | Partial | Yes | No | No | No | No | No | Yes |
| Skill files / reusable agentic workflows (markdown) | No | Yes | No | No | No | Yes | No | Partial |
| Terminal context as first-class agent input | Partial | Yes | Partial | No | No | No | No | No |
| Context assembly transparency (show prompt) | No | Partial | Yes | No | No | No | No | No |
| AI ghost text code completion (Tab-accept) | Yes | Yes | Yes | Yes | No | Yes | No | No |
| Edit prediction (intent-level, beyond token completion) | No | No | Yes | No | No | No | No | No |
| LSP-backed autocomplete and go-to-def | Yes | Yes | Yes | Yes | No | Yes | No | Yes |
| Inline assistant (select + transform in place) | Yes | Yes | Yes | No | No | Yes | No | Partial |
| Slash commands for context assembly | Yes | No | Yes | No | No | No | No | Yes |
| Multi-file edit with per-file accept/reject | Yes | Yes | No | No | No | No | No | Partial |
| Conversation forking (branch from message) | No | No | No | No | No | No | No | Yes |
| Session search across all conversations | No | Yes | No | No | No | No | No | Yes |
| System prompt editor per session | Partial | No | Yes | No | No | No | No | No |
| Context limit visualization | Yes | Yes | No | No | No | No | No | Partial |
| Agent Client Protocol (ACP) integration | Yes | No | Yes | No | No | No | No | No |
| AI review with clustering + batch autofix | No | No | No | No | No | Yes | No | No |
| Review-to-fix agent pipeline | No | No | No | No | No | Yes | No | No |
| Suggested changes (edit in review = commit suggestion) | No | No | No | No | No | Yes | No | No |
| Plan Mode (structured plan before execution) | Partial | Yes | No | No | No | Yes | No | No |
| Arena Mode (blind A/B model comparison) | No | Yes | No | No | No | No | No | No |
| Agent hooks (pre/post action triggers) | No | Yes | No | No | No | No | No | No |
| Real-time collaboration (CRDT multi-user editing) | No | No | Yes | No | No | No | No | No |
| Contextual Cmd+K (entity-aware actions) | Partial | No | No | No | Yes | No | Yes | Yes |
| Single-key shortcut scheme for entities | No | No | No | No | Yes | No | No | No |
| Sprint/cycle with velocity + rollover | No | No | No | No | Yes | No | No | No |
| Activity timeline linking all entities | No | No | No | No | Yes | No | No | No |
| Issue-to-PR-to-deploy linked chain | No | No | No | No | Partial | Yes | No | No |
| PR reviewer auto-assignment (code owners) | No | No | No | Yes | No | Yes | No | No |
| Inspector tied to selection (not mode) | No | No | No | Yes | No | No | No | Partial |
| History inspector for selected file | No | No | No | Yes | No | No | No | No |
| Navigator keyboard access (Cmd+1..N) | Partial | Partial | Partial | Yes | No | No | No | Partial |
| Universal entity action panel | No | No | No | No | Yes | No | Yes | Partial |
| Natural language command invocation | Partial | No | No | No | Yes | No | Yes | No |
| Extension marketplace (100+ extensions) | Yes | No | Partial | No | No | No | Yes | Partial |
| AI model routing as top-level selector | Yes | Yes | Partial | No | No | Partial | Yes | Partial |
| Real terminal (PTY) | No | No | Yes | No | No | No | No | Yes |
| Terminal AI command suggestions | Partial | Yes | No | No | No | No | No | No |
| Database connections (Postgres, SQLite) | No | No | No | No | No | No | No | No |
| Deploy provider integration (real deploys) | No | No | No | No | No | Yes | No | Partial |
| Source control graph (interactive DAG) | No | No | No | Yes | No | Yes | No | Yes |
| Merge conflict resolution UI | No | No | No | Yes | No | No | No | Yes |
| Debug variable inspector + call stack | No | No | No | Yes | No | No | No | No |
| Code folding | No | No | Yes | Yes | No | No | No | No |
| Editor minimap | No | No | No | Yes | No | No | No | Yes |
| Tree-sitter syntax highlighting | No | No | Yes | No | No | No | No | Yes |
| Multi-cursor editing | No | No | Yes | Yes | No | No | No | No |
| Session search across all conversations | No | Yes | No | No | No | No | No | Yes |
| Codebase Q&A with file citations | Yes | Yes | Yes | No | No | No | No | Yes |
| Quick capture to ticket conversion | No | No | No | No | Yes | No | Yes | No |
| Native macOS feel (non-Electron) | No | No | Yes | Yes | No | No | Yes | Yes |
| BYOK / multi-provider AI | Yes | Yes | Partial | No | No | Partial | Yes | Partial |

---

## Where Anvil Leads (Honest Assessment)

As of Q2 2026, Anvil genuinely leads or is competitive in the following areas:

**Agent infrastructure**: Parallel sessions with git worktrees, agent sidebar, auto-PR, conversation forking, subagent UI, session memory, auto-context inference, slash commands, session search via FTS5. This is now a full, honest feature set that matches or exceeds Cursor's baseline agent experience (excluding Automations).

**Native macOS quality**: No competitor ships a SwiftUI/AppKit native application. This is a structural advantage that compounds with every Tahoe UI improvement. Zed is native (Rust/GPUI) but not SwiftUI — it does not benefit from macOS system API integration depth.

**Source control UX**: Unified source control navigator, worktree browser, merge conflict resolver, git blame annotations, interactive DAG, and inline diff comments are all shipped. This exceeds what Cursor and Windsurf offer natively (both defer heavily to terminal-level git).

**Conversation forking**: Unique to Anvil. No other tool in this audit has shipped the ability to branch a new agent session from any message in an existing session. This is a high-value research and exploration feature.

**Merge conflict resolution**: Three-panel resolver within the IDE. Cursor and Windsurf do not have this — they push users to the terminal or an external tool.

---

## Where Anvil Lags (Honest Assessment)

**Critical gaps (blocks adoption):**

- **AI ghost text completion** — Tab-accept inline AI completions are missing. This is the feature developers evaluate in the first five minutes. LSP completions are present, but AI-powered multi-token ghost text (Copilot-style) is absent.
- **Real ACP provider** — AnvilACP is not wired to real Claude/GPT models yet (#86 in progress). Agents are running against stub/mock implementations. This is the highest-priority in-flight work.

**Significant gaps (erodes differentiation):**

- **Always-on event-triggered agents (Automations)** — No equivalent. Cursor has had this since March 5, 2026. This is the next frontier of agentic IDE capability and Anvil has nothing planned.
- **Real-time action tracking as implicit context** — Windsurf's Cascade watches every developer action (file opens, edits, terminal commands) as automatic context. Anvil has this in spec (A-08: ActionObserver) but it is unshipped.
- **Context assembly transparency** — Zed shows the full LLM request; Anvil hides it. Trust deficit.
- **Plan Mode** — Structured plan-before-execution that the user can review and edit before the agent starts working. Windsurf and Copilot CLI both have it.
- **ACP participation** — Cursor and Zed have committed to the open Agent Client Protocol. Anvil is not in this ecosystem. Risk: the ACP standard becomes the interoperability layer and Anvil is locked out.
- **Agent hooks** — Windsurf's Cascade Hooks (pre/post-action triggers) enable team-level policy enforcement. No equivalent in Anvil.

**Quality gaps (important for power users):**

- **Multi-cursor editing** — Still unshipped. Every serious code editor has this.
- **Code folding** — Still unshipped. Basic editor expectation.
- **System prompt editor per session** — Zed exposes this; Anvil hides it.
- **Context assembly transparency** — Show the user what went into the prompt.
- **Debug inspector + breakpoints** — Xcode gold standard; Anvil has nothing planned.

---

## Top 10 Highest-Impact Features to Close the Gap

Ranked by user impact × feasibility. User impact = how frequently a developer hits this in a typical session × how likely it is to drive adoption or retention. Feasibility = assessed implementation effort given Anvil's current architecture.

---

### 1. AI Ghost Text Completion (Tab-accept)
**Why it matters**: This is the single feature developers evaluate in the first five minutes of trying an AI IDE. Every competitor has it as a baseline experience. Without it, Anvil's AI credentials are invisible during evaluation. A developer who opens a file and sees no ghost text will assume the AI is broken, regardless of the sophistication of the agent session layer.

**Gap vs competition**: Every competitor has this. Anvil does not.

**Feasibility**: AnvilACP already defines a completion provider protocol. Once the real ACP provider is wired (#86), ghost text is the next surface to light up. Estimated medium complexity (the protocol exists, the rendering layer needs the ghost text overlay).

**What to build**: Completion provider in AnvilACP returning multi-token continuations. Ghost text rendered as grayed overlay text in the editor at cursor position. Tab accepts; Escape dismisses; any non-Tab keystroke rejects. Wire through the existing LSP/ACP layering.

---

### 2. Wire Real ACP Provider (Claude + GPT models)
**Why it matters**: All agent features currently run against stub implementations. The entire agent session layer — parallel sessions, conversation forking, auto-PR, subagent dispatch — is UI-only until real models are wired. This is not a feature gap; it is the thing that makes all other features real.

**Gap vs competition**: Every competitor ships against live models. Anvil does not yet.

**Feasibility**: In progress (#86). The ACP protocol is defined. The work is implementing the HTTP client against the Anthropic and OpenAI APIs, handling streaming, and wiring through the existing AgentSession use case layer. High priority, in-flight.

**What to build**: AnthropicACPProvider and OpenAIACPProvider implementing the AnvilACP protocol. Streaming responses via AsyncStream. Model selection in session inspector. Error handling with retry. API key configuration in settings (#87, also in progress).

---

### 3. Always-On Event-Triggered Agents (Automations)
**Why it matters**: Cursor Automations (March 2026) represents the next frontier of agentic IDE capability — agents that fire without the developer present, triggered by GitHub events, Slack messages, PagerDuty incidents, or schedules. This is how Cursor justifies enterprise adoption: it replaces on-call triage workflows, automates PR classification, and handles bug reports end-to-end. No other competitor has matched this yet. Anvil has time to ship a competitive version before the market standardizes on Cursor's implementation.

**Gap vs competition**: Only Cursor has this. This is a genuine opportunity to leapfrog rather than catch up.

**Feasibility**: Medium-high complexity. Requires: an event trigger model (webhook receiver or polling adapters for GitHub, Linear, Slack), an agent schedule model, cloud sandbox or local sandbox execution, and a UI for configuring and monitoring automations. The agent session infrastructure already exists. The gap is the trigger layer and the execution environment for headless runs.

**What to build**: `AnvilAutomations` workspace (or section within Agent workspace). Trigger types: GitHub PR event, Linear issue created, time-based schedule, webhook. Each automation has: trigger config, instruction text, model/provider selection, MCP tool config, output config (PR, Slack message, comment). Automation run history shows outcome per trigger. Background execution reuses existing AgentSession infrastructure.

---

### 4. Real-Time Action Tracking as Implicit Context (ActionObserver)
**Why it matters**: Windsurf's most-praised feature is that Cascade "already knows what you're doing" without you telling it. Developers who switch from Windsurf to Anvil immediately notice that Anvil's agents don't know what files are open or what commands they just ran. This is a significant friction difference in daily use.

**Gap vs competition**: Windsurf has it; Cursor has partial (open files). Anvil has it in spec (A-08) but unshipped.

**Feasibility**: Medium complexity. The observation hooks already exist in SwiftUI (file open events, terminal command events, navigation events). The implementation is: record these events in a lightweight ring buffer in AnvilApplication, inject the last N events as implicit context in every agent turn, show them in the collapsible "Context used" section.

**What to build**: `ActionObserver` service in AnvilApplication. Records: files opened/closed with timestamps, terminal commands executed and exit codes, editor navigation changes (current file + line). Passes last 20 actions as implicit context prefix in every AgentSession turn, trimmed to fit context window. Surfaced in the context inspector per turn.

---

### 5. Plan Mode — Structured Plan Before Execution
**Why it matters**: Both Windsurf and Copilot CLI have shipped Plan Mode: the agent produces a structured, editable implementation plan before writing code. Developers have learned to expect this in 2026. Without it, Anvil's agents feel more opaque — they just start working with no preview of what they are about to do.

**Gap vs competition**: Windsurf, Copilot CLI, and partially Cursor all have this. Anvil does not.

**Feasibility**: Medium complexity. The agent session view already shows conversation flow. Plan Mode adds a distinct "plan" turn type: the agent produces a structured task list, the user can edit/approve/reject individual steps, and execution begins only after approval. Maps naturally onto the existing AgentSession turn model.

**What to build**: Agent session setting: `executionMode = .plan | .direct`. In plan mode, the first agent response is rendered as a structured editable checklist (not raw markdown). Each step can be toggled, reordered, or deleted. A "Run Plan" button kicks off execution. During execution, each step is checked off as it completes.

---

### 6. Context Assembly Transparency
**Why it matters**: Zed exposes the full LLM request in the agent panel. Anthropic's own Claude Code does the same. Developers who use AI tools daily want to understand why the model made a decision. Opaque context is a trust deficit, especially when agents make mistakes. This is also a direct differentiator vs Cursor (which does not show context assembly).

**Gap vs competition**: Zed has it; no one else does. Anvil can lead Cursor on this.

**Feasibility**: Low-medium complexity. The context assembly already happens in AnvilApplication before each turn. The work is persisting the assembled context alongside the turn and surfacing it in a collapsible UI section in the conversation view.

**What to build**: Add `contextSnapshot: ContextSnapshot` to each `AgentTurn` model. ContextSnapshot contains: active rules, injected memories, auto-context files (with relevance scores), slash command payloads, action observer snapshot, system prompt text. Render as a collapsible "What was sent" section below each response. Collapsed by default, single click to expand. This turns debugging from impossible to trivial.

---

### 7. Agent Hooks (Pre/Post Action Policy Triggers)
**Why it matters**: Windsurf's Cascade Hooks enable teams to enforce coding standards automatically — run a linter before the agent commits, block prompts that violate policy, run custom scripts after each action. This is an enterprise adoption lever. Teams that want to adopt Anvil broadly need a mechanism to enforce conventions without relying on the developer remembering to follow them.

**Gap vs competition**: Only Windsurf has this as a first-class feature. Opportunity for Anvil to match or exceed.

**Feasibility**: Medium complexity. Fits naturally as a layer in the AnvilACP dispatch pipeline — before tool invocation, after tool completion, before commit, after PR creation. Rules are markdown-configured in `.anvil/hooks.md` or the Rules editor.

**What to build**: `AgentHook` value object in AnvilDomain with `trigger: HookTrigger` (before_tool_call, after_tool_call, before_commit, after_commit, on_prompt) and `action: HookAction` (run_shell_command, validate_with_linter, block_with_message, log_to_file). Hook configuration in the Rules editor alongside project rules. Hook execution in the ACP dispatch pipeline.

---

### 8. Multi-Cursor Editing
**Why it matters**: This is a baseline editor capability that power users rely on daily. Developers who use VS Code, Zed, or Xcode expect Cmd+Click to add a cursor and Cmd+D to select the next occurrence. Its absence is noticed immediately and reads as an incomplete editor.

**Gap vs competition**: Zed, VS Code, Xcode all have this. Anvil does not.

**Feasibility**: Medium complexity. Requires the editor text model to support multiple cursor positions, each with independent insertion, deletion, and movement. Most of the rendering complexity is in keeping the cursor views synchronized.

**What to build**: `MultiCursorManager` in AnvilEditor. Cmd+Click adds a cursor at the clicked position. Cmd+D selects the next occurrence of the current selection and adds a cursor there. All active cursors receive the same keystrokes. Escape collapses back to single cursor. Render each additional cursor as a secondary blinking caret.

---

### 9. Code Folding
**Why it matters**: Another baseline editor capability. Developers working in large files collapse functions, classes, and import blocks to reduce cognitive load. Its absence is a red flag for first-time evaluators and a daily friction for power users.

**Gap vs competition**: Zed, VS Code, Xcode all have this. Anvil does not.

**Feasibility**: Medium complexity. The LSP client already implements the foldingRange provider (E-09 in task registry). The work is rendering collapse/expand triangles in the gutter and managing fold state per file.

**What to build**: Wire LSP `textDocument/foldingRange` response to the editor gutter as collapse triangles. Clicking a triangle toggles the fold. Preserve fold state in the editor document model (per file, per session). Folded regions render as a single line with an indicator (e.g., `{ ... }` in muted color). Cmd+Opt+[ / ] to fold/unfold current level.

---

### 10. ACP Participation (Agent Client Protocol)
**Why it matters**: Cursor and Zed have jointly committed to ACP as an open standard for AI agents across editors. If ACP gains traction, agents built for the ACP ecosystem will be marketable as "works in Cursor, Zed, and Anvil." If Anvil is not in the ACP ecosystem, it misses that developer distribution channel. This is low urgency today but high strategic risk over 6–12 months.

**Gap vs competition**: Cursor (launched it), Zed (co-authored it). JetBrains participating. Anvil not present.

**Feasibility**: Lower complexity than it appears. ACP is a protocol specification — adding an ACP adapter layer on top of AnvilACP's existing protocol abstractions is an incremental addition. The larger work is the partnership/visibility investment to be recognized as a compatible tool.

**What to build**: Implement the ACP server endpoint in AnvilACP so that external ACP-compatible clients can dispatch agent sessions to Anvil. Publish Anvil's ACP compatibility on the project site. Engage with the ACP working group. Over time, Anvil's agent infrastructure (worktrees, session memory, parallel execution) becomes a selling point in the ACP ecosystem.

---

## UI/UX Patterns to Implement Immediately

These are interaction primitives that cut across multiple features and should be codified as shell-wide rules before more feature work lands. These have not changed from the prior audit.

### Pattern 1: Entity-aware Cmd+K
Cmd+K is now shipped (#48). The pattern must be maintained as new entity types are added — each new entity type must register its contextual actions in CommandRegistry before the UI is built.

### Pattern 2: Single-key actions on focused list rows
Tickets: `a` assign, `p` priority, `l` label, `e` edit, `→` open agent. Files: `o` open, `b` blame, `r` rename. Sessions: `r` resume, `s` stop, `x` cancel. Diff hunks: `↵` approve, `x` reject, `c` comment. Requires `KeyEventRouter.swift` to understand the focused entity type. Single-key presses must only fire when no text field is focused.

### Pattern 3: Passive background work surfacing
Status bar item shows compact spinner with count ("2 running") expanding on click to a list of active background tasks. Transient top-right notification on completion. No modal interruptions.

### Pattern 4: Empty states that route forward
Every empty state has exactly one next action. "No provider configured" → "Connect provider" button. "No active sessions" → "Start session" button. Zero dead-end empty states.

### Pattern 5: Collapsible context inspection
Each agent turn gets a "Context used" section. Collapsed by default. Expanded by clicking. See item #6 above.

### Pattern 6: Selection survives state changes
Selection state must survive sidebar collapse, inspector toggle, utility deck toggle, mode switch, and window resize. Move selection state into `SelectionCoordinator` at AppState level.

### Pattern 7: Consistent row anatomy
Leading icon (16pt, semantic color) | Primary label (truncated, 14pt medium) | Trailing badge + optional shortcut hint (only if wired) | Hover reveals delete/duplicate/pin. Selection uses system accent fill. No shortcut hints for unwired shortcuts.

---

## Sources

- [Cursor Automations Blog](https://cursor.com/blog/automations)
- [Cursor Changelog — March 2026](https://cursor.com/changelog/03-05-26)
- [Cursor Changelog (latest)](https://cursor.com/changelog)
- [Cursor March 2026 Updates: JetBrains, Plugins, and Agent Improvements](https://theagencyjournal.com/cursors-march-2026-updates-jetbrains-integration-and-smarter-agents/)
- [TechCrunch: Cursor Automations](https://techcrunch.com/2026/03/05/cursor-is-rolling-out-a-new-system-for-agentic-coding/)
- [Windsurf Wave 13: Shipmas Edition](https://windsurf.com/blog/windsurf-wave-13)
- [Windsurf Wave 13: Neowin coverage](https://www.neowin.net/news/windsurf-wave-13-introduces-the-new-swe-15-model-and-git-worktrees/)
- [Cognition AI acquisition of Windsurf](https://cognition.ai/blog/windsurf)
- [Zed — Agentic Editing](https://zed.dev/agentic)
- [Zed AI Overview](https://zed.dev/docs/ai/overview)
- [Zed: Fastest AI Code Editor blog](https://zed.dev/blog/fastest-ai-code-editor)
- [Zed IDE Complete Guide 2026](https://agmazon.com/blog/articles/technology/202603/zed-ide-complete-guide-en.html)
- [Is Zed ready for AI power users in 2026?](https://www.builder.io/blog/zed-ai-2026)
- [GitHub Copilot Coding Agent — GA announcement](https://github.blog/news-insights/product-news/github-copilot-meet-the-new-coding-agent/)
- [GitHub Copilot CLI GA — February 2026](https://github.blog/changelog/2026-02-25-github-copilot-cli-is-now-generally-available/)
- [GitHub Copilot CLI: Plan before you build](https://github.blog/changelog/2026-01-21-github-copilot-cli-plan-before-you-build-steer-as-you-go/)
- [GPT-5.3-Codex GA for GitHub Copilot](https://github.blog/changelog/2026-02-09-gpt-5-3-codex-is-now-generally-available-for-github-copilot/)
- [Copilot coding agent: semantic code search](https://github.blog/changelog/2026-03-17-copilot-coding-agent-works-faster-with-semantic-code-search/)
- [Claude and Codex available for Copilot Business/Pro](https://github.blog/changelog/2026-02-26-claude-and-codex-now-available-for-copilot-business-pro-users/)
- [Copilot Code Review agentic architecture](https://github.blog/changelog/2026-03-05-copilot-code-review-now-runs-on-an-agentic-architecture/)
- [GitHub Copilot 2026: Complete Guide](https://www.nxcode.io/resources/news/github-copilot-complete-guide-2026-features-pricing-agents)
- [Linear UI Refresh March 2026](https://linear.app/changelog/2026-03-12-ui-refresh)
- [Raycast AI](https://www.raycast.com/core-features/ai)
- [Xcode 16 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-16-release-notes)
