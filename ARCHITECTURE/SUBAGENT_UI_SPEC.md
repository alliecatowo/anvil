# Subagent UI Specification

Last updated: 2026-03-28

This document specifies the visual design and interaction model for displaying subagent hierarchies and agent team management in Anvil. It covers two distinct surfaces: (1) the in-conversation subagent tree view that makes dispatched agent work visible, and (2) the team management panel that gives operators a roster-level view of all declared agents.

---

## Tahoe Aesthetic Compliance

All UI in this spec must satisfy the mandatory **macOS Tahoe Aesthetic** standard defined in `CLAUDE.md`. Key constraints that directly affect this feature:

| Rule | Application here |
|---|---|
| `.glassEffect(.regular)` on cards/overlays (macOS 26) | Subagent block backgrounds |
| `.ultraThinMaterial` on panels (macOS 15–25 fallback) | Subagent block backgrounds + inspector panel |
| No custom `ZStack + RoundedRectangle + .fill` buttons | All action buttons use `.bordered` / `.plain` |
| `.sidebar` list style for sidebar lists | Agent session sidebar only |
| `.inset` list style for content-area lists | Team management roster (lives in inspector) |
| No `alternatesRowBackgrounds: true` | Roster rows — no stripe pattern |
| No `frame(minHeight:)` on List/Table | Roster — do not constrain minimum height |
| `scaleEffect` + `opacity` loop for pulse indicators | Running state badge — no spinner |
| `withAnimation(.spring(response: 0.3, dampingFraction: 0.8))` | All state transitions |
| `Color.accentColor` for interactive elements | Action buttons (Stop, Assign) |
| System semantic colors only | Status colors — no hardcoded hex |
| `.monospacedDigit` for numbers | Elapsed time, cost, token counts |

---

## Background and Research

### Claude Code

Claude Code's subagent model is the primary reference implementation. Each subagent invocation appears in the conversation as a collapsible tool call block. The collapsed state shows the agent type name and a summary of the returned result. The expanded state exposes the full agent conversation: the delegated prompt, every tool call the subagent made, and the final return value.

Key observations:
- Subagents are collapsed by default to protect the main conversation's visual signal
- The color chip assigned per agent (configurable) distinguishes concurrent agents at a glance
- Agent type labels ("Explore", "Plan", "general-purpose") appear in the block header
- Background agents run concurrently while the parent continues; status is shown in a status bar chip
- Sub-subagents are not permitted (depth-1 only) in the current Claude Code model, but the visual language is designed to accommodate depth-2 for teams

### Xcode Build Log

Xcode's build log activity viewer is the best macOS precedent for hierarchical process display. Relevant patterns:
- Build phases appear as disclosure rows with a leading triangle and phase name
- Parallel tasks are not shown simultaneously scrolling — each target/phase is a separate collapsible group
- Status indicators: spinning progress indicator during execution; green checkmark on success; red badge with count on failure
- The log does not animate rows in or out while running — it appends sequentially and scrolls to the tail
- Individual compiler invocations are nested under the compile phase as child rows
- The "Build Succeeded" / "Build Failed" header at the top summarizes the tree before any details are read

Xcode's model maps cleanly to agent execution trees: replace "Target" with "Session", "Build Phase" with "Agent dispatch", and "Compiler invocation" with "Tool call".

### OpenAI Codex

Codex runs subagent workflows by spawning specialized agents in parallel, then collecting results. Subagents use path-based readable addresses (`/root/agent_a`) for structured inter-agent messaging. The UI surfaces parallel sessions with title labels to distinguish them. The spawn_agents_on_csv pattern — one worker per row, all run in parallel, results aggregated — is the canonical team pattern. Per-session visibility is available via agent session logs accessible from the PR or task view.

Key takeaway: path-based addressing is the right mental model for teams. Each agent has a stable, readable identity that can appear in log lines, status bars, and cross-links.

### Linear Sub-Issues

Linear's sub-issue model drives the rollup design:
- Parent issue shows a progress pill summarizing children (e.g., "3/7 done")
- Children are listed under the parent in an indented tree — clicking opens the child without losing parent context via a slide-out panel
- Completion of a child auto-updates the parent progress
- The "Parent issue" field enables views grouped by parent, making the hierarchy navigable from any direction

For agent teams, the analogous rollup is: parent task shows total subtask completion, each team member's assignment visible at a glance, completion cascades upward.

---

## Surface 1: Subagent Tree View (In-Conversation)

### Purpose

When the active session dispatches one or more subagents (via the Agent tool), those dispatches appear inline in the conversation as structured, collapsible tree nodes. The tree makes parallel work legible without overwhelming the conversation.

### Visual Structure

Each subagent dispatch renders as a block within the message stream, structurally similar to how tool calls are rendered today but with richer internal structure.

```
┌─────────────────────────────────────────────────────────────────┐
│ ▶  researcher    running    0.4s    $0.002                       │
└─────────────────────────────────────────────────────────────────┘
```

Expanded:

```
┌─────────────────────────────────────────────────────────────────┐
│ ▼  researcher    running    0.4s    $0.002                       │
│   ─────────────────────────────────────────────────────────────  │
│   Prompt: "Find all usages of AuthService across the codebase"  │
│                                                                  │
│   ├─ Glob  *.swift                              done  0.1s      │
│   ├─ Grep  "AuthService"  AnvilDomain/          done  0.2s      │
│   └─ Read  AuthService.swift                    done  0.1s      │
│                                                                  │
│   Output preview: "Found 14 usages across 6 files. Key sites:  │
│   LoginView.swift:42, SessionViewModel.swift:89..."             │
└─────────────────────────────────────────────────────────────────┘
```

Nested subagent (depth-2, a sub-dispatch from the researcher):

```
┌─────────────────────────────────────────────────────────────────┐
│ ▼  researcher    done    1.2s    $0.004                          │
│   ─────────────────────────────────────────────────────────────  │
│   Prompt: "Find all usages of AuthService..."                   │
│                                                                  │
│   ├─ Glob  *.swift                              done  0.1s      │
│   ├─▶  deep-searcher    done    0.8s    $0.002         [nested] │
│   └─ Read  AuthService.swift                    done  0.1s      │
│                                                                  │
│   Output preview: "Found 14 usages..."                          │
└─────────────────────────────────────────────────────────────────┘
```

### Anatomy of a Subagent Row

**Header bar (always visible):**
- Disclosure triangle (16pt, chevron.right / chevron.down)
- Agent name label (13pt medium, `.primary`)
- Status badge (see status system below)
- Elapsed time ("1.2s", "14s", "2m 3s") — right-aligned, 11pt `.tertiary`
- Cost ("$0.004") — right-aligned, 11pt `.tertiary`

**Collapsed body (height: 0):** nothing rendered.

**Expanded body:**
- Separator line (0.5pt, `.separator`)
- Delegated prompt label (11pt `.secondary`, truncated at 3 lines with "show more" toggle)
- Tool call list (see below)
- Output preview (11pt `.secondary`, truncated at 4 lines with "show more" toggle)
- If the agent produced file diffs: a compact file list with change counts (`+12 -3`)

**Tool call rows within an expanded subagent:**
- Leading connector line (1pt, `.quaternary`, vertical bar on the left)
- Tool icon: 12pt SF Symbol matching the tool type (magnifyingglass = Grep/Glob, doc.text = Read, pencil = Write/Edit, terminal = Bash)
- Tool name (12pt medium, `.primary`)
- Tool argument preview (12pt, `.secondary`, truncated)
- Status dot (4pt circle): `.systemGray` waiting, `.systemBlue` running, `.systemGreen` done, `.systemRed` failed
- Duration (11pt `.tertiary`)

### Status Badge System

Status is displayed as a pill label, not a spinner. The running state uses a subtle pulse animation on the pill's background, not a spinner icon. This avoids visual noise when many agents run concurrently.

| Status | Label | Color | Animation |
|---|---|---|---|
| `idle` | "Idle" | `.systemGray` | None |
| `running` | "Running" | `.systemBlue` | Pulse opacity 0.6 → 1.0, 1.5s cycle |
| `paused` | "Paused" | `.systemOrange` | None |
| `completed` | "Done" | `.systemGreen` | None |
| `failed` | "Failed" | `.systemRed` | None |
| `cancelled` | "Cancelled" | `.systemGray` | None |

The pulse animation uses `scaleEffect` + `opacity` looped with `repeatForever(.autoreverse)` — per the Tahoe animation standard ("Pulsing indicators: `scaleEffect` + `opacity` loop, never spinning custom shapes"). Do not use a `ProgressView` (spinner) for running state — it creates visual competition when 4+ agents are running simultaneously.

### Color Coding

Each agent type (by `name` field in the agent definition) is assigned a fixed hue from a palette of 8 colors. The color is applied as a 2pt left-border accent on the subagent block and as the foreground tint on the agent name label. If the agent was given a custom color in its definition, that color is used directly.

Color assignment is deterministic: `colorIndex = hash(agentName) % 8`. This means the same agent type always gets the same color across all sessions and all users on the same project (because it comes from the agent name, not a random value).

Palette (semantic names, resolved to system colors):
1. `.systemBlue` — general-purpose, researcher
2. `.systemPurple` — planner, designer
3. `.systemOrange` — writer, documenter
4. `.systemGreen` — tester, verifier
5. `.systemCyan` — explorer, reader
6. `.systemIndigo` — architect, reviewer
7. `.systemPink` — notifier, reporter
8. `.systemYellow` — coordinator, orchestrator

### Interaction Behavior

- **Click anywhere on the header bar:** toggles expand/collapse. The disclosure triangle rotates 90 degrees using `withAnimation(.spring(response: 0.3, dampingFraction: 0.8))`.
- **Click agent name:** selects that agent's session in the sidebar (if it has a corresponding session object). This is a deep-link into the agent's own conversation view.
- **Right-click header:** context menu with: "Copy output", "Open session", "Stop agent" (if running), "Retry" (if failed).
- **New subagent dispatches while expanded:** tool call rows append at the bottom with a brief scale-in animation.
- **Completion:** the status badge transitions from "Running" (pulse) to "Done" (static green) with a 0.2s cross-fade. No sound or modal.

### Parallel Agents (Multiple Simultaneous Dispatches)

When the parent session dispatches multiple subagents in the same turn, all appear as sibling blocks in sequence within the turn bubble. The order is: dispatch order from the model. Running agents use pulsing badges; completed ones are static.

The vertical layout of 4+ running agent blocks communicates parallelism better than any animation — the stacked pulse is visually readable and calm.

### SwiftUI Implementation

The tree uses `OutlineGroup` inside a `List` with `children` binding for recursive depth. For the tool call rows inside an expanded agent block, use a plain `VStack` with `ForEach` — these are not independently expandable so `OutlineGroup` is not needed at that level.

```swift
// Conceptual structure (not final implementation)
struct SubagentBlock: View {
    let dispatch: AgentDispatch  // domain model to be defined
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            SubagentExpandedBody(dispatch: dispatch)
        } label: {
            SubagentHeaderRow(dispatch: dispatch)
        }
        .disclosureGroupStyle(SubagentDisclosureStyle())
    }
}
```

The `SubagentDisclosureStyle` provides the left-border accent, background fill (`.glassEffect(.regular)` on macOS 26 / `.ultraThinMaterial` on macOS 15–25 as a fallback), and corner radius (6pt). Do not use a custom `ZStack + RoundedRectangle + .fill` for the block background.

---

## Surface 2: Team Management View

### Purpose

The team management panel provides a roster-level view of all declared agent team members: their role, current task, active/idle status, and controls for reassignment and stopping. This is analogous to a project management "people" view but for AI agents.

### Where It Lives

The team management panel lives in the Agent workspace's right inspector pane, accessible via `Cmd+Shift+I` when the Agent mode is active, or via a "Team" button in the agent sidebar toolbar. It is a collapsible inspector section, not a separate navigation destination.

Alternatively, a standalone panel for operators managing large teams (5+ agents) is accessible via `Cmd+K` → "Show Agent Team".

### Roster List Structure

```
┌──────────────────────────────────────────────────────────────┐
│ AGENT TEAM (4 members, 2 active)                             │
│ ──────────────────────────────────────────────────────────── │
│ [●] researcher      Running    "Find AuthService usages"     │
│     claude-haiku-4-5   0.4s   $0.002    [Stop]              │
│                                                              │
│ [●] implementer     Running    "Update LoginView.swift"      │
│     claude-sonnet-4-6  12.3s  $0.041    [Stop]              │
│                                                              │
│ [○] reviewer        Idle       Last: "Reviewed PR #42" 4m   │
│     claude-sonnet-4-6  –       –        [Assign]            │
│                                                              │
│ [○] coordinator     Idle       Waiting for dependencies     │
│     claude-opus-4-6    –       –        [Assign]            │
└──────────────────────────────────────────────────────────────┘
```

### Anatomy of a Team Member Row

Each row is 2-line density (52pt height):

**Line 1:**
- Status dot (8pt circle): filled `.systemGreen` for active/running, outlined `.systemGray` for idle
- Agent name (14pt medium, `.primary`)
- Status label (13pt `.secondary`): "Running", "Idle", "Paused", "Failed"
- Current task summary (13pt `.secondary`, truncated to ~40 chars, right of status label with an em-dash separator)

**Line 2 (indented to align with agent name):**
- Model label (11pt `.tertiary`): "claude-haiku-4-5", "claude-sonnet-4-6", etc.
- Elapsed time (11pt `.tertiary`)
- Cost so far (11pt `.tertiary`)
- Action button (trailing): "Stop" for running agents (destructive, red tint), "Assign" for idle agents (accent tint)

**Hover state:** reveals additional trailing actions: "Open session" (magnifyingglass icon) and "Restart" (arrow.clockwise icon).

**Active state animation:** the status dot for running agents pulses using the same opacity cycle as the in-conversation badge (1.5s, 0.6→1.0 opacity, repeat autoreverses). No spinner.

### Section Header

```
AGENT TEAM (4 members, 2 active)
```

- Font: 11pt `.caption`, letter-spaced, `.secondary`
- Right side: "Manage team" button (opens full configuration sheet) and a "+" button to add a new agent definition
- The count updates reactively: "2 active" goes to "3 active" when a new agent starts

### Status Rollup Bar

At the top of the team panel, a compact progress bar shows overall team completion for the current task:

```
▓▓▓▓▓▓░░░░░░░░  3 of 7 subtasks complete
```

- Bar height: 4pt, corner radius: 2pt
- Fill: `.systemGreen` for completed portion
- Background: `.systemFill`
- Label: "X of Y subtasks complete" (11pt `.secondary`)

This is the Linear-style rollup adapted for agent teams. It makes the parent agent's orchestration progress legible without requiring the user to expand individual session threads.

### Assign and Stop Actions

**Stop (running agent):**
- Confirmation is required if the agent has been running for more than 10 seconds, to prevent accidental stops of expensive operations
- Confirmation: an inline confirmation within the row (not a modal): "Stop researcher?" with [Cancel] and [Stop] buttons, appearing in a slide-in animation
- If the agent has outstanding tool calls, those are cancelled; cost is shown as final

**Assign (idle agent):**
- Opens an inline prompt field below the row: "Task for researcher:" with a text input and Send button
- The task is sent as the agent's first turn
- The row immediately transitions from "Idle" to "Running" with the submitted task as the summary

**Reassign (running agent):**
- Accessible via right-click context menu only (not a primary affordance) to prevent accidents
- Action: "Reassign..." — stops the current task and opens the inline prompt

### Sorting and Filtering

Default sort order: active (running) first, sorted by elapsed time descending; then idle, sorted alphabetically.

No filtering UI is provided by default (team sizes are expected to be 2–8). If a team has more than 8 members, a search field appears at the top of the roster.

---

## Visual Hierarchy Rules

### Indentation

| Level | Left padding | Use |
|---|---|---|
| Root session | 0pt (full width) | The user's own session |
| Depth-1 subagent block | 12pt | Agents dispatched by the root session |
| Tool call rows inside an agent | 20pt | Individual tool calls within a dispatch |
| Depth-2 subagent block | 28pt | Agents dispatched by a depth-1 agent |
| Max depth | 2 levels | No deeper nesting is rendered; flatten beyond depth-2 |

The left-border accent line is 2pt wide and spans the full height of the block including all child content. This visual connector anchors the nested content to its parent.

### Typography Hierarchy

| Role | Size | Weight | Color |
|---|---|---|---|
| Agent name | 13pt | Medium (`.medium`) | `.primary` |
| Status badge label | 11pt | Semibold | Badge-specific (see above) |
| Delegated prompt | 11pt | Regular | `.secondary` |
| Tool name | 12pt | Medium | `.primary` |
| Tool argument preview | 12pt | Regular | `.secondary` |
| Elapsed / cost | 11pt | Regular | `.tertiary` |
| Output preview | 11pt | Regular | `.secondary` |
| Team roster name | 14pt | Medium | `.primary` |
| Team roster status | 13pt | Regular | `.secondary` |
| Team roster model | 11pt | Regular | `.tertiary` |
| Section headers | 11pt | Regular, letterspaced | `.secondary` |

No custom fonts. All sizes use `Font.system(size:weight:)` to respect Dynamic Type scaling.

### Color Usage

- **Status colors** are always system semantic colors (`Color(.systemGreen)`, etc.), not custom hex values. This ensures correct dark/light mode behavior without any `colorScheme` branching in views.
- **Agent accent colors** use a 5% opacity fill on the block background and 100% opacity on the left-border line. Never apply agent color to text labels — it reduces legibility in dark mode.
- **Background materials:** subagent blocks use `.glassEffect(.regular)` (macOS 26) with `.ultraThinMaterial` as the macOS 15–25 fallback. Team roster rows use `.clear` — no material on individual rows. The inspector panel hosting the team view uses `.ultraThinMaterial`. Never use a custom opaque `Color` or `RoundedRectangle` fill where a material is appropriate.
- **Selection:** standard `.accentColor` selection fill. Do not use custom selection colors.

### Animation Policy

| Action | Animation |
|---|---|
| Disclosure toggle (expand/collapse) | `spring(response: 0.3, dampingFraction: 0.8)`, triangle rotation |
| New agent block appears | `spring(response: 0.3, dampingFraction: 0.8)` scale from 0.95 to 1.0 |
| Status transition (running → done) | `spring(response: 0.3, dampingFraction: 0.8)` cross-fade |
| Running state pulse | `scaleEffect` 1.0→1.08 + `opacity` 0.6→1.0, `repeatForever(.autoreverse)`, 1.5s |
| Tool call row append | `spring(response: 0.3, dampingFraction: 0.8)` translate from +8pt y to 0 |
| Inline confirm/assign reveal | `spring(response: 0.3, dampingFraction: 0.8)` height expansion |

**Rule:** no spinner (`ProgressView`) for running state. The `scaleEffect` + `opacity` pulse pattern communicates "this is live" per the Tahoe standard without the visual dominance of a spinner. Spinners are reserved for blocking operations where the UI is waiting for a response before proceeding (e.g., initial session connect). Never use spinning custom shapes.

### Native macOS Patterns

**NSOutlineView / SwiftUI OutlineGroup:** The subagent tree should use `List` with `OutlineGroup` for the recursive session-to-subagent levels. Tool call rows within an expanded subagent are a plain `VStack` — they are not independently expandable and do not need `OutlineGroup`.

**DisclosureGroup with custom style:** implement a `SubagentDisclosureStyle` conforming to `DisclosureGroupStyle` to get the left-border accent and background material. The stock `DisclosureGroupStyle` lacks the visual affordance needed.

**List style:** the agent sidebar (the main session list in the sidebar column) uses `.listStyle(.sidebar)`. The team management roster, which lives inside an inspector panel rather than a primary sidebar column, uses `.listStyle(.inset)`. Never use `alternatesRowBackgrounds: true` or `frame(minHeight:)` on any List or Table.

**Consistent row anatomy:** follow the row anatomy from `COMPETITOR_GAP.md` Pattern 7: leading icon/dot, primary label, trailing badge/action, hover-revealed secondary actions. No row should deviate from this grammar.

**Keyboard navigation:** the subagent tree is fully keyboard-navigable. Arrow keys navigate rows; Space or Return toggles expand/collapse on a selected agent block; `s` stops a running agent (single-key action following the agent sidebar pattern already in COMPETITOR_GAP.md); `o` opens the agent's session in the main conversation panel.

---

## Domain Model Extensions Needed

The following additions to `AnvilDomain` are required to implement this spec. These are not yet in the codebase.

### `AgentDispatch`

A new value type representing a single subagent invocation from within a session:

```swift
public struct AgentDispatch: Sendable, Identifiable, Codable {
    public let id: String
    public let parentSessionId: String
    public let agentType: String          // "researcher", "implementer", etc.
    public let delegatedPrompt: String
    public var status: AgentSessionStatus
    public let startedAt: Date
    public var completedAt: Date?
    public var cost: Decimal
    public var toolCalls: [DispatchedToolCall]
    public var outputPreview: String?
    public var childDispatches: [AgentDispatch]   // depth-2 support
    public var accentColorIndex: Int              // 0–7, deterministic from agentType
}
```

### `DispatchedToolCall`

```swift
public struct DispatchedToolCall: Sendable, Identifiable, Codable {
    public let id: String
    public let toolName: String
    public let argumentPreview: String
    public var status: ToolCallStatus
    public let startedAt: Date
    public var completedAt: Date?
}

public enum ToolCallStatus: String, Sendable, Codable {
    case pending, running, completed, failed
}
```

### `AgentTeamMember`

```swift
public struct AgentTeamMember: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let role: String
    public let modelId: String
    public var status: AgentSessionStatus
    public var currentTaskSummary: String?
    public var assignedSessionId: String?
    public var elapsedSeconds: Double?
    public var costSoFar: Decimal
    public var lastCompletedTaskSummary: String?
    public var lastCompletedAt: Date?
}
```

### `AgentTeam`

```swift
public struct AgentTeam: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public var members: [AgentTeamMember]
    public var subtaskCount: Int
    public var completedSubtaskCount: Int

    public var completionRatio: Double {
        guard subtaskCount > 0 else { return 0 }
        return Double(completedSubtaskCount) / Double(subtaskCount)
    }
}
```

---

## Task Cross-References

This spec directly drives the following existing tasks:

- **Task #78** — Subagent tree view: implement the `SubagentBlock`, `SubagentHeaderRow`, `SubagentExpandedBody`, and `DispatchedToolCallRow` views in `Packages/AnvilUI/Sources/Modes/Agent/`. Wire `AgentDispatch` objects into `ConversationView` as a new `dispatches: [AgentDispatch]` parameter alongside the existing `session`.

- **Task #79** — Agent team management view: implement `AgentTeamRosterView`, `TeamMemberRow`, `TeamRollupBar` in `Packages/AnvilUI/Sources/Modes/Agent/`. Surface from the inspector pane and from `Cmd+K` → "Show Agent Team".

Both tasks depend on the domain model extensions (AgentDispatch, AgentTeamMember, AgentTeam) being added to `Packages/AnvilDomain/Sources/Primitives/Agents/` first.

---

## Reference Sources

Research used to produce this spec:

- [Claude Code Subagents Docs](https://code.claude.com/docs/en/sub-agents) — primary reference for subagent model and UI patterns
- [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams) — team topology and SendMessage protocol
- [OpenAI Codex Subagents](https://developers.openai.com/codex/subagents) — parallel subagent patterns and path-based addressing
- [Linear Parent and Sub-Issues](https://linear.app/docs/parent-and-sub-issues) — progress rollup and nested hierarchy patterns
- [SwiftUI OutlineGroup](https://developer.apple.com/documentation/swiftui/outlinegroup) — native macOS recursive list implementation
- [Xcode Build Parallelization WWDC22](https://developer.apple.com/videos/play/wwdc2022/110364/) — activity viewer hierarchy and status indicator patterns
- `ARCHITECTURE/COMPETITOR_GAP.md` — row anatomy pattern (Pattern 7), single-key shortcuts (Pattern 2)
