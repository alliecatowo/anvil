# ANVIL — Comprehensive Specification

## Agent-Native Development Environment for macOS

**Version:** 0.1.0-spec
**Target:** macOS 15+ (Sequoia), Apple Silicon primary, Intel supported
**Language:** Swift 6 with strict concurrency
**UI Framework:** SwiftUI + AppKit interop

---

# PART 1: VISION & PHILOSOPHY

## What Anvil Is

Anvil is a native macOS application that replaces VS Code, terminal AI tools, browser-based dev dashboards, and half a dozen other apps with a single, keyboard-driven integration surface. It is not an IDE in the traditional sense — it is the **post-IDE**: an agent-native development environment where AI is ambient infrastructure, not a bolted-on feature.

## What Anvil Is Not

- Not a full-featured code editor competing with Neovim/VS Code for all-day typing. It has an editor for review and light editing.
- Not a terminal emulator competing with Warp/iTerm. It has an embedded terminal.
- Not a project management tool competing with Linear/Jira. It integrates with them.
- Not a cloud agent like Codex/Devin. It orchestrates agents — local and cloud.

## Core Design Principles

1. **Write-heavy, not read-heavy.** Every pixel is a verb. You open Anvil to command things, not watch things.
2. **ACP is electricity in the walls.** AI flows through every surface via your Agent Communication Protocol connection. No per-feature API keys. Plugins inherit AI for free.
3. **Opinionated workflow.** Intent → Agent → Review → Ship. Four phases, four modes, keyboard-navigable.
4. **Never leave.** If you open a browser, Anvil has failed. PRs, issues, databases, deployments, messages, docs — all in-app with native UI.
5. **Form drives function.** If it is not gorgeous, it is a bug.
6. **The abstraction is the product. The provider is replaceable.** Every feature is a Primitive with a contract. Providers are swappable. First-party implementations use the same plugin API as third-party.

---

# PART 2: DESIGN LANGUAGE

## Reference Applications

The visual and interaction design draws from these specific references:

- **Raycast** — Command palette as primary interaction surface. Speed. Density. Every action is a keystroke away.
- **Linear** — Opinionated workflow. Keyboard-first list navigation. Typographic precision. The feeling that the app respects your time.
- **GitKraken** — The sidebar-driven multi-view layout. Graph visualization. The feeling of mastery over complex git state.
- **Codex UI / ChatGPT desktop app** — The conversational agent panel. Clean message rendering. Tool call visualization.
- **KaraFun** — The three-panel window architecture: narrow left sidebar for navigation, wide main content area, optional right detail panel. Clean category switching with visual indicators.
- **macOS System Settings / Notes** — Native feel. Source list sidebar. Seamless transitions. The app feels like it belongs on the platform.
- **Superhuman** — Inbox-zero interaction model. `j/k` navigation. Batch actions. Speed as the core feature.

## Window Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Traffic lights    [Mode tabs: Intent Agent Review Ship ...]     │
│                    Title / Context indicator        [Search ⌘K]  │
├────────┬─────────────────────────────────┬───────────────────────┤
│        │                                 │                       │
│  Side  │                                 │    Detail / Inspector │
│  bar   │       Main Content Area         │    Panel              │
│        │                                 │    (contextual,       │
│  Nav   │       (changes based on         │     collapsible,      │
│  list  │        mode + selection)         │     ⌘⇧I toggle)      │
│        │                                 │                       │
│  48px  │                                 │                       │
│  wide  │                                 │                       │
│  icons │                                 │                       │
│  when  │                                 │                       │
│  col-  │                                 │                       │
│  lapsed│                                 │                       │
├────────┴─────────────────────────────────┴───────────────────────┤
│  Status Bar: branch ∙ provider ∙ agent status ∙ cost ∙ clock    │
└──────────────────────────────────────────────────────────────────┘
```

### Sidebar

- Width: 260px default, resizable, collapsible to 48px icon rail
- Sections change based on active Mode
- Each section is collapsible
- Items in lists support: selection, multi-select (x), drag-and-drop reorder
- Keyboard: `j/k` move, `↵` open, `x` select, `⌘[` / `⌘]` collapse/expand sections
- At collapsed width: shows only icons for each section, tooltip on hover

### Main Content Area

- Fills remaining horizontal space
- Supports tabs (⌘T new, ⌘W close, ⌘⇧[ / ⌘⇧] switch)
- Supports horizontal and vertical splits (⌘\ split right, ⌘⇧\ split down)
- Each tab/split has its own content, mode-independent
- Scroll position preserved per tab

### Detail / Inspector Panel

- Right-side panel, 320px default, resizable, collapsible
- Toggle: `⌘⇧I`
- Content is contextual: shows details/properties of whatever is selected in sidebar or main content
- In Agent mode: shows session metadata, token usage, linked items
- In Review mode: shows PR metadata, CI status, reviewer assignments
- In Editor: shows file info, symbols, git blame

### Status Bar

- Fixed bottom, 24px height
- Left: current branch, source control status, uncommitted change count
- Center: active agent status (provider icon, model, running/idle), quick switch with click
- Right: ACP cost (session / today), notification count, clock
- All status bar items are clickable with contextual actions

## Color System

```
Background (primary):     #0D0D0D (near-black)
Background (secondary):   #161616 (panels, sidebar)
Background (tertiary):    #1E1E1E (cards, hover states)
Background (elevated):    #252525 (modals, dropdowns, command palette)

Border (subtle):          #2A2A2A (panel dividers)
Border (medium):          #3A3A3A (card outlines, input fields)
Border (strong):          #505050 (focused elements)

Text (primary):           #EDEDED (main content)
Text (secondary):         #999999 (descriptions, metadata)
Text (tertiary):          #666666 (placeholders, disabled)

Accent (blue):            #3B82F6 (primary actions, selections, links)
Accent (green):           #22C55E (success, approved, passing tests)
Accent (amber):           #F59E0B (warnings, pending, in-progress)
Accent (red):             #EF4444 (errors, destructive actions, failing tests)
Accent (purple):          #A855F7 (agent activity, ACP-powered features)
Accent (teal):            #14B8A6 (info, secondary accent)

Diff (added bg):          #22C55E at 10% opacity
Diff (removed bg):        #EF4444 at 10% opacity
Diff (added text):        #4ADE80
Diff (removed text):      #F87171

Selection (background):   #3B82F6 at 20% opacity
Selection (border):       #3B82F6 at 60% opacity
```

## Typography

```
UI text:          SF Pro Text, 13px/16px regular
UI labels:        SF Pro Text, 11px/14px medium, tracking +0.3
Sidebar items:    SF Pro Text, 13px/18px regular (14px medium for section headers)
Main headings:    SF Pro Display, 20px/24px semibold
Subheadings:      SF Pro Display, 15px/20px medium
Code / monospace: SF Mono, 12px/18px regular (editor, diffs, terminal, code blocks)
Command palette:  SF Pro Text, 15px/20px regular (input), 13px/16px regular (results)
Status bar:       SF Mono, 11px/14px regular
```

## Motion

- All transitions: 150ms ease-out (matches macOS system feel)
- Sidebar collapse: 200ms spring(response: 0.5, dampingFraction: 0.85)
- Command palette appear: 100ms fade + 4px vertical translate
- List item insert/remove: 150ms with opacity + height animation
- Mode switch: crossfade 120ms
- No bouncing. No elastic overscroll on lists. No decorative animations. Every animation communicates state change.

## Iconography

- SF Symbols throughout (system-native, supports Dynamic Type and accessibility)
- 16px standard, 20px for sidebar section icons, 12px for inline status indicators
- Weight: regular for content, medium for navigation, semibold for status bar
- Custom icons only for: provider logos (Claude, OpenAI, GitHub, etc.), Anvil app icon

## Component Library (Core UI Elements)

### List Item
Standard list item used across all sidebar lists and inbox views:
```
┌──────────────────────────────────┐
│ [icon] Title text          [tag] │
│        Secondary text    [time]  │
└──────────────────────────────────┘
```
- 40px height for compact lists, 56px for rich lists (with secondary text)
- Hover: background shifts to tertiary
- Selected: accent-blue selection background + left 3px accent bar
- Multi-selected: checkmark icon left of title

### Card
Used for work items, agent sessions, deployment targets:
```
┌──────────────────────────────────────┐
│ Header with icon and title      [⋯] │
│                                      │
│ Content area                         │
│                                      │
│ Footer: metadata, tags, actions      │
└──────────────────────────────────────┘
```
- Background: tertiary
- Border: subtle, 8px corner radius
- Hover: medium border
- Padding: 12px

### Diff View
```
Line numbers │ - removed line (red text on red-tinted bg)
Line numbers │ + added line (green text on green-tinted bg)
Line numbers │   context line (normal text)
```
- Side-by-side: two columns, synced scrolling
- Unified: single column, interleaved
- Inline comments: expand below the relevant line, 12px left indent, subtle left border

### Agent Message
```
┌─────────────────────────────────────────────┐
│ Claude (Opus)                    2:34 PM     │
│                                              │
│ I'll start by examining the auth module...   │
│                                              │
│ ┌─ Tool Call: read_file ──────────────────┐  │
│ │ path: src/auth/handler.ts               │  │
│ │ ▶ Result (142 lines)          [expand]  │  │
│ └─────────────────────────────────────────┘  │
│                                              │
│ The issue is in the token validation...      │
│                                              │
│ ┌─ Tool Call: edit_file ──────────────────┐  │
│ │ path: src/auth/handler.ts               │  │
│ │ [Inline diff view]             [✓] [✗]  │  │
│ └─────────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```
- Tool calls: collapsible, show name + key params when collapsed
- File edits: show inline diff with approve/reject buttons
- Terminal output: monospace, dark inset background, scrollable with max-height
- Streaming: text appears word-by-word, tool calls appear as pending with spinner

### Command Palette
```
┌────────────────────────────────────────────────┐
│ 🔍 [                                        ] │
├────────────────────────────────────────────────┤
│ Actions                                        │
│   ▶ Dispatch agent for "Fix auth bug"    ⌘⇧A  │
│   ▶ AI review current file               ⌘⇧R  │
│   ▶ Switch provider to Gemini              ⌘P  │
│ Files                                          │
│   📄 src/auth/handler.ts                       │
│   📄 src/auth/middleware.ts                    │
│ Work Items                                     │
│   🎫 ANV-142: Fix SSO token refresh           │
└────────────────────────────────────────────────┘
```
- Appears centered, 600px wide, max 400px tall
- Backdrop: background dim at 40% opacity
- Results grouped by category with section headers
- Fuzzy matching with bold highlights on matched characters
- 6 visible results before scroll, selected item has accent highlight
- Keyboard: arrow keys navigate, ↵ execute, ⌘# jump to category, esc dismiss

---

# PART 3: APPLICATION ARCHITECTURE

## Hexagonal Architecture (Ports & Adapters)

Anvil uses hexagonal architecture with Domain-Driven Design principles. This maps perfectly to the Primitive/Provider model:

- **Primitives** are **Ports** (interfaces defined by the domain)
- **Providers** are **Adapters** (concrete implementations)
- **The Domain Layer** knows nothing about any specific provider
- **The Application Layer** orchestrates domain operations
- **The Presentation Layer** (SwiftUI) observes domain state via ViewModels

```
┌─────────────────────────────────────────────────────────────────┐
│                    Presentation Layer (SwiftUI)                  │
│   Views ←→ ViewModels ←→ Application Services                  │
├─────────────────────────────────────────────────────────────────┤
│                    Application Layer                             │
│   Use Cases / Commands / Queries / Event Handlers               │
├─────────────────────────────────────────────────────────────────┤
│                    Domain Layer (Pure Swift)                     │
│   Primitives (Ports) / Entities / Value Objects / Domain Events │
├──────────┬──────────┬──────────┬──────────┬─────────────────────┤
│ Git      │ GitHub   │ Claude   │ Slack    │ ... more adapters   │
│ Adapter  │ Adapter  │ Adapter  │ Adapter  │                     │
│(libgit2) │ (API)    │ (API)    │ (API)    │                     │
└──────────┴──────────┴──────────┴──────────┴─────────────────────┘
         Infrastructure Layer (Adapters / Providers)
```

## Project Structure

```
Anvil/
├── Anvil.xcodeproj
├── Packages/                              # Swift packages (modular)
│   ├── AnvilDomain/                       # Pure domain — zero dependencies
│   │   ├── Sources/
│   │   │   ├── Primitives/                # Port protocols
│   │   │   │   ├── SourceControl/
│   │   │   │   │   ├── SourceControlPort.swift
│   │   │   │   │   ├── Branch.swift
│   │   │   │   │   ├── Commit.swift
│   │   │   │   │   ├── Diff.swift
│   │   │   │   │   ├── WorktreeManager.swift
│   │   │   │   │   └── MergeConflict.swift
│   │   │   │   ├── SourceControlCloud/
│   │   │   │   │   ├── SourceControlCloudPort.swift
│   │   │   │   │   ├── PullRequest.swift
│   │   │   │   │   ├── RemoteRepo.swift
│   │   │   │   │   └── RepoTemplate.swift
│   │   │   │   ├── Tickets/
│   │   │   │   │   ├── TicketPort.swift
│   │   │   │   │   ├── Ticket.swift
│   │   │   │   │   ├── Cycle.swift
│   │   │   │   │   ├── Board.swift
│   │   │   │   │   └── TicketRelation.swift
│   │   │   │   ├── Agents/
│   │   │   │   │   ├── AgentPort.swift
│   │   │   │   │   ├── AgentSession.swift
│   │   │   │   │   ├── AgentMessage.swift
│   │   │   │   │   ├── ToolCall.swift
│   │   │   │   │   ├── ToolResult.swift
│   │   │   │   │   ├── ApprovalPolicy.swift
│   │   │   │   │   └── SynthesisRoom.swift
│   │   │   │   ├── CodeReview/
│   │   │   │   │   ├── CodeReviewPort.swift
│   │   │   │   │   ├── Review.swift
│   │   │   │   │   ├── ReviewComment.swift
│   │   │   │   │   └── ReviewChecklist.swift
│   │   │   │   ├── Database/
│   │   │   │   │   ├── DatabasePort.swift
│   │   │   │   │   ├── DatabaseConnection.swift
│   │   │   │   │   ├── Schema.swift
│   │   │   │   │   ├── QueryResult.swift
│   │   │   │   │   └── Migration.swift
│   │   │   │   ├── Hosting/
│   │   │   │   │   ├── HostingPort.swift
│   │   │   │   │   ├── Deployment.swift
│   │   │   │   │   ├── Environment.swift
│   │   │   │   │   └── BuildLog.swift
│   │   │   │   ├── Observability/
│   │   │   │   │   ├── ObservabilityPort.swift
│   │   │   │   │   ├── ErrorEvent.swift
│   │   │   │   │   ├── Alert.swift
│   │   │   │   │   └── Metric.swift
│   │   │   │   ├── Documentation/
│   │   │   │   │   ├── DocumentationPort.swift
│   │   │   │   │   ├── Document.swift
│   │   │   │   │   ├── DocIndex.swift
│   │   │   │   │   └── ExternalDocSource.swift
│   │   │   │   ├── Messaging/
│   │   │   │   │   ├── MessagingPort.swift
│   │   │   │   │   ├── Channel.swift
│   │   │   │   │   ├── Message.swift
│   │   │   │   │   └── Thread.swift
│   │   │   │   ├── CICD/
│   │   │   │   │   ├── CICDPort.swift
│   │   │   │   │   ├── Pipeline.swift
│   │   │   │   │   ├── BuildRun.swift
│   │   │   │   │   └── TestResult.swift
│   │   │   │   ├── Containers/
│   │   │   │   │   ├── ContainerPort.swift
│   │   │   │   │   ├── Container.swift
│   │   │   │   │   ├── ContainerImage.swift
│   │   │   │   │   └── ComposeStack.swift
│   │   │   │   ├── Testing/
│   │   │   │   │   ├── TestingPort.swift
│   │   │   │   │   ├── TestSuite.swift
│   │   │   │   │   ├── TestCase.swift
│   │   │   │   │   └── CoverageReport.swift
│   │   │   │   ├── APIClient/
│   │   │   │   │   ├── APIClientPort.swift
│   │   │   │   │   ├── HTTPRequest.swift
│   │   │   │   │   ├── RequestCollection.swift
│   │   │   │   │   └── APISchema.swift
│   │   │   │   ├── Secrets/
│   │   │   │   │   ├── SecretsPort.swift
│   │   │   │   │   ├── Secret.swift
│   │   │   │   │   └── Vault.swift
│   │   │   │   ├── Voice/
│   │   │   │   │   ├── VoicePort.swift
│   │   │   │   │   ├── Transcription.swift
│   │   │   │   │   └── VoiceSession.swift
│   │   │   │   ├── Design/
│   │   │   │   │   ├── DesignPort.swift
│   │   │   │   │   ├── DesignFile.swift
│   │   │   │   │   ├── DesignToken.swift
│   │   │   │   │   └── Component.swift
│   │   │   │   ├── RemoteEnvironments/
│   │   │   │   │   ├── RemoteEnvironmentPort.swift
│   │   │   │   │   ├── RemoteConnection.swift
│   │   │   │   │   └── Tunnel.swift
│   │   │   │   ├── Schedule/
│   │   │   │   │   ├── SchedulePort.swift
│   │   │   │   │   ├── CalendarEvent.swift
│   │   │   │   │   ├── TimeBlock.swift
│   │   │   │   │   └── Availability.swift
│   │   │   │   ├── PersonalTasks/
│   │   │   │   │   ├── PersonalTaskPort.swift
│   │   │   │   │   ├── PersonalTask.swift
│   │   │   │   │   └── DailyLog.swift
│   │   │   │   ├── Notifications/
│   │   │   │   │   ├── NotificationPort.swift
│   │   │   │   │   ├── Notification.swift
│   │   │   │   │   └── NotificationRule.swift
│   │   │   │   ├── Search/
│   │   │   │   │   ├── SearchPort.swift
│   │   │   │   │   ├── SearchResult.swift
│   │   │   │   │   └── SearchScope.swift
│   │   │   │   ├── Analytics/
│   │   │   │   │   ├── AnalyticsPort.swift
│   │   │   │   │   ├── UsageMetric.swift
│   │   │   │   │   └── CostReport.swift
│   │   │   │   ├── PackageManagement/
│   │   │   │   │   ├── PackageManagementPort.swift
│   │   │   │   │   ├── Dependency.swift
│   │   │   │   │   └── Vulnerability.swift
│   │   │   │   └── AgentMarketplace/
│   │   │   │       ├── AgentMarketplacePort.swift
│   │   │   │       ├── Skill.swift
│   │   │   │       └── SkillCompatibility.swift
│   │   │   ├── Core/
│   │   │   │   ├── PrimitiveRegistry.swift       # Tracks all registered primitives
│   │   │   │   ├── ProviderRegistry.swift         # Tracks all registered providers
│   │   │   │   ├── InterPrimitiveLink.swift       # Cross-primitive references
│   │   │   │   ├── DomainEvent.swift              # Base event protocol
│   │   │   │   ├── DomainError.swift              # Typed error hierarchy
│   │   │   │   └── EntityID.swift                 # Type-safe identifiers
│   │   │   └── ACP/
│   │   │       ├── ACPPort.swift                  # Core ACP abstraction
│   │   │       ├── ACPRequest.swift
│   │   │       ├── ACPResponse.swift
│   │   │       ├── ACPStreamEvent.swift
│   │   │       ├── ACPToolDefinition.swift
│   │   │       ├── ACPModelSelection.swift
│   │   │       └── ACPCostTracker.swift
│   │   └── Tests/
│   │
│   ├── AnvilApplication/                  # Use cases, commands, queries
│   │   ├── Sources/
│   │   │   ├── UseCases/
│   │   │   │   ├── Agent/
│   │   │   │   │   ├── StartAgentSessionUseCase.swift
│   │   │   │   │   ├── SynthesizeSessionsUseCase.swift
│   │   │   │   │   ├── DispatchAdversarialReviewUseCase.swift
│   │   │   │   │   └── SwitchAgentProviderUseCase.swift
│   │   │   │   ├── SourceControl/
│   │   │   │   │   ├── CreateWorktreeUseCase.swift
│   │   │   │   │   ├── AutoCommitUseCase.swift
│   │   │   │   │   ├── MergeBranchUseCase.swift
│   │   │   │   │   └── ResolveConflictUseCase.swift
│   │   │   │   ├── Review/
│   │   │   │   │   ├── SubmitReviewUseCase.swift
│   │   │   │   │   ├── AIReviewUseCase.swift
│   │   │   │   │   └── BatchReviewUseCase.swift
│   │   │   │   ├── Project/
│   │   │   │   │   ├── CreateProjectUseCase.swift
│   │   │   │   │   ├── GraduateProjectUseCase.swift
│   │   │   │   │   └── ScaffoldFromTemplateUseCase.swift
│   │   │   │   ├── Deployment/
│   │   │   │   │   ├── DeployUseCase.swift
│   │   │   │   │   └── RollbackUseCase.swift
│   │   │   │   └── ... (use cases for each primitive)
│   │   │   ├── Services/
│   │   │   │   ├── WorktreeOrchestrator.swift     # Manages worktree lifecycle
│   │   │   │   ├── ContextBuilder.swift           # Builds agent context from project state
│   │   │   │   ├── NotificationAggregator.swift   # Merges notifications from all primitives
│   │   │   │   ├── SearchIndexer.swift            # Indexes content from all primitives
│   │   │   │   ├── ACPRouter.swift                # Routes AI requests to configured providers
│   │   │   │   ├── PluginManager.swift            # Plugin lifecycle management
│   │   │   │   └── ProjectManager.swift           # Project lifecycle and metadata
│   │   │   └── EventBus/
│   │   │       ├── EventBus.swift                 # Pub/sub for domain events
│   │   │       └── EventHandlers/                 # React to cross-primitive events
│   │   │           ├── OnAgentCompleted.swift      # → Create review item
│   │   │           ├── OnPRMerged.swift            # → Trigger deploy, close ticket
│   │   │           ├── OnBuildFailed.swift         # → Notify, create error event
│   │   │           ├── OnErrorSpiked.swift         # → Alert, correlate with deploy
│   │   │           └── ...
│   │   └── Tests/
│   │
│   ├── AnvilInfrastructure/               # Adapters (providers)
│   │   ├── Sources/
│   │   │   ├── SourceControl/
│   │   │   │   └── GitAdapter/
│   │   │   │       ├── GitSourceControlAdapter.swift
│   │   │   │       ├── LibGit2Wrapper.swift
│   │   │   │       ├── GitWorktreeManager.swift
│   │   │   │       ├── GitDiffParser.swift
│   │   │   │       └── GitGraphBuilder.swift
│   │   │   ├── SourceControlCloud/
│   │   │   │   ├── GitHubAdapter/
│   │   │   │   │   ├── GitHubCloudAdapter.swift
│   │   │   │   │   ├── GitHubAPIClient.swift
│   │   │   │   │   ├── GitHubPRMapper.swift
│   │   │   │   │   └── GitHubWebhookHandler.swift
│   │   │   │   └── GitLabAdapter/
│   │   │   │       └── GitLabCloudAdapter.swift
│   │   │   ├── Agents/
│   │   │   │   ├── ClaudeAdapter/
│   │   │   │   │   ├── ClaudeAgentAdapter.swift
│   │   │   │   │   ├── AnthropicAPIClient.swift
│   │   │   │   │   ├── ClaudeToolMapper.swift
│   │   │   │   │   └── ClaudeStreamParser.swift
│   │   │   │   ├── OpenAIAdapter/
│   │   │   │   │   ├── OpenAIAgentAdapter.swift
│   │   │   │   │   └── OpenAIAPIClient.swift
│   │   │   │   ├── OllamaAdapter/
│   │   │   │   │   ├── OllamaAgentAdapter.swift
│   │   │   │   │   └── OllamaLocalClient.swift
│   │   │   │   └── CodexAdapter/
│   │   │   │       └── CodexCloudAdapter.swift
│   │   │   ├── Tickets/
│   │   │   │   ├── AnvilNativeTicketAdapter.swift
│   │   │   │   ├── LinearAdapter/
│   │   │   │   ├── JiraAdapter/
│   │   │   │   └── GitHubIssuesAdapter/
│   │   │   ├── Database/
│   │   │   │   ├── PostgreSQLAdapter/
│   │   │   │   ├── NeonAdapter/
│   │   │   │   ├── SQLiteAdapter/
│   │   │   │   ├── MongoDBAdapter/
│   │   │   │   └── RedisAdapter/
│   │   │   ├── Hosting/
│   │   │   │   ├── VercelAdapter/
│   │   │   │   ├── RailwayAdapter/
│   │   │   │   ├── FlyIOAdapter/
│   │   │   │   └── CloudflareAdapter/
│   │   │   ├── Observability/
│   │   │   │   ├── SentryAdapter/
│   │   │   │   └── DatadogAdapter/
│   │   │   ├── Messaging/
│   │   │   │   ├── SlackAdapter/
│   │   │   │   ├── DiscordAdapter/
│   │   │   │   └── TeamsAdapter/
│   │   │   ├── Documentation/
│   │   │   │   ├── AnvilNativeDocAdapter.swift
│   │   │   │   ├── NotionAdapter/
│   │   │   │   └── DevDocsAdapter/
│   │   │   ├── CICD/
│   │   │   │   ├── GitHubActionsAdapter/
│   │   │   │   └── CircleCIAdapter/
│   │   │   ├── Containers/
│   │   │   │   ├── DockerAdapter/
│   │   │   │   └── KubernetesAdapter/
│   │   │   ├── Testing/
│   │   │   │   ├── JestAdapter/
│   │   │   │   ├── PytestAdapter/
│   │   │   │   └── PlaywrightAdapter/
│   │   │   ├── Secrets/
│   │   │   │   ├── AnvilVaultAdapter.swift
│   │   │   │   └── OnePasswordAdapter/
│   │   │   ├── Voice/
│   │   │   │   ├── MacOSSpeechAdapter.swift
│   │   │   │   └── WhisperAdapter/
│   │   │   ├── Design/
│   │   │   │   └── FigmaAdapter/
│   │   │   ├── RemoteEnvironments/
│   │   │   │   ├── SSHAdapter/
│   │   │   │   ├── CodespacesAdapter/
│   │   │   │   └── NgrokAdapter/
│   │   │   ├── Schedule/
│   │   │   │   ├── AnvilNativeScheduleAdapter.swift
│   │   │   │   ├── AppleCalendarAdapter/
│   │   │   │   └── GoogleCalendarAdapter/
│   │   │   ├── PersonalTasks/
│   │   │   │   ├── AnvilNativeTaskAdapter.swift
│   │   │   │   └── TodoistAdapter/
│   │   │   ├── PackageManagement/
│   │   │   │   ├── NPMAdapter/
│   │   │   │   ├── CargoAdapter/
│   │   │   │   └── PipAdapter/
│   │   │   ├── Search/
│   │   │   │   └── AnvilNativeSearchAdapter.swift
│   │   │   ├── Analytics/
│   │   │   │   └── AnvilNativeAnalyticsAdapter.swift
│   │   │   ├── AgentMarketplace/
│   │   │   │   ├── MCPRegistryAdapter/
│   │   │   │   └── AnvilMarketplaceAdapter/
│   │   │   └── Persistence/
│   │   │       ├── SQLiteStore.swift              # GRDB-based local storage
│   │   │       ├── FileStore.swift                # File-based storage (markdown docs, etc.)
│   │   │       └── KeychainStore.swift            # macOS Keychain for secrets/tokens
│   │   └── Tests/
│   │
│   ├── AnvilUI/                           # Presentation layer
│   │   ├── Sources/
│   │   │   ├── App/
│   │   │   │   ├── AnvilApp.swift
│   │   │   │   ├── AppState.swift                 # Global observable state
│   │   │   │   ├── AppRouter.swift                # Navigation state machine
│   │   │   │   └── DependencyContainer.swift      # DI container
│   │   │   ├── DesignSystem/
│   │   │   │   ├── Colors.swift                   # AnvilColor namespace
│   │   │   │   ├── Typography.swift               # AnvilFont namespace
│   │   │   │   ├── Spacing.swift                  # AnvilSpacing namespace
│   │   │   │   ├── Animations.swift               # AnvilAnimation namespace
│   │   │   │   └── Components/
│   │   │   │       ├── AnvilListItem.swift
│   │   │   │       ├── AnvilCard.swift
│   │   │   │       ├── AnvilButton.swift
│   │   │   │       ├── AnvilTextField.swift
│   │   │   │       ├── AnvilBadge.swift
│   │   │   │       ├── AnvilContextMenu.swift
│   │   │   │       ├── AnvilSplitView.swift
│   │   │   │       ├── AnvilTabBar.swift
│   │   │   │       ├── AnvilSearchField.swift
│   │   │   │       ├── AnvilDiffView.swift
│   │   │   │       ├── AnvilCodeBlock.swift
│   │   │   │       ├── AnvilMarkdownRenderer.swift
│   │   │   │       └── AnvilLoadingIndicator.swift
│   │   │   ├── Shell/
│   │   │   │   ├── MainWindow.swift               # Top-level window layout
│   │   │   │   ├── Sidebar.swift                  # Left sidebar container
│   │   │   │   ├── ContentArea.swift              # Main content with tabs
│   │   │   │   ├── InspectorPanel.swift           # Right detail panel
│   │   │   │   ├── StatusBar.swift                # Bottom status bar
│   │   │   │   ├── CommandPalette.swift           # ⌘K overlay
│   │   │   │   └── ModeTabBar.swift               # Top mode switcher
│   │   │   ├── Modes/
│   │   │   │   ├── Intent/
│   │   │   │   │   ├── IntentMode.swift           # Mode container
│   │   │   │   │   ├── IntentSidebar.swift        # Work item list
│   │   │   │   │   ├── TicketDetailView.swift     # Rich ticket editor
│   │   │   │   │   ├── CycleView.swift            # Sprint/cycle timeline
│   │   │   │   │   ├── BoardView.swift            # Kanban board
│   │   │   │   │   ├── ProjectNotesView.swift     # Persistent knowledge base
│   │   │   │   │   └── TicketViewModel.swift
│   │   │   │   ├── Agent/
│   │   │   │   │   ├── AgentMode.swift
│   │   │   │   │   ├── AgentSidebar.swift         # Session list
│   │   │   │   │   ├── ConversationView.swift     # Chat with rich rendering
│   │   │   │   │   ├── WorkspaceView.swift        # File tree + diffs
│   │   │   │   │   ├── PlanView.swift             # Structured plan editor
│   │   │   │   │   ├── SynthesisRoomView.swift    # Multi-session merge
│   │   │   │   │   ├── AgentLaunchSheet.swift     # New session configuration
│   │   │   │   │   ├── ProviderPicker.swift       # Model/provider selector
│   │   │   │   │   └── AgentViewModel.swift
│   │   │   │   ├── Review/
│   │   │   │   │   ├── ReviewMode.swift
│   │   │   │   │   ├── ReviewSidebar.swift        # Reviewable items list
│   │   │   │   │   ├── DiffReviewView.swift       # Side-by-side / unified diff
│   │   │   │   │   ├── StackedDiffView.swift      # Layered change review
│   │   │   │   │   ├── GitGraphView.swift         # DAG visualization
│   │   │   │   │   ├── PRDetailView.swift         # Full PR view
│   │   │   │   │   ├── ReviewCommentView.swift    # Inline comment composer
│   │   │   │   │   ├── ReviewInboxView.swift      # Superhuman-style triage
│   │   │   │   │   └── ReviewViewModel.swift
│   │   │   │   ├── Ship/
│   │   │   │   │   ├── ShipMode.swift
│   │   │   │   │   ├── ShipSidebar.swift          # Deployment targets
│   │   │   │   │   ├── DeployDashboardView.swift  # Environment status
│   │   │   │   │   ├── BuildLogView.swift         # Streaming log viewer
│   │   │   │   │   ├── PreviewBrowserView.swift   # Inline preview frame
│   │   │   │   │   ├── EnvVarManagerView.swift    # Environment config
│   │   │   │   │   ├── RollbackView.swift         # Rollback with diff
│   │   │   │   │   └── ShipViewModel.swift
│   │   │   │   └── Auxiliary/                     # Non-core modes (⌘5+)
│   │   │   │       ├── EditorMode/
│   │   │   │       │   ├── EditorMode.swift
│   │   │   │       │   ├── EditorView.swift       # Code editor surface
│   │   │   │       │   ├── EditorSidebar.swift    # File explorer
│   │   │   │       │   ├── SymbolOutline.swift    # LSP symbol list
│   │   │   │       │   ├── MinimapView.swift      # Code minimap
│   │   │   │       │   ├── BreadcrumbBar.swift    # File path breadcrumb
│   │   │   │       │   └── EditorViewModel.swift
│   │   │   │       ├── DatabaseMode/
│   │   │   │       │   ├── DatabaseMode.swiftå
│   │   │   │       │   ├── SchemaExplorer.swift
│   │   │   │       │   ├── QueryConsole.swift
│   │   │   │       │   ├── ResultsTable.swift
│   │   │   │       │   ├── MigrationTimeline.swift
│   │   │   │       │   └── DatabaseViewModel.swift
│   │   │   │       ├── TerminalMode/
│   │   │   │       │   ├── TerminalMode.swift
│   │   │   │       │   ├── TerminalView.swift     # SwiftTerm embedded
│   │   │   │       │   ├── TerminalTabBar.swift
│   │   │   │       │   └── TerminalViewModel.swift
│   │   │   │       ├── DocsMode/
│   │   │   │       │   ├── DocsMode.swift
│   │   │   │       │   ├── DocBrowser.swift       # Tree navigation
│   │   │   │       │   ├── DocEditor.swift        # Markdown editor
│   │   │   │       │   ├── DocPreview.swift       # Rendered view
│   │   │   │       │   ├── ExternalDocViewer.swift # Reference docs
│   │   │   │       │   └── DocsViewModel.swift
│   │   │   │       ├── MessagingMode/
│   │   │   │       │   ├── MessagingMode.swift
│   │   │   │       │   ├── ChannelList.swift
│   │   │   │       │   ├── ChatView.swift
│   │   │   │       │   ├── ThreadPanel.swift
│   │   │   │       │   ├── UnifiedInbox.swift
│   │   │   │       │   └── MessagingViewModel.swift
│   │   │   │       ├── ScheduleMode/
│   │   │   │       │   ├── ScheduleMode.swift
│   │   │   │       │   ├── CalendarView.swift     # Day/week/month
│   │   │   │       │   ├── TimeBlockView.swift    # Focus time blocks
│   │   │   │       │   ├── AvailabilityView.swift
│   │   │   │       │   ├── AgendaView.swift       # Today's schedule
│   │   │   │       │   └── ScheduleViewModel.swift
│   │   │   │       ├── ObservabilityMode/
│   │   │   │       │   ├── ObservabilityMode.swift
│   │   │   │       │   ├── ErrorFeed.swift
│   │   │   │       │   ├── ErrorDetailView.swift
│   │   │   │       │   ├── MetricsDashboard.swift
│   │   │   │       │   └── ObservabilityViewModel.swift
│   │   │   │       ├── TestingMode/
│   │   │   │       │   ├── TestingMode.swift
│   │   │   │       │   ├── TestExplorer.swift
│   │   │   │       │   ├── TestResultsView.swift
│   │   │   │       │   ├── CoverageOverlay.swift
│   │   │   │       │   └── TestingViewModel.swift
│   │   │   │       ├── APIMode/
│   │   │   │       │   ├── APIMode.swift
│   │   │   │       │   ├── RequestBuilder.swift
│   │   │   │       │   ├── ResponseViewer.swift
│   │   │   │       │   ├── CollectionBrowser.swift
│   │   │   │       │   └── APIViewModel.swift
│   │   │   │       ├── ContainersMode/
│   │   │   │       │   ├── ContainersMode.swift
│   │   │   │       │   ├── ContainerDashboard.swift
│   │   │   │       │   ├── ComposeGraph.swift
│   │   │   │       │   └── ContainersViewModel.swift
│   │   │   │       ├── DesignMode/
│   │   │   │       │   ├── DesignMode.swift
│   │   │   │       │   ├── DesignBrowser.swift
│   │   │   │       │   ├── InspectionPanel.swift
│   │   │   │       │   └── DesignViewModel.swift
│   │   │   │       ├── NotificationsMode/
│   │   │   │       │   ├── NotificationsMode.swift
│   │   │   │       │   ├── InboxView.swift        # Superhuman-style
│   │   │   │       │   ├── ActivityFeedView.swift
│   │   │   │       │   └── NotificationsViewModel.swift
│   │   │   │       ├── AnalyticsMode/
│   │   │   │       │   ├── AnalyticsMode.swift
│   │   │   │       │   ├── UsageDashboard.swift
│   │   │   │       │   ├── CostBreakdown.swift
│   │   │   │       │   └── AnalyticsViewModel.swift
│   │   │   │       └── PersonalMode/
│   │   │   │           ├── PersonalMode.swift
│   │   │   │           ├── QuickCapture.swift     # ⌘⇧Space overlay
│   │   │   │           ├── TaskListView.swift
│   │   │   │           ├── DailyLogView.swift
│   │   │   │           ├── BookmarksView.swift
│   │   │   │           └── PersonalViewModel.swift
│   │   │   ├── Keyboard/
│   │   │   │   ├── KeyboardManager.swift          # Central key event handler
│   │   │   │   ├── Keybindings.swift              # All bindings, user-configurable
│   │   │   │   ├── KeybindingContext.swift         # Context-aware binding resolution
│   │   │   │   └── ChordTracker.swift             # Multi-key sequences (g t, g b, etc.)
│   │   │   └── Settings/
│   │   │       ├── SettingsWindow.swift
│   │   │       ├── GeneralSettings.swift
│   │   │       ├── ProviderSettings.swift         # ACP provider configuration
│   │   │       ├── KeybindingSettings.swift       # Customize all shortcuts
│   │   │       ├── AppearanceSettings.swift       # Theme, font, density
│   │   │       ├── PluginSettings.swift           # Manage installed plugins
│   │   │       └── ProjectSettings.swift          # Per-project configuration
│   │   └── Tests/
│   │
│   ├── AnvilEditor/                       # Editor engine (separate package)
│   │   ├── Sources/
│   │   │   ├── TextEngine/
│   │   │   │   ├── TextBuffer.swift               # Rope-based text buffer
│   │   │   │   ├── PieceTable.swift               # Piece table for edits
│   │   │   │   ├── UndoManager.swift
│   │   │   │   └── TextSelection.swift
│   │   │   ├── Rendering/
│   │   │   │   ├── EditorRenderer.swift           # Custom Metal/CoreText rendering
│   │   │   │   ├── LineNumberGutter.swift
│   │   │   │   ├── SyntaxHighlighter.swift        # Tree-sitter integration
│   │   │   │   ├── InlineDecorations.swift        # Git blame, coverage, errors
│   │   │   │   └── Minimap.swift
│   │   │   ├── LSP/
│   │   │   │   ├── LSPClient.swift                # Language Server Protocol client
│   │   │   │   ├── LSPManager.swift               # Manages language server lifecycles
│   │   │   │   ├── Completions.swift              # Autocomplete from LSP
│   │   │   │   ├── Diagnostics.swift              # Errors/warnings from LSP
│   │   │   │   ├── HoverProvider.swift            # Hover documentation
│   │   │   │   ├── GoToDefinition.swift
│   │   │   │   ├── FindReferences.swift
│   │   │   │   ├── RenameProvider.swift
│   │   │   │   ├── CodeActions.swift              # Quick fixes, refactors
│   │   │   │   └── SymbolProvider.swift           # Document/workspace symbols
│   │   │   └── TreeSitter/
│   │   │       ├── TreeSitterParser.swift
│   │   │       ├── LanguageGrammar.swift
│   │   │       └── Grammars/                      # Bundled language grammars
│   │   │           ├── swift.scm
│   │   │           ├── typescript.scm
│   │   │           ├── python.scm
│   │   │           ├── rust.scm
│   │   │           ├── go.scm
│   │   │           └── ... (30+ languages)
│   │   └── Tests/
│   │
│   ├── AnvilTerminal/                     # Terminal emulator package
│   │   ├── Sources/
│   │   │   ├── SwiftTermWrapper.swift
│   │   │   ├── ShellIntegration.swift             # CWD tracking, command detection
│   │   │   └── TerminalTheme.swift
│   │   └── Tests/
│   │
│   ├── AnvilGit/                          # Git operations package
│   │   ├── Sources/
│   │   │   ├── LibGit2Swift.swift                 # Swift wrapper for libgit2
│   │   │   ├── BranchManager.swift
│   │   │   ├── WorktreeEngine.swift               # Invisible worktree management
│   │   │   ├── DiffEngine.swift
│   │   │   ├── GraphBuilder.swift                 # DAG construction for visualization
│   │   │   ├── StackedDiffEngine.swift            # Stacked/dependent change tracking
│   │   │   ├── MergeEngine.swift
│   │   │   ├── BlameEngine.swift
│   │   │   └── AutoCommitter.swift                # Intelligent auto-commit boundaries
│   │   └── Tests/
│   │
│   ├── AnvilACP/                          # ACP client package
│   │   ├── Sources/
│   │   │   ├── ACPClient.swift                    # Unified client interface
│   │   │   ├── ACPProviderProtocol.swift
│   │   │   ├── Providers/
│   │   │   │   ├── AnthropicProvider.swift
│   │   │   │   ├── OpenAIProvider.swift
│   │   │   │   ├── GoogleProvider.swift
│   │   │   │   ├── OllamaProvider.swift
│   │   │   │   └── OpenAICompatibleProvider.swift # Generic for any compatible endpoint
│   │   │   ├── Streaming/
│   │   │   │   ├── SSEParser.swift
│   │   │   │   └── StreamProcessor.swift
│   │   │   ├── Tools/
│   │   │   │   ├── ToolRegistry.swift
│   │   │   │   ├── FileTools.swift                # Read/write/search files
│   │   │   │   ├── TerminalTools.swift            # Execute commands
│   │   │   │   ├── BrowserTools.swift             # Web browsing
│   │   │   │   └── PluginTools.swift              # Tools provided by plugins
│   │   │   └── CostTracking/
│   │   │       ├── TokenCounter.swift
│   │   │       ├── CostCalculator.swift
│   │   │       └── BudgetEnforcer.swift
│   │   └── Tests/
│   │
│   └── AnvilPluginSDK/                    # Public SDK for plugin developers
│       ├── Sources/
│       │   ├── PluginProtocol.swift                # Base protocol all plugins implement
│       │   ├── PrimitiveContract.swift             # How to provide for a primitive
│       │   ├── ViewRegistration.swift              # Register SwiftUI views
│       │   ├── CommandRegistration.swift           # Register command palette actions
│       │   ├── KeybindingRegistration.swift        # Register keyboard shortcuts
│       │   ├── ACPAccess.swift                     # Plugin's interface to ACP
│       │   ├── InterPluginCommunication.swift      # Request data from other plugins
│       │   ├── StorageAccess.swift                 # Plugin-scoped persistent storage
│       │   └── PluginMetadata.swift                # Plugin identity and capabilities
│       └── Tests/
│
├── App/                                   # Main app target
│   ├── AnvilApp.swift                     # Entry point
│   ├── Info.plist
│   ├── Anvil.entitlements                 # Sandbox, keychain, network, files
│   └── Resources/
│       ├── Assets.xcassets
│       └── Grammars/                      # Bundled tree-sitter grammars
│
├── Plugins/                               # First-party plugins (built as packages)
│   ├── AnvilGitHubPlugin/
│   ├── AnvilSlackPlugin/
│   ├── AnvilNeonPlugin/
│   ├── AnvilVercelPlugin/
│   ├── AnvilSentryPlugin/
│   ├── AnvilDockerPlugin/
│   └── AnvilFigmaPlugin/
│
└── Scripts/
    ├── bootstrap.sh                       # Dev environment setup
    ├── generate-grammars.sh               # Build tree-sitter grammars
    └── package-plugin.sh                  # Package a plugin for distribution
```

## Dependency Graph

```
AnvilPluginSDK  ←  (third-party plugins)
       ↑
AnvilDomain     ←  (zero external dependencies, pure Swift)
       ↑
AnvilApplication ← (depends on Domain only)
       ↑
AnvilInfrastructure ← (depends on Domain + Application + external libs)
       ↑
AnvilUI ← (depends on Application + Domain, NO direct Infrastructure imports)
       ↑
AnvilEditor ← (standalone, depends on Tree-sitter, LSP libs)
AnvilTerminal ← (standalone, depends on SwiftTerm)
AnvilGit ← (standalone, depends on libgit2)
AnvilACP ← (standalone, depends on Domain for types)
```

**Critical rule:** AnvilUI NEVER imports AnvilInfrastructure directly. All communication goes through Application layer protocols. This ensures providers are truly swappable at runtime.

## External Dependencies

| Dependency | Purpose | Package |
|-----------|---------|---------|
| libgit2 | Git operations | SwiftGit2 (forked, maintained) |
| SwiftTerm | Terminal emulator | SwiftTerm |
| GRDB | SQLite database | GRDB.swift |
| Tree-sitter | Syntax parsing | SwiftTreeSitter |
| KeychainAccess | Keychain wrapper | KeychainAccess |
| Nuke | Image loading/caching | Nuke |
| swift-markdown | Markdown parsing | swift-markdown |
| swift-collections | Ordered collections | swift-collections |

---

# PART 4: THE PRIMITIVES — COMPLETE SPECIFICATION

Every feature in Anvil is a Primitive — an abstract concept with a defined contract. Every primitive has one or more Providers — concrete implementations. Anvil ships default providers, but all are swappable. Plugins can add providers to existing primitives or introduce new primitives entirely.

```
Primitive (abstract contract / port)
  └── Provider (concrete implementation / adapter)
       └── Instance (configured connection)
```

First-party implementations use the exact same plugin API as third-party. No private APIs. No shortcuts.

## Primitive 1: Source Control

The versioning substrate.

**Port protocol: `SourceControlPort`**

**Domain types:**
- `Branch` — name, upstream, ahead/behind counts, is-current
- `Commit` — hash, author, date, message, parents, diff stats
- `Diff` — file-level and hunk-level changes with context
- `MergeConflict` — file, ours/theirs/base content, resolution status
- `Tag` — name, target commit, annotation
- `Stash` — message, diff, date
- `Worktree` — path, branch, clean/dirty status (internal, not exposed to user)

**Required provider capabilities:**
- `branches()` → list all branches
- `commits(branch:, range:)` → commit history
- `diff(from:, to:)` → diff between refs
- `diff(staged:)` → working copy changes
- `createBranch(name:, from:)` → create branch
- `merge(source:, into:, strategy:)` → merge
- `rebase(branch:, onto:)` → rebase
- `cherryPick(commit:)` → cherry-pick
- `revert(commit:)` → revert
- `blame(file:, ref:)` → line-by-line blame
- `log(file:)` → file history
- `stash()` / `stashPop()` / `stashList()`
- `createWorktree(branch:, path:)` → worktree management
- `removeWorktree(path:)`
- `autoCommit(message:, paths:)` → intelligent auto-commit

**ACP hooks (AI affordances available to any surface):**
- Generate commit message from staged diff
- Explain any commit in natural language
- Suggest branch name from work item context
- AI-assisted conflict resolution
- "Why did this line change?" — blame + commit context

**Views registered:**
- Sidebar section: Branches (list with indicators)
- Sidebar section: Stashes
- Main view: Git Graph (DAG visualization, zoomable, filterable, interactive)
- Main view: Stacked Diff (layered dependent changes, review bottom-up)
- Main view: Timeline (chronological, filterable)
- Inline annotation: Blame overlay (per-file, gutter)
- Inspector panel: Commit detail

**Default provider:** Git via libgit2
**Plugin providers:** Mercurial, SVN, Jujutsu, Pijul

---

## Primitive 2: Source Control Cloud

Remote hosting and collaboration.

**Port protocol: `SourceControlCloudPort`**

**Domain types:**
- `RemoteRepo` — name, URL, visibility, default branch, description
- `PullRequest` — title, description, source/target branches, status (open/merged/closed), reviewers, CI status, labels, comments, diff stats
- `PRComment` — body, file path, line number, thread, resolved status
- `RepoTemplate` — name, description, languages, preview URL
- `BranchProtectionRule` — branch pattern, required reviews, required CI
- `Release` — tag, title, body, assets, date

**Required provider capabilities:**
- `repos()` → list repositories
- `pullRequests(repo:, status:)` → list PRs
- `createPR(title:, description:, source:, target:)` → open PR
- `mergePR(id:, strategy:)` → merge PR
- `prComments(prId:)` → list comments
- `addComment(prId:, body:, file:, line:)` → add inline comment
- `ciStatus(prId:)` → CI check status
- `templates(org:)` → list repo templates
- `createRepo(name:, visibility:, template:)` → create remote repo
- `push(remote:, branch:)` / `pull(remote:, branch:)` / `fetch(remote:)`
- `releases(repo:)` → list releases
- `createRelease(tag:, title:, body:)` → create release

**ACP hooks:**
- Auto-generate PR description from diff + linked work items + project notes
- AI-powered PR review (security, style, correctness, performance)
- Draft release notes from merged PRs in range
- Suggest reviewers from code ownership + diff content

**Views registered:**
- Sidebar section: Pull Requests (list with status, CI, reviewer indicators)
- Main view: PR Detail (full review interface, inline comments, CI status, merge controls)
- Main view: Repo browser (files, branches, tags, releases)
- Main view: Template picker (for new project scaffolding)
- Inspector panel: PR metadata

**Default provider:** GitHub via REST + GraphQL API
**Plugin providers:** GitLab, Bitbucket, Gitea, Codeberg

---

## Primitive 3: Tickets

Project work tracking. The units of intent.

**Port protocol: `TicketPort`**

**Domain types:**
- `Ticket` — title, description (markdown), status, priority (P0-P4), assignee, labels, due date, story points, custom fields
- `TicketStatus` — open, in-progress, in-review, done, cancelled (configurable per project)
- `Cycle` — name, start date, end date, ticket IDs, velocity
- `Board` — name, columns (each column maps to a status), WIP limits
- `TicketRelation` — type (blocks, blocked-by, parent, child, duplicate, related), source, target
- `Epic` — a ticket that groups other tickets

**Required provider capabilities:**
- `tickets(filter:, sort:)` → list tickets
- `createTicket(title:, description:, priority:, labels:)` → create
- `updateTicket(id:, changes:)` → update any field
- `deleteTicket(id:)` → delete/archive
- `cycles()` → list cycles/sprints
- `createCycle(name:, dates:, ticketIds:)` → create cycle
- `boards()` → list boards
- `relations(ticketId:)` → get relations
- `addRelation(type:, source:, target:)` → create relation
- `moveTicketToStatus(id:, status:)` → status transition
- `customFields(project:)` → available custom fields

**ACP hooks:**
- Generate ticket from vague idea → structured with repro steps, acceptance criteria
- Break down epic into subtasks
- Auto-triage: suggest priority and labels from description
- Sprint planning: "Given velocity and backlog, suggest next cycle"
- Auto-close stale tickets with summary

**Views registered:**
- Sidebar section: Tickets (filterable list, grouped by status/priority/assignee)
- Sidebar section: Cycles (current + upcoming)
- Main view: Ticket Detail (rich editor, relations, linked branches/sessions, activity log)
- Main view: Board (kanban, draggable, WIP limits)
- Main view: Cycle timeline (burndown chart, velocity)
- Main view: Backlog (drag to prioritize)
- Main view: My Work (cross-project personal queue)

**Default provider:** Anvil Native (local SQLite, zero config)
**Plugin providers:** Linear, Jira, Asana, GitHub Issues, Shortcut, Notion databases

---

## Primitive 4: Code Review

Structured evaluation of changes. The human + AI judgment layer.

**Port protocol: `CodeReviewPort`**

**Domain types:**
- `Review` — source (PR, agent session, manual selection), status (pending, approved, changes-requested), reviewer, linked diff
- `ReviewComment` — body, file path, line range, thread, resolved status, is-ai-generated
- `ReviewChecklist` — items with checked status, configurable per project
- `ReviewSummary` — AI-generated overview of changes

**Required provider capabilities:**
- `pendingReviews()` → items needing review
- `submitReview(id:, status:, comments:)` → submit with inline comments
- `resolveComment(id:)` → mark comment resolved
- `requestReview(from:, for:)` → request review from user/team
- `checklist(project:)` → get review checklist
- `aiReview(diff:, context:)` → dispatch AI review (uses ACP)

**ACP hooks:**
- Full AI code review: security, correctness, performance, style, test coverage
- "Explain this change to me" per hunk
- Auto-generate review checklist from project conventions
- Summarize review thread for quick catch-up
- Adversarial review: dispatch second agent to critique first

**Views registered:**
- Sidebar section: Review Inbox (Superhuman-style triage: j/k, a/r, batch actions)
- Main view: Diff Review (side-by-side or unified, inline comments, approve/reject per hunk)
- Main view: Stacked Diff Review (layered changes, review bottom-up, per-layer approval)
- Main view: Review Comment Thread (discussion, resolution)
- Inspector panel: Review metadata, checklist status, CI status

**Keyboard model (Review Inbox):**
- `j/k` — navigate items
- `↵` — open review
- `a` — approve
- `r` — request changes
- `c` — add comment
- `n/p` — next/previous hunk in diff
- `⌘↵` — submit all pending reviews
- `x` — select for batch operation

**Default provider:** Anvil Native (works with any source control provider)
**Plugin providers:** Graphite, ReviewBoard, Gerrit

---

## Primitive 5: Agents

AI-powered work sessions. The core differentiator.

**Port protocol: `AgentPort`**

**Domain types:**
- `AgentSession` — id, provider, model, status (idle/running/paused/complete/failed), work item link, worktree path, token usage, cost, start time, conversation
- `AgentMessage` — role (user/assistant/system), content (text, tool calls, tool results), timestamp
- `ToolCall` — name, arguments, status (pending/approved/rejected/completed), result
- `ToolResult` — content, type (text, diff, image, error)
- `ApprovalPolicy` — per-tool-category rules (auto-approve reads, ask for writes, always ask for terminal)
- `SynthesisRoom` — input sessions, synthesis agent config, output (plan, merged code, conflict resolution)
- `AgentPlan` — structured list of intended steps, each with status (planned/active/complete/skipped), user annotations

**Required provider capabilities:**
- `startSession(prompt:, context:, model:, tools:)` → begin session with streaming
- `sendMessage(sessionId:, content:)` → continue conversation
- `approveToolCall(sessionId:, toolCallId:)` → approve pending action
- `rejectToolCall(sessionId:, toolCallId:, reason:)` → reject with feedback
- `pauseSession(sessionId:)` / `resumeSession(sessionId:)`
- `forkSession(sessionId:, fromMessage:)` → branch conversation
- `exportSession(sessionId:, format:)` → export as markdown/JSON
- `availableModels()` → list models from this provider
- `estimateCost(prompt:, model:)` → cost estimation

**ACP meta-hooks:**
- Session summarization (condense long session → key decisions + changes)
- Synthesis rooms (multi-session context merge)
- Adversarial dispatch (review agent critiques working agent)
- Auto-select model based on task complexity and cost budget
- Inject project notes as persistent context

**Views registered:**
- Sidebar section: Sessions (grouped by work item, status indicators, provider icons)
- Main view: Conversation (rich message rendering, inline diffs, collapsible tool calls, approve/reject buttons)
- Main view: Workspace (file tree of agent's worktree, diff-against-baseline per file)
- Main view: Plan (structured, editable, commentable agent intentions)
- Main view: Synthesis Room (multi-session merge interface)
- Main view: Multi-Session Dashboard (all active sessions, resource allocation)
- Inspector panel: Session metadata (model, tokens, cost, linked items)
- Command palette actions: launch, pause, switch provider, inject context, fork, synthesize

**Conversation sub-views (toggled with `⌘[` / `⌘]`):**
1. Conversation — the chat interaction
2. Workspace — file tree + diffs
3. Plan — structured intentions

**Default providers:** Anthropic Claude (API), OpenAI (API)
**Plugin providers:** Google Gemini, Ollama (local), Codex (cloud), Mistral, any OpenAI-compatible endpoint

---

## Primitive 6: Agent Skills & Marketplace

Discoverability and management of agent capabilities across providers.

**Port protocol: `AgentMarketplacePort`**

**Domain types:**
- `Skill` — id, name, description, provider compatibility, version, author, install status
- `SkillCompatibility` — which ACP providers support this skill
- `SkillConfig` — per-skill configuration (API keys, endpoints, permissions)
- `SkillCategory` — code, data, web, infrastructure, custom

**Required provider capabilities:**
- `searchSkills(query:, provider:, category:)` → search catalog
- `skillDetail(id:)` → full skill information
- `installSkill(id:, forProviders:)` → install for one or multiple providers
- `uninstallSkill(id:, forProviders:)` → remove
- `installedSkills()` → list currently installed
- `compatibilityCheck(skillId:, providers:)` → check compatibility

**ACP hooks:**
- "What skills would help with this task?" — suggest from marketplace
- Auto-configure skills from project context (detect Next.js → suggest Vercel MCP)
- Cross-provider install ("install Context7 for all my providers at once")

**Views registered:**
- Main view: Marketplace Browser (search, filter by provider/category, install buttons)
- Main view: Installed Skills Manager (per-project, global, update available indicators)
- Inspector panel: Skill detail (description, permissions, reviews, compatibility matrix)

**Default provider:** Anvil Marketplace (aggregates across ecosystems)
**Source providers:** Anthropic MCP Registry, OpenAI Plugin Directory, community registries

---

## Primitive 7: Observability

Error tracking, monitoring, alerting.

**Port protocol: `ObservabilityPort`**

**Domain types:**
- `ErrorEvent` — title, stack trace, severity, count, first/last seen, status (unresolved/resolved/ignored), tags, affected users
- `Alert` — rule, trigger condition, status (firing/resolved), notification targets
- `Metric` — name, type (counter/gauge/histogram), values, time series
- `HealthCheck` — service, status, latency, last checked

**Required provider capabilities:**
- `errors(filter:, timeRange:)` → list errors
- `errorDetail(id:)` → full error with stack trace, breadcrumbs, user context
- `acknowledgeError(id:)` / `resolveError(id:)` / `ignoreError(id:)`
- `alerts()` → list alert rules and status
- `metrics(names:, timeRange:)` → metric time series
- `healthChecks()` → service health overview

**ACP hooks:**
- Auto-triage: AI reads stack trace, searches codebase, suggests root cause
- "Explain this error" in plain language
- Auto-generate ticket from error with full context
- Correlate errors with recent deployments
- Anomaly detection alerts

**Views registered:**
- Sidebar section: Errors (list with severity indicators and counts)
- Sidebar section: Alerts (active/resolved)
- Main view: Error Feed (real-time, filterable)
- Main view: Error Detail (stack trace, breadcrumbs, linked deploys)
- Main view: Metrics Dashboard (charts, key indicators)
- Main view: Health Status (service map with status colors)

**Default provider:** None (must configure)
**Plugin providers:** Sentry, Datadog, New Relic, Grafana, BetterStack, Highlight.io, PagerDuty

---

## Primitive 8: Database

Direct database interaction.

**Port protocol: `DatabasePort`**

**Sub-protocols for different engine types:**
- `RelationalDatabasePort` — SQL-based operations
- `DocumentDatabasePort` — document-based operations
- `KeyValueDatabasePort` — key-value operations

**Domain types:**
- `DatabaseConnection` — host, port, database name, credentials reference (→ Secrets primitive), engine type
- `Schema` — tables/collections, columns/fields, types, indexes, relations, constraints
- `QueryResult` — columns, rows, timing, explain plan
- `Migration` — id, name, up/down SQL/script, status (pending/applied/failed), applied date

**Required provider capabilities:**
- `connect(connection:)` → establish connection
- `schema()` → introspect schema
- `execute(query:)` → run query, return results
- `explain(query:)` → explain query plan
- `migrations(directory:)` → list migrations with status
- `runMigration(id:)` / `rollbackMigration(id:)`
- `tables()` → list tables/collections
- `rows(table:, filter:, limit:, offset:)` → browse data
- `insertRow(table:, data:)` / `updateRow(table:, id:, data:)` / `deleteRow(table:, id:)`

**ACP hooks:**
- Natural language to SQL: "show me users who signed up last week without email verification"
- Explain query plan in plain language
- Suggest indexes for slow queries
- Auto-generate migration from description
- Validate migration safety ("will lock table for ~4min at current size")
- Generate seed data from schema

**Views registered:**
- Sidebar section: Connections (saved databases with status)
- Sidebar section: Tables/Collections (tree view per connection)
- Main view: Schema Browser (tables, columns, types, ER diagram)
- Main view: Query Console (multi-tab, syntax highlighted, autocomplete from schema)
- Main view: Results Table (sortable, filterable, paginated, inline editing)
- Main view: Migration Timeline (history, pending, per-environment status)
- Main view: Branch Explorer (for Neon: database branches alongside git branches)

**Relational providers:** PostgreSQL, MySQL, SQLite, MSSQL
**Document providers:** MongoDB, DynamoDB, Firestore
**Key-value providers:** Redis, Valkey
**Cloud platform providers:** Neon, Supabase, PlanetScale, CockroachDB, Turso

---

## Primitive 9: Hosting & Deployment

Where code runs. The Ship mode backbone.

**Port protocol: `HostingPort`**

**Domain types:**
- `Deployment` — id, environment, branch/commit, status (building/deploying/live/failed/rolled-back), URL, timestamp, build log
- `Environment` — name (preview/staging/production), URL, variables, linked branch
- `EnvironmentVariable` — key, value (masked for secrets), scope
- `BuildLog` — streaming text, timestamp per line, exit code
- `Domain` — hostname, DNS records, SSL status

**Required provider capabilities:**
- `environments()` → list environments
- `deploy(environment:, ref:)` → trigger deployment
- `deploymentStatus(id:)` → get current status
- `buildLog(deploymentId:)` → stream build output
- `rollback(environment:, toDeployment:)` → rollback
- `envVars(environment:)` → list environment variables
- `setEnvVar(environment:, key:, value:)` → set variable
- `deleteEnvVar(environment:, key:)` → remove variable
- `domains(environment:)` → list configured domains
- `previewURL(deploymentId:)` → get preview URL

**ACP hooks:**
- "Explain this build failure" — reads logs, cross-references recent changes
- Auto-generate deployment plan for multi-service releases
- "Is it safe to deploy?" — checks CI, error rates, pending migrations
- Auto-generate changelog from merged PRs
- Cost estimation from usage patterns

**Views registered:**
- Sidebar section: Environments (list with status indicators)
- Sidebar section: Recent Deployments
- Main view: Deploy Dashboard (environments, current status, controls)
- Main view: Build Log Viewer (streaming, searchable, collapsible steps)
- Main view: Environment Config (vars, secrets, diff across environments)
- Main view: Preview Browser (inline frame, shareable link)
- Main view: Rollback (one-click with confirmation and change diff)

**Serverless providers:** Vercel, Netlify, Cloudflare Pages
**Container/PaaS providers:** Railway, Fly.io, Render, Heroku, Google Cloud Run
**IaaS providers:** AWS, GCP, Azure
**Edge providers:** Cloudflare Workers, Deno Deploy

---

## Primitive 10: Remote Environments & Tunnels

Develop against remote machines, cloud dev environments, or expose local services.

**Port protocol: `RemoteEnvironmentPort`**

**Domain types:**
- `RemoteConnection` — host, port, user, auth method (key/password/agent), status, jump proxy
- `Tunnel` — local port, remote host:port, direction (local/remote), status, public URL (for reverse tunnels)
- `DevEnvironment` — name, image, status (running/stopped/creating), resources (CPU/RAM), ports, SSH details

**Required provider capabilities:**
- `connect(connection:)` → establish SSH/remote connection
- `disconnect(connectionId:)`
- `listFiles(connectionId:, path:)` → remote file browser
- `readFile(connectionId:, path:)` / `writeFile(connectionId:, path:, content:)`
- `createTunnel(connectionId:, localPort:, remotePort:, direction:)` → port forward
- `closeTunnel(tunnelId:)`
- `createDevEnv(image:, resources:)` → spin up cloud dev environment
- `startDevEnv(id:)` / `stopDevEnv(id:)` / `destroyDevEnv(id:)`

**ACP hooks:**
- "Set up a dev environment for this project" — reads config, suggests container, ports, env vars
- Diagnose connection issues (key permissions, known_hosts, firewall)
- Auto-configure port forwarding from docker-compose or Procfile

**Views registered:**
- Sidebar section: Connections (saved hosts, status)
- Sidebar section: Tunnels (active, with URLs)
- Main view: Connection Manager (add, edit, test, quick-connect)
- Main view: Remote File Browser (integrated with editor + source control)
- Main view: Tunnel Dashboard (active tunnels, traffic stats)
- Main view: Dev Environment Manager (list, create, resource allocation)

**Providers:** SSH (default), GitHub Codespaces, Gitpod, DevPod, Coder, ngrok, Cloudflare Tunnel, Tailscale

---

## Primitive 11: Documentation

Knowledge lives here.

**Port protocol: `DocumentationPort`**

**Sub-protocols:**
- `InternalDocPort` — team knowledge (editable, collaborative)
- `ExternalDocPort` — reference material (read-only, indexed)

**Domain types:**
- `Document` — title, body (markdown/rich text), path in hierarchy, version, author, last modified
- `DocFolder` — name, children (docs + sub-folders)
- `DocComment` — inline comment on document, thread, resolved status
- `ExternalDocSource` — name, URL, version, index status
- `DocSearchResult` — document ref, snippet, relevance score

**Required provider capabilities (Internal):**
- `documents(folder:)` → list documents
- `documentContent(id:)` → get full content
- `createDocument(title:, body:, folder:)` → create
- `updateDocument(id:, body:)` → update
- `documentHistory(id:)` → version history
- `comments(documentId:)` → list comments
- `addComment(documentId:, body:, position:)` → add inline comment
- `search(query:)` → full-text search

**Required provider capabilities (External):**
- `sources()` → list indexed sources
- `addSource(url:, version:)` → index external docs
- `removeSource(id:)` → remove
- `search(query:, source:)` → search across external docs
- `browse(source:, path:)` → navigate doc structure

**ACP hooks:**
- Auto-generate docs from code (README, API docs, architecture overview)
- Keep docs in sync with code changes ("this PR changes auth — update auth docs?")
- Search across all docs with natural language
- Summarize long documents or RFC threads
- Agents access all indexed docs as context (no copy-pasting)

**Views registered:**
- Sidebar section: Internal Docs (tree)
- Sidebar section: External Sources (indexed sites)
- Main view: Doc Browser (tree nav, content area, outline/TOC)
- Main view: Doc Editor (markdown with live preview, or rich text)
- Main view: Multi-Doc Search (unified across internal + external)
- Main view: Doc Diff (version comparison)
- Main view: Reference Panel (pin external docs alongside editor)

**Internal providers:** Anvil Native (local markdown, git-backed), Notion, Confluence, Google Docs, Slite, Outline
**External providers:** DevDocs, Dash, custom doc sites (crawl + index), Context7

---

## Primitive 12: Messaging & Communication

Talk to your team without leaving.

**Port protocol: `MessagingPort`**

**Domain types:**
- `Channel` — name, type (public/private/DM), unread count, members, topic
- `Message` — author, body (rich text, code blocks, attachments), timestamp, thread, reactions, edited
- `Thread` — parent message, reply count, participants
- `Presence` — user, status (online/offline/busy/away), custom status text

**Required provider capabilities:**
- `channels()` → list channels
- `messages(channelId:, cursor:)` → paginated messages
- `sendMessage(channelId:, body:, thread:)` → send
- `editMessage(id:, body:)` → edit
- `deleteMessage(id:)` → delete
- `addReaction(messageId:, emoji:)` → react
- `threads(channelId:)` → list active threads
- `search(query:, channels:)` → search messages
- `presence()` → current team presence
- `markRead(channelId:)` → mark channel as read

**ACP hooks:**
- Summarize unread threads ("catch me up on #engineering")
- Draft reply based on conversation context
- "Turn this thread into a ticket" — extract action items, create structured ticket
- Auto-notify channel on deployment/error events
- Smart notification filtering: surface what needs attention

**Views registered:**
- Sidebar section: Channels (with unread indicators, priority sorted)
- Sidebar section: Direct Messages
- Main view: Chat View (message list, thread panel, reactions)
- Main view: Unified Inbox (all mentions and DMs across providers, Superhuman-style)
- Main view: Search Results (cross-channel, cross-provider)

**Providers:** Slack, Discord, Microsoft Teams, Zulip, Matrix, IRC

---

## Primitive 13: CI/CD & Automation

Build, test, deploy pipelines.

**Port protocol: `CICDPort`**

**Domain types:**
- `Pipeline` — name, trigger (push/PR/schedule/manual), steps, last run status
- `BuildRun` — pipeline, trigger ref, status (queued/running/passed/failed/cancelled), duration, steps with individual status
- `BuildStep` — name, status, duration, log output
- `TestResult` — suite, name, status (pass/fail/skip), duration, output, is-flaky
- `Artifact` — name, type, size, download URL

**Required provider capabilities:**
- `pipelines(repo:)` → list pipelines
- `runs(pipeline:, branch:)` → list runs
- `runDetail(id:)` → full run with steps
- `logs(runId:, step:)` → streaming logs
- `triggerRun(pipeline:, ref:)` → manual trigger
- `cancelRun(id:)` → cancel
- `rerunRun(id:)` → re-run
- `testResults(runId:)` → test results
- `artifacts(runId:)` → build artifacts

**ACP hooks:**
- "Why did this build fail?" — reads logs, identifies root cause, suggests fix
- "Is this test flaky?" — analyzes pass/fail history
- Auto-generate CI config for new projects
- Suggest pipeline parallelization
- Estimate build time impact of changes

**Views registered:**
- Sidebar section: Pipelines (status per pipeline)
- Sidebar section: Recent Runs
- Main view: Pipeline Dashboard (runs, duration trends, success rate)
- Main view: Build Detail (steps, logs, artifacts, test results)
- Main view: Test Report (pass/fail, flaky tracker, coverage)
- Main view: Build Queue (pending, running, scheduled)

**Providers:** GitHub Actions, CircleCI, GitLab CI, Jenkins, Buildkite, Dagger, Earthly

---

## Primitive 14: Containerization & Infrastructure

Containers, compose stacks, infrastructure-as-code.

**Port protocol: `ContainerPort`**

**Domain types:**
- `Container` — id, image, status (running/stopped/created), ports, resource usage, logs
- `ContainerImage` — name, tag, size, created, layers, vulnerabilities
- `ComposeStack` — services, networks, volumes, status
- `InfraResource` — type, name, status, provider, cost
- `IaCPlan` — resources to add/change/destroy, diff

**Required provider capabilities:**
- `containers()` → list containers
- `startContainer(id:)` / `stopContainer(id:)` / `removeContainer(id:)`
- `containerLogs(id:, follow:)` → log streaming
- `images()` → list images
- `buildImage(dockerfile:, tag:)` → build
- `composeUp(path:)` / `composeDown(path:)` → compose lifecycle
- `composeServices(path:)` → list services with status
- `plan(directory:)` → IaC plan (dry run)
- `apply(directory:)` → IaC apply

**ACP hooks:**
- "Generate a Dockerfile for this project" — reads package files, suggests multi-stage build
- Explain docker-compose configuration
- Analyze container resource usage, suggest right-sizing
- Security scan Dockerfile for vulnerabilities
- Translate between IaC formats

**Views registered:**
- Sidebar section: Containers (running, with resource bars)
- Sidebar section: Images (local)
- Main view: Container Dashboard (list, resource usage, port mappings)
- Main view: Compose Visualizer (service graph, dependency flow, health)
- Main view: Image Browser (layers, vulnerability scan results)
- Main view: IaC Plan Viewer (resource diff before apply)

**Providers:** Docker, Podman, Kubernetes, Terraform, Pulumi, AWS CDK

---

## Primitive 15: Testing

First-class test management.

**Port protocol: `TestingPort`**

**Domain types:**
- `TestSuite` — name, file path, test count, pass/fail/skip counts
- `TestCase` — name, suite, status (pass/fail/skip/error), duration, output, assertions
- `CoverageReport` — per-file coverage (line/branch/function percentages), uncovered ranges
- `TestSnapshot` — name, current content, expected content, diff, status (match/mismatch/new)
- `FlakyTest` — test ref, pass rate, history of recent runs

**Required provider capabilities:**
- `discover(directory:)` → find all tests
- `run(tests:, filter:)` → execute tests, stream results
- `runFile(path:)` → run tests in single file
- `runSingle(test:)` → run single test
- `coverage(directory:)` → generate coverage report
- `snapshots(directory:)` → list snapshots
- `updateSnapshot(name:)` → accept new snapshot
- `watch(directory:)` → watch mode with file change detection

**ACP hooks:**
- Generate tests from code ("write tests for this function")
- "Why is this test failing?" — reads assertion, source, suggests fix
- Generate test data / fixtures
- Suggest missing test coverage
- Convert between test frameworks

**Views registered:**
- Sidebar section: Test Explorer (tree, with run buttons and status per suite/test)
- Main view: Test Results (per-run, inline failure details and output)
- Main view: Coverage Overlay (gutter markers in editor, per-file percentages)
- Main view: Flaky Dashboard (ranked by flakiness, history graphs)
- Main view: Snapshot Manager (review, approve, reject snapshots)

**Providers:** Jest, Vitest, Pytest, Go test, Playwright, Cypress, RSpec, JUnit, Cargo test, Swift Testing

---

## Primitive 16: API Development & Testing

Design, test, document APIs.

**Port protocol: `APIClientPort`**

**Domain types:**
- `HTTPRequest` — method, URL, headers, body, auth, environment variables
- `RequestCollection` — name, folders, requests
- `HTTPResponse` — status, headers, body, timing breakdown
- `APISchema` — type (OpenAPI/GraphQL), endpoints, types, auth methods
- `MockServer` — routes, responses, delay, status

**Required provider capabilities:**
- `send(request:)` → execute HTTP request
- `collections()` → list saved collections
- `saveRequest(collection:, request:)` → save to collection
- `importCollection(format:, data:)` → import from Postman/Insomnia/Bruno
- `schema(url:)` → fetch and parse API schema
- `startMock(routes:)` / `stopMock()`

**ACP hooks:**
- Generate request from natural language
- Generate API docs from request/response pairs
- "Debug this 500" — reads response, checks logs if observability connected
- Generate mock data matching schema
- Convert between API description formats

**Views registered:**
- Sidebar section: Collections (folder tree)
- Sidebar section: Schemas (imported API specs)
- Main view: Request Builder (method, URL, headers, body tabs, auth)
- Main view: Response Viewer (formatted JSON/XML, headers, timing)
- Main view: Schema Explorer (endpoints, types, try-it-live)
- Main view: History (recent requests, replayable)

**Default provider:** Built-in HTTP client
**Import providers:** Postman, Insomnia, Bruno, Hoppscotch

---

## Primitive 17: Secrets & Configuration

Manage sensitive values.

**Port protocol: `SecretsPort`**

**Domain types:**
- `Secret` — key, value (encrypted/masked), scope (project/environment), last rotated, last accessed
- `Vault` — name, provider, secrets count
- `SecretAuditEntry` — secret ref, action (read/write/delete), timestamp, actor

**Required provider capabilities:**
- `secrets(scope:)` → list secrets (values masked)
- `getSecret(key:, scope:)` → retrieve value
- `setSecret(key:, value:, scope:)` → create/update
- `deleteSecret(key:, scope:)` → remove
- `rotationStatus(key:)` → when last rotated, reminder status
- `auditLog(key:)` → access history
- `injectIntoEnv(scope:)` → generate .env content for a given scope

**ACP hooks:**
- Detect hardcoded secrets in code, suggest migration to vault
- Auto-populate .env from vault for given environment
- "What secrets does this project need?" — reads config, suggests requirements

**Views registered:**
- Sidebar section: Vaults (configured secret stores)
- Main view: Vault Browser (secrets by project/environment)
- Main view: Environment Diff ("staging has X but preview doesn't")
- Main view: Audit Log (access history, rotation status)
- Inspector panel: Secret metadata (last rotated, accessed by)

**Default provider:** Anvil Vault (local, macOS Keychain-backed)
**Plugin providers:** 1Password, Doppler, HashiCorp Vault, AWS Secrets Manager, Infisical

---

## Primitive 18: Voice & Audio

Voice as input modality.

**Port protocol: `VoicePort`**

**Domain types:**
- `VoiceSession` — status (idle/listening/processing/speaking), transcription buffer, linked agent session
- `Transcription` — text, confidence, speaker, timestamps
- `VoiceCommand` — trigger phrase, mapped action

**Required provider capabilities:**
- `startListening()` → begin voice capture
- `stopListening()` → end capture
- `transcribe(audio:)` → convert to text
- `synthesize(text:)` → text to speech
- `voiceCommands()` → registered voice commands

**ACP hooks:**
- Dictate agent prompts instead of typing
- "Walk me through this code" — agent explains while you navigate
- Voice-driven code review: speak comments, transcribed and attached to lines
- Ambient mode: agent listens as you think aloud, suggests periodically
- Meeting note → action items → tickets pipeline

**Views registered:**
- Status bar: Voice indicator (recording state, quick toggle)
- Overlay: Transcription view (live, editable)
- Settings: Voice configuration (input device, provider, language, wake word)

**Providers:** macOS Speech (default), Whisper (local), Deepgram, AssemblyAI, ElevenLabs (TTS)

---

## Primitive 19: Design & Assets

Bridge between design and implementation.

**Port protocol: `DesignPort`**

**Domain types:**
- `DesignFile` — name, type, pages/frames, last modified, thumbnail
- `DesignComponent` — name, measurements, styles, constraints
- `DesignToken` — name, type (color/spacing/typography/shadow), value, code variable mapping
- `Asset` — name, format, resolutions, export settings

**Required provider capabilities:**
- `files(project:)` → list design files
- `frames(fileId:)` → list frames/pages
- `inspect(componentId:)` → measurements, colors, typography, spacing
- `exportAsset(componentId:, format:, scale:)` → export
- `tokens(fileId:)` → extract design tokens
- `syncTokens(tokens:, codeTarget:)` → sync tokens to code variables

**ACP hooks:**
- "Implement this design" — agent receives spec + assets, generates component code
- Design-code drift detection ("button color doesn't match token")
- Generate design tokens from file
- Screenshot implementation and overlay against design

**Views registered:**
- Sidebar section: Design Files (from connected tool)
- Main view: Design Browser (frames, pages, components, thumbnails)
- Main view: Inspection Panel (select element → dimensions, colors, spacing)
- Main view: Token Manager (tokens with code variable mapping, sync status)
- Main view: Comparison Overlay (design reference alongside implementation)

**Providers:** Figma, Sketch (file-based), Penpot, Zeplin

---

## Primitive 20: Personal Tasks & Notes

Your stuff. Not work tickets.

**Port protocol: `PersonalTaskPort`**

**Domain types:**
- `PersonalTask` — title, notes, priority, due date, tags, status (todo/done/someday)
- `DailyLog` — date, entries (auto-populated from activity + manual), summary
- `Bookmark` — title, type (link/file/code-snippet), content, tags, source
- `QuickNote` — text (markdown), timestamp, tags

**Required provider capabilities:**
- `tasks(filter:)` → list tasks
- `createTask(title:, notes:, priority:, due:)` → create
- `completeTask(id:)` / `uncompleteTask(id:)` → toggle
- `dailyLog(date:)` → get/create daily log
- `addLogEntry(date:, content:)` → append to log
- `bookmarks(filter:)` → list bookmarks
- `createBookmark(title:, type:, content:, tags:)` → save
- `quickNotes()` → list notes
- `createQuickNote(text:)` → quick capture

**ACP hooks:**
- "What should I focus on today?" — synthesizes tickets, PRs, messages, personal tasks
- Turn stray thought into structured task
- End-of-day summary: shipped, pending, blocked
- Resurface relevant bookmarks when working on related code
- Weekly retrospective generation

**Views registered:**
- Global overlay: Quick Capture (`⌘⇧Space` — type, dismiss)
- Sidebar section: Today (tasks due today + calendar events)
- Sidebar section: Bookmarks
- Main view: Task List (today / upcoming / someday, keyboard-navigable)
- Main view: Daily Log (chronological, auto + manual entries)
- Main view: Bookmarks (tagged, searchable, filterable by type)

**Default provider:** Anvil Native (local, private, optional iCloud sync)
**Plugin providers:** Todoist, Things 3, Apple Reminders, Obsidian vault

---

## Primitive 21: Schedule & Calendar

Time management, integrated with everything.

**Port protocol: `SchedulePort`**

**Domain types:**
- `CalendarEvent` — title, start, end, location, attendees, notes, recurrence, calendar source, linked ticket/PR
- `TimeBlock` — type (focus/meeting/break), start, end, label, linked work items
- `Availability` — time ranges with free/busy status
- `DailyAgenda` — merged view of events + time blocks + task due dates

**Required provider capabilities:**
- `events(dateRange:, calendars:)` → list events
- `createEvent(title:, start:, end:, attendees:, notes:)` → create
- `updateEvent(id:, changes:)` → update
- `deleteEvent(id:)` → delete
- `calendars()` → list available calendars
- `availability(dateRange:)` → free/busy
- `timeBlocks(dateRange:)` → list focus/meeting blocks
- `createTimeBlock(type:, start:, end:, label:, workItems:)` → block time for work item

**ACP hooks:**
- "Schedule 2 hours of focus time for this ticket" — finds open slot, creates block
- "When am I free for a 30-min sync this week?" — checks availability
- Daily briefing: "Today you have 3 meetings, 2 focus blocks, 5 tickets in progress"
- Auto-suggest focus blocks based on ticket deadlines and estimated effort
- "Reschedule my afternoon" — AI rebalances time blocks around new constraint

**Views registered:**
- Sidebar section: Today's Agenda (chronological, compact)
- Sidebar section: Upcoming (next few days)
- Main view: Calendar (day/week/month, with time blocks and events interleaved)
- Main view: Focus Planner (drag tickets onto time blocks, auto-estimate duration)
- Main view: Availability Grid (for scheduling meetings)
- Status bar: Next event/block indicator with countdown

**Default provider:** Anvil Native (local time blocks) + Apple Calendar (system events)
**Plugin providers:** Google Calendar, Outlook/Exchange, Fantastical, Cal.com

---

## Primitive 22: Notifications & Inbox

The unified attention manager.

**Port protocol: `NotificationPort`**

**Domain types:**
- `Notification` — source primitive, type, title, body, priority (critical/high/normal/low), timestamp, read status, action URL, linked entities
- `NotificationRule` — condition (source + type + pattern), action (priority override, auto-archive, route to channel, snooze)
- `NotificationDigest` — time period, grouped notifications, AI summary

**Required provider capabilities:**
- `notifications(filter:, cursor:)` → paginated notifications
- `markRead(ids:)` / `markUnread(ids:)` / `archive(ids:)` / `snooze(ids:, until:)`
- `rules()` → list routing rules
- `createRule(condition:, action:)` → add rule
- `digest(period:)` → generate digest with AI summary

**ACP hooks:**
- Intelligent triage: "3 things need attention now, 12 can wait"
- Summarize notification batches
- Auto-route: build failures → high, dependabot → low
- "Catch me up" — morning briefing from overnight notifications
- Smart focus mode: only show truly critical items

**Views registered:**
- Mode: Notifications Mode (`⌘0` or dedicated shortcut)
- Main view: Inbox (Superhuman-style: j/k, e archive, s snooze, ↵ act)
- Main view: Focus Mode (critical only)
- Main view: Activity Feed (chronological stream across all primitives)
- Status bar: Unread count badge
- Menu bar: Notification popover (quick glance without entering mode)

**Default provider:** Anvil Native (aggregates from all configured primitives)

---

## Primitive 23: Search & Navigation

Find anything, anywhere, instantly.

**Port protocol: `SearchPort`**

**Domain types:**
- `SearchResult` — source primitive, type, title, snippet, relevance score, URL/path
- `SearchScope` — all, or filtered by primitive(s), project(s), time range
- `RecentItem` — type, title, timestamp, path (for quick-switch)

**Required provider capabilities:**
- `search(query:, scope:)` → full-text search across all indexed content
- `semanticSearch(query:, scope:)` → AI-powered semantic search
- `recentItems(limit:)` → recently viewed/edited items
- `index(content:, source:)` → add to search index
- `deindex(source:)` → remove from index

**ACP hooks:**
- Natural language search: "where do we handle webhook auth?"
- "Find all code related to this ticket"
- Semantic search across docs and agent sessions
- "What did we discuss about the migration?" — cross-primitive search

**Views registered:**
- Command palette: `⌘K` (everything search)
- Command palette: `⌘⇧P` (commands only)
- Quick switch: `⌘E` (recent items)
- Main view: Search Results (grouped by primitive, with previews and actions)

**Default provider:** Anvil Native (local full-text index, updated real-time)
**Plugin providers:** Sourcegraph, GitHub Code Search

---

## Primitive 24: Analytics & Usage

Understand your development process.

**Port protocol: `AnalyticsPort`**

**Domain types:**
- `UsageMetric` — type (tokens/cost/time/success-rate), value, provider, project, time period
- `VelocityMetric` — tickets completed, PRs merged, deploy frequency, per time period
- `CostReport` — breakdown by provider, project, task type
- `ActivityEntry` — timestamp, action, primitive, entity, duration

**Required provider capabilities:**
- `metrics(type:, timeRange:, groupBy:)` → query metrics
- `costReport(timeRange:, groupBy:)` → cost breakdown
- `activityLog(timeRange:)` → chronological activity
- `velocityReport(timeRange:)` → development velocity

**ACP hooks:**
- "How much did I spend on AI this week?"
- "Which model gives best results for code review?"
- Suggest model/provider switches for cost-effectiveness
- Weekly retrospective: auto-generated summary of shipped/in-progress/blocked
- Productivity insights: "You ship 2x more when you use focus blocks"

**Views registered:**
- Main view: Dashboard (configurable widgets, key metrics)
- Main view: Cost Breakdown (per provider, project, task type, time series)
- Main view: Activity Timeline (correlated with productivity)
- Main view: Velocity Charts (trends, comparisons)

**Default provider:** Anvil Native (computed from local activity data)

---

## Primitive 25: Package Management

Dependencies as first-class.

**Port protocol: `PackageManagementPort`**

**Domain types:**
- `Dependency` — name, current version, latest version, type (direct/dev/transitive), license
- `Vulnerability` — CVE, severity, affected versions, fixed version, affected dependency path
- `LockfileDiff` — changes between two lockfile versions

**Required provider capabilities:**
- `dependencies(directory:)` → list all dependencies with versions
- `outdated(directory:)` → list dependencies with available updates
- `update(packages:)` → update specific packages
- `audit(directory:)` → vulnerability scan
- `licenseCheck(directory:)` → license compliance report
- `dependencyTree(directory:)` → full dependency graph
- `lockfileDiff(from:, to:)` → diff between lockfile versions

**ACP hooks:**
- "Is it safe to update this?" — checks changelog, breaking changes, vulnerabilities
- Auto-generate migration guide for major version bumps
- "Which dependencies are unmaintained?"
- Suggest alternatives for deprecated packages

**Views registered:**
- Sidebar section: Dependencies (direct, with update indicators)
- Main view: Dependency Tree (visual, filterable, vulnerability markers)
- Main view: Update Dashboard (available updates, risk assessment, batch update)
- Main view: Vulnerability Report (CVEs, severity, affected paths, fixes)
- Main view: License Report (compliance status per dependency)

**Auto-detect providers:** npm/yarn/pnpm, pip/poetry/uv, cargo, go mod, bundler, pub, Swift Package Manager

---

# PART 5: CROSS-CUTTING SYSTEMS

## The Worktree Engine

Every agent session gets its own worktree automatically. Users never see worktree paths or run worktree commands.

**Lifecycle:**
1. Agent session starts → Anvil creates branch from configured base
2. Creates worktree in `~/.anvil/worktrees/{project}/{session-id}/`
3. Points agent's working directory at worktree
4. Monitors file changes for Workspace view in real-time
5. Auto-commits at meaningful boundaries (agent step complete, user approval)
6. On session complete → worktree available for review
7. On merge → worktree cleaned up
8. Periodic garbage collection of stale worktrees

**What this enables:**
- Parallel agents on same repo (3 agents, 3 features, 3 worktrees, no conflicts)
- Instant context switching (click session → see its worktree state, zero latency)
- Always-available branches (every branch always "checked out" somewhere)
- Clean auto-tracking (isolated worktrees = safe auto-commit)

**Branching architecture:**
- Each work item → branch
- Each agent session on work item → same branch or sub-branch
- Stacked changes tracked as branch chains with known dependencies
- Merge/rebase operations respect the stack

## The ACP System

Agent Communication Protocol is the universal AI backbone. Every AI affordance in every primitive flows through ACP.

**Router configuration:**
```
Task Type          → Default Provider   → Fallback
─────────────────────────────────────────────────────
Code generation    → Claude Opus        → Claude Sonnet
Code review        → Claude Opus        → Codex
Commit messages    → Claude Haiku       → local Qwen
Ticket generation  → Claude Sonnet      → Gemini Flash
Summarization      → Claude Haiku       → local Phi
Doc generation     → Claude Sonnet      → Gemini Pro
```

Users configure this table. Per-project overrides supported. Cost budgets per provider, per project, per day.

**Plugin ACP access:**
```swift
// Any plugin can do this — no API key needed
let response = try await anvil.acp.complete(
    prompt: "Generate a commit message for this diff: \(diff)",
    model: .default,
    taskType: .commitMessage
)
```

This is the moat. Every plugin gets AI for free through the user's existing connection.

## The Event Bus

Domain events enable cross-primitive automation without coupling.

**Key event flows:**
- `AgentSessionCompleted` → creates review item in Code Review
- `PRMerged` → triggers deployment (if auto-deploy configured), closes linked ticket
- `BuildFailed` → creates notification (critical), logs to observability
- `ErrorSpiked` → creates alert, correlates with recent deployment
- `TicketStatusChanged` → updates board view, notifies assignee
- `DeploymentCompleted` → creates notification, updates environment status
- `TestsFailed` → blocks PR merge, creates notification

Event handlers are composable. Plugins can register handlers for any domain event.

## The Keyboard System

**Global shortcuts (always available):**
```
⌘K          Command palette (everything search)
⌘⇧P         Command palette (commands only)
⌘E          Quick switch (recent items)
⌘1-4        Switch to mode (Intent/Agent/Review/Ship)
⌘5-0        Switch to auxiliary modes
⌘N          New item (context-dependent: ticket, session, doc, etc.)
⌘⇧A         New agent session
⌘⇧N         Append to project notes (from anywhere)
⌘⇧Space     Quick capture (personal task/note overlay)
⌘,          Settings
⌘⇧I         Toggle inspector panel
⌘T          New tab
⌘W          Close tab
⌘⇧[/]       Switch tabs
⌘\          Split right
⌘⇧\         Split down
⌘B          Toggle sidebar
⌘J          Toggle bottom panel (terminal)
⌘.          Quick actions for current selection
```

**List navigation (any list, anywhere):**
```
j/k         Move down/up
↵           Open/expand
⌘↵          Open in split
x           Toggle select
⇧X          Select all visible
/           Filter (type to filter)
```

**Chord sequences (vim-style go-to):**
```
g t         Go to linked ticket
g b         Go to linked branch
g p         Go to linked PR
g d         Go to linked deployment
g a         Go to linked agent session
g n         Go to project notes
g c         Go to linked CI run
```

**Mode-specific shortcuts documented in each primitive above.**

All keybindings are user-configurable. Conflict detection built in. Import from VS Code / Vim / Emacs / Sublime presets.

## The Project Lifecycle

**Birth:**
1. `⌘N` → "New Project"
2. Options: Blank (empty repo) / From Template (GitHub templates) / From Repo (clone URL or GitHub picker) / From Directory (existing local folder)
3. Immediately a git repo. Always tracked. Always has source control.

**Development:**
Work flows through Intent → Agent → Review → Ship. Git history grows organically. Auto-commits at meaningful boundaries. Manual commits always available too.

**Graduation:**
When local project is ready for remote:
- `⌘K` → "Push to GitHub"
- Creates remote repo (name, visibility, org)
- Pushes full history
- Sets up cloud integration (issues sync, PR creation)
- Optionally configures CI/CD via plugin

Zero ceremony to start. Full ceremony when you're ready.

## The Editor

Not a VS Code replacement. A review-first, lightweight code surface.

**Core capabilities:**
- Rope-based text buffer for performance on large files
- Tree-sitter syntax highlighting (30+ languages bundled)
- Full LSP support via Language Server Protocol client
- Multiple cursor editing
- Find and replace (file, project-wide with regex)
- Code folding
- Minimap
- Breadcrumb navigation
- Split views (horizontal, vertical)

**LSP features:**
- Autocomplete with documentation preview
- Diagnostics (errors, warnings, info, hints) — gutter markers + Problems panel
- Hover documentation
- Go to definition / Go to type definition / Go to implementation
- Find all references
- Rename symbol (project-wide)
- Code actions (quick fixes, refactors)
- Document symbols (outline view)
- Workspace symbols (project-wide fuzzy search)
- Signature help
- Inlay hints
- Code lens (inline metadata above functions/classes)
- Formatting (format document, format selection)

**LSP server management:**
- Auto-detect language from file extension
- Auto-install LSP servers for detected languages (sourcekit-lsp, typescript-language-server, pyright, rust-analyzer, gopls, etc.)
- Per-project LSP configuration
- Multiple LSP servers per language supported

**Editor-specific keyboard shortcuts:**
```
⌘P          Go to file (fuzzy search)
⌘⇧O         Go to symbol (current file)
⌘T          Go to symbol (workspace)
F12         Go to definition
⇧F12        Find all references
F2          Rename symbol
⌘.          Code actions
⌘⇧M         Problems panel
⌃`          Toggle terminal
⌥↑/↓       Move line up/down
⇧⌥↑/↓      Duplicate line
⌘D          Select next occurrence
⌘⇧L         Select all occurrences
⌘/          Toggle comment
⌥⌘[/]       Fold/unfold
```

**Inline decorations (composable, from multiple primitives):**
- Git blame (inline, toggleable)
- Test coverage (gutter — green/red/yellow markers)
- LSP diagnostics (gutter icons, underlines)
- Agent changes (purple gutter markers for AI-modified lines)
- Observability errors (gutter markers linking to Sentry/Datadog errors at that line)
- Review comments (inline, from Code Review primitive)

## The Review View

Cursor-inspired review experience for agent work.

**Layout:** Side-by-side diff with original on left, agent's changes on right. Or unified view toggled with a keystroke.

**Features:**
- Per-hunk approve/reject (`a` / `r`)
- Per-file approve/reject
- Inline comment on any line (`c`)
- AI-generated change summary per file (collapsible header)
- "Explain this change" button per hunk
- Linked test results (did tests pass after this change?)
- One-click "run tests for this file" from review
- Accept all / reject all with confirmation
- Navigate changes: `n` next hunk, `p` previous hunk, `]` next file, `[` previous file

---

# PART 6: THE PLUGIN SYSTEM

## Plugin Registration

```swift
struct SentryPlugin: AnvilPlugin {
    static let metadata = PluginMetadata(
        id: "com.sentry.anvil",
        name: "Sentry",
        version: "1.0.0",
        provides: [
            .provider(for: .observability, id: "sentry"),
        ],
        requires: [
            .primitive(.sourceControlCloud),
            .primitive(.tickets),
        ],
        views: [
            .sidebarSection(mode: .ship, id: "sentry-errors"),
            .mainView(id: "sentry-error-detail"),
            .inlineAnnotation(id: "sentry-gutter-errors"),
        ],
        commands: [
            .command(id: "sentry.triage", title: "Triage Error", shortcut: nil),
            .command(id: "sentry.create-ticket", title: "Create Ticket from Error", shortcut: nil),
        ]
    )
}
```

## New Primitive Introduction

```swift
struct FeatureFlagPlugin: AnvilPlugin {
    static let metadata = PluginMetadata(
        id: "com.launchdarkly.anvil",
        name: "LaunchDarkly",
        introduces: [
            .primitive(
                id: "feature-flags",
                name: "Feature Flags",
                contract: FeatureFlagContract.self
            ),
        ]
    )
}
// Other plugins can now provide for the "feature-flags" primitive
```

## Plugin Sandboxing and Inter-Plugin Communication

```swift
// Plugins can request data from other plugins via defined protocols
let currentBranch = try await anvil.plugins.sourceControl.currentBranch()
let lastCommit = try await anvil.plugins.sourceControl.lastCommit()

// ACP access — any plugin, no API key
let explanation = try await anvil.acp.complete(
    prompt: "Explain this error: \(stackTrace)",
    taskType: .errorAnalysis
)

// Plugin-scoped persistent storage
try await anvil.storage.set("sentry.last-sync", value: Date())
let lastSync: Date? = try await anvil.storage.get("sentry.last-sync")
```

## First-Party Plugins (Ship with Anvil)

| Plugin | Provides For |
|--------|-------------|
| Git | Source Control (default) |
| GitHub | Source Control Cloud (default), Tickets (GitHub Issues) |
| Terminal | Embedded terminal |
| Editor | Code editing surface |
| Project Notes | Documentation (internal, lightweight) |

## Distribution

- Plugins are Swift packages
- Distributed via Anvil Plugin Registry (future) or direct URL
- Code-signed for security
- Sandboxed: declared permissions for network, filesystem, keychain
- Auto-update mechanism

---

# PART 7: INTER-PRIMITIVE LINK MAP

Every link is bidirectional and keyboard-navigable via chord sequences.

```
Ticket ←→ Branch ←→ PR ←→ Deployment ←→ Environment
  ↕          ↕        ↕        ↕              ↕
Agent  ←→ Review ←→ CI/CD ←→ Observability ←→ Health
  ↕          ↕        ↕        ↕
Docs   ←→ Testing ←→ Database ←→ Secrets
  ↕          ↕                     ↕
Notes  ←→ Messages ←→ Schedule ←→ Personal Tasks
                         ↕
                     Notifications (aggregates all)
                         ↕
                      Search (indexes all)
                         ↕
                     Analytics (measures all)
```

**Link types:**
- `linkedTo` — generic bidirectional link
- `createdFrom` — causal (agent session created from ticket)
- `triggeredBy` — event-driven (deployment triggered by PR merge)
- `blocks` / `blockedBy` — dependency (PR blocked by failing CI)
- `referencedIn` — informational (ticket referenced in doc)

All links are stored in Anvil's local database and synced from providers where applicable.

---

# PART 8: PRIMITIVE-PROVIDER SUMMARY TABLE

| # | Primitive | Default Provider | Plugin Provider Examples |
|---|-----------|-----------------|--------------------------|
| 1 | Source Control | Git (libgit2) | Mercurial, Jujutsu, SVN |
| 2 | Source Control Cloud | GitHub | GitLab, Bitbucket, Gitea |
| 3 | Tickets | Anvil Native | Linear, Jira, Asana, Shortcut |
| 4 | Code Review | Anvil Native | Graphite, Gerrit |
| 5 | Agents | Claude + OpenAI | Gemini, Ollama, Codex, Mistral |
| 6 | Agent Marketplace | Anvil Marketplace | MCP Registry, OpenAI Plugins |
| 7 | Observability | — | Sentry, Datadog, New Relic |
| 8 | Database | PostgreSQL | MySQL, MongoDB, Redis, Neon |
| 9 | Hosting | — | Vercel, Railway, Fly.io, AWS |
| 10 | Remote Environments | SSH | Codespaces, Gitpod, ngrok |
| 11 | Documentation | Anvil Native | Notion, Confluence, DevDocs |
| 12 | Messaging | — | Slack, Discord, Teams |
| 13 | CI/CD | GitHub Actions | CircleCI, Buildkite, Dagger |
| 14 | Containers & IaC | Docker | Podman, K8s, Terraform |
| 15 | Testing | Auto-detect | Jest, Pytest, Playwright |
| 16 | API Development | Built-in HTTP | Postman, Bruno import |
| 17 | Secrets | Anvil Vault | 1Password, Doppler, HCV |
| 18 | Voice | macOS Speech | Whisper, Deepgram, ElevenLabs |
| 19 | Design | — | Figma, Sketch, Penpot |
| 20 | Personal Tasks | Anvil Native | Todoist, Things 3 |
| 21 | Schedule | Native + Apple Cal | Google Cal, Outlook, Cal.com |
| 22 | Notifications | Anvil Native | — (aggregates all) |
| 23 | Search | Anvil Native | Sourcegraph |
| 24 | Analytics | Anvil Native | — (computed) |
| 25 | Package Management | Auto-detect | npm, pip, cargo, go mod, SPM |

---

# PART 9: TECHNICAL REQUIREMENTS

## Platform

- macOS 15+ (Sequoia)
- Apple Silicon primary target, Intel supported
- Minimum 8GB RAM, recommended 16GB
- Universal binary

## Performance Targets

- App launch → interactive: < 2 seconds
- Mode switch: < 100ms
- Command palette appear: < 50ms
- File open in editor: < 200ms for files under 10MB
- Git operations (branch, diff, log): < 500ms for repos under 100k commits
- Agent message render: < 16ms per frame (60fps streaming)
- Search results: < 100ms for local index
- Sidebar list scroll: 60fps with 10,000 items (virtualized)

## Security

- All secrets in macOS Keychain via Keychain Services API
- ACP provider tokens encrypted at rest
- Plugin sandboxing via App Sandbox entitlements
- Network: TLS 1.3 for all API calls
- No telemetry without explicit opt-in
- Local-first data: everything works offline except provider syncs
- No data sent to Anvil servers (there are none — local app only)

## Data Storage

- Project metadata: SQLite via GRDB (`~/.anvil/db/`)
- Configuration: JSON files (`~/.anvil/config/`)
- Plugin data: SQLite per-plugin (`~/.anvil/plugins/{id}/`)
- Worktrees: Git worktrees (`~/.anvil/worktrees/`)
- Search index: SQLite FTS5 (`~/.anvil/index/`)
- Cache: File-based (`~/.anvil/cache/`), auto-purged

## Accessibility

- Full VoiceOver support
- All interactive elements keyboard-accessible
- Dynamic Type scaling
- Reduced Motion support (disables all animations)
- High Contrast support
- Minimum touch target: 44x44 points (for trackpad)

---

# PART 10: BUILD PRIORITIES

## Phase 1: Foundation (Months 1-3)

Build the shell and core primitives that make the app usable day-one.

1. **App shell** — Window architecture, sidebar, main content, inspector, status bar, mode switching
2. **Design system** — Colors, typography, spacing, core components (AnvilListItem, AnvilCard, AnvilButton, etc.)
3. **Command palette** — ⌘K with fuzzy search, context-aware actions, keyboard navigation
4. **Keyboard system** — Global shortcuts, list navigation, chord sequences, customization
5. **Source Control (Git)** — Full git operations via libgit2, worktree engine, graph view, stacked diff view, auto-commit
6. **Source Control Cloud (GitHub)** — PRs, issues, repo management, templates
7. **Editor** — Text buffer, Tree-sitter highlighting, LSP client, inline decorations
8. **ACP system** — Provider protocol, Claude adapter, OpenAI adapter, router, cost tracking
9. **Agents** — Session management, conversation view, workspace view, plan view, approval workflow
10. **Code Review** — Diff review, inline comments, review inbox, AI review dispatch
11. **Terminal** — SwiftTerm embedded, shell integration
12. **Project lifecycle** — New project (blank, template, clone, existing), graduation to GitHub

## Phase 2: Integration (Months 4-6)

Add the primitives that make you never leave the app.

13. **Tickets (Anvil Native)** — Lightweight tickets, cycles, boards, backlog
14. **Notifications & Inbox** — Unified inbox, triage, routing rules
15. **Search** — Full-text index across all primitives, semantic search via ACP
16. **Documentation (Anvil Native)** — Internal docs, external doc indexing, reference panel
17. **Project Notes** — Persistent scratchpad, auto-structured, ACP-organized
18. **Personal Tasks** — Quick capture, task list, daily log, bookmarks
19. **CI/CD (GitHub Actions)** — Pipeline status, build logs, test results
20. **Testing** — Test explorer, run/watch, coverage overlay, flaky tracker
21. **Settings** — All configuration surfaces, keybinding editor, provider management

## Phase 3: Expansion (Months 7-9)

Deep integrations and advanced features.

22. **Synthesis Rooms** — Multi-session merge, adversarial review
23. **Database (PostgreSQL)** — Schema browser, query console, migrations
24. **Hosting (Vercel)** — Deploy, preview, env vars, rollback
25. **Messaging (Slack)** — Channels, DMs, unified inbox
26. **Schedule** — Calendar view, time blocks, focus planner
27. **Secrets (Anvil Vault)** — Keychain-backed vault, env injection
28. **Analytics** — Usage dashboard, cost breakdown, velocity
29. **Package Management** — Dependency tree, vulnerabilities, updates
30. **Voice** — Dictation, voice commands, ambient mode

## Phase 4: Ecosystem (Months 10-12)

Plugin system and advanced providers.

31. **Plugin SDK** — Public API, view registration, command registration, ACP access
32. **Plugin distribution** — Package format, signing, registry
33. **Agent Marketplace** — Cross-provider skill browser, batch install
34. **Additional providers** — Linear, Jira, GitLab, Sentry, Datadog, Neon, Railway, etc.
35. **Remote Environments** — SSH, Codespaces, tunnels
36. **Containers** — Docker dashboard, compose visualizer
37. **API Development** — Request builder, response viewer, collection management
38. **Design** — Figma integration, token sync, comparison overlay

---

# APPENDIX A: COMPLETE KEYBOARD SHORTCUT REFERENCE

## Global
| Shortcut | Action |
|----------|--------|
| `⌘K` | Command palette (everything) |
| `⌘⇧P` | Command palette (commands only) |
| `⌘E` | Quick switch (recent items) |
| `⌘1` | Intent mode |
| `⌘2` | Agent mode |
| `⌘3` | Review mode |
| `⌘4` | Ship mode |
| `⌘5` | Editor mode |
| `⌘6` | Database mode |
| `⌘7` | Terminal mode |
| `⌘8` | Docs mode |
| `⌘9` | Messaging mode |
| `⌘0` | Notifications mode |
| `⌘N` | New item (contextual) |
| `⌘⇧A` | New agent session |
| `⌘⇧N` | Append to project notes |
| `⌘⇧Space` | Quick capture overlay |
| `⌘,` | Settings |
| `⌘⇧I` | Toggle inspector panel |
| `⌘B` | Toggle sidebar |
| `⌘J` | Toggle terminal panel |
| `⌘T` | New tab |
| `⌘W` | Close tab |
| `⌘⇧[` | Previous tab |
| `⌘⇧]` | Next tab |
| `⌘\` | Split right |
| `⌘⇧\` | Split down |
| `⌘.` | Quick actions (context menu) |
| `⌘G` | AI generate (context-dependent) |
| `⌘⇧R` | AI review current view |
| `⌘P` | Switch ACP provider/model |

## List Navigation (Universal)
| Shortcut | Action |
|----------|--------|
| `j` / `↓` | Move down |
| `k` / `↑` | Move up |
| `↵` | Open / expand |
| `⌘↵` | Open in split |
| `x` | Toggle select |
| `⇧X` | Select all visible |
| `/` | Filter |
| `esc` | Clear filter / deselect |

## Chord Sequences (Go-To)
| Chord | Action |
|-------|--------|
| `g t` | Go to linked ticket |
| `g b` | Go to linked branch |
| `g p` | Go to linked PR |
| `g d` | Go to linked deployment |
| `g a` | Go to linked agent session |
| `g n` | Go to project notes |
| `g c` | Go to linked CI run |
| `g e` | Go to linked error |
| `g s` | Go to linked schedule |

## Review Mode
| Shortcut | Action |
|----------|--------|
| `a` | Approve current item/hunk |
| `r` | Request changes / reject |
| `c` | Comment on current line/hunk |
| `n` | Next hunk |
| `p` | Previous hunk |
| `]` | Next file |
| `[` | Previous file |
| `⌘↵` | Submit all reviews |
| `d` | Toggle side-by-side / unified |

## Agent Mode
| Shortcut | Action |
|----------|--------|
| `⌘[` | Previous sub-view (Conversation/Workspace/Plan) |
| `⌘]` | Next sub-view |
| `⌘⇧S` | Synthesis room (with selected sessions) |
| `⌘P` | Switch provider mid-session |
| `space` | Pause/resume agent |
| `y` | Approve pending tool call |
| `n` | Reject pending tool call |

## Editor
| Shortcut | Action |
|----------|--------|
| `⌘P` | Go to file |
| `⌘⇧O` | Go to symbol (file) |
| `⌘T` | Go to symbol (workspace) |
| `F12` | Go to definition |
| `⇧F12` | Find all references |
| `F2` | Rename symbol |
| `⌘.` | Code actions |
| `⌘⇧M` | Problems panel |
| `⌃\`` | Toggle terminal |
| `⌥↑/↓` | Move line |
| `⇧⌥↑/↓` | Duplicate line |
| `⌘D` | Select next occurrence |
| `⌘⇧L` | Select all occurrences |
| `⌘/` | Toggle comment |
| `⌥⌘[/]` | Fold / unfold |

---

# APPENDIX B: ACP PROVIDER PROTOCOL

```swift
/// The core ACP provider protocol. Every AI provider implements this.
public protocol ACPProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var availableModels: [ACPModel] { get async throws }

    func complete(
        messages: [ACPMessage],
        model: ACPModel,
        tools: [ACPToolDefinition],
        stream: Bool
    ) -> AsyncThrowingStream<ACPStreamEvent, Error>

    func estimateCost(
        messages: [ACPMessage],
        model: ACPModel
    ) -> ACPCostEstimate

    func supportsTools(_ tools: [ACPToolDefinition]) -> Bool
}

public enum ACPStreamEvent: Sendable {
    case textDelta(String)
    case toolCallStart(id: String, name: String)
    case toolCallDelta(id: String, argumentsDelta: String)
    case toolCallEnd(id: String)
    case toolResult(id: String, content: ACPToolResultContent)
    case messageComplete(ACPMessage)
    case usage(ACPUsage)
    case error(ACPError)
}

public struct ACPModel: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let provider: String
    public let contextWindow: Int
    public let inputCostPer1kTokens: Decimal
    public let outputCostPer1kTokens: Decimal
    public let capabilities: Set<ACPCapability>
}

public enum ACPCapability: String, Sendable {
    case codeGeneration
    case codeReview
    case reasoning
    case vision
    case toolUse
    case longContext
}
```

---

# APPENDIX C: PRIMITIVE PORT PROTOCOL (BASE)

```swift
/// Every primitive conforms to this base protocol.
public protocol AnvilPrimitive: Sendable {
    /// Unique identifier for this primitive type
    static var primitiveId: String { get }

    /// Human-readable name
    static var displayName: String { get }

    /// SF Symbol name for the primitive's icon
    static var iconName: String { get }

    /// The domain events this primitive can emit
    associatedtype DomainEvent: AnvilDomainEvent

    /// The views this primitive registers
    static var registeredViews: [AnvilViewRegistration] { get }

    /// The command palette actions this primitive provides
    static var commands: [AnvilCommandRegistration] { get }

    /// ACP hook definitions (what AI can do with this primitive)
    static var acpHooks: [ACPHookDefinition] { get }
}

/// Every provider conforms to this.
public protocol AnvilProvider: Sendable {
    associatedtype Primitive: AnvilPrimitive

    var providerId: String { get }
    var providerName: String { get }

    /// Initialize with configuration
    init(config: ProviderConfiguration) throws

    /// Health check
    func validateConnection() async throws -> Bool
}
```

---

This document is the single source of truth. Give it to Claude Code with a team of agents. Get an app.

