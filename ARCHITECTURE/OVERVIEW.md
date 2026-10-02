# Anvil Architecture Overview

Last updated: 2026-03-29

This document is the single authoritative summary of what Anvil is, how it is structured, what exists today, and how to build and extend it. Every other document in this repo is subordinate to or referenced from this one.

---

## Project Vision

Anvil is a native macOS development environment built for the post-IDE era. It is not a better code editor. It is the developer's operational center: the place where work is planned, executed by AI agents, reviewed, and shipped — without ever opening a browser.

**The core premise:** AI is ambient infrastructure, not a bolted-on feature. Every surface in Anvil is AI-capable via the Agent Communication Protocol (ACP). Plugins inherit AI for free. There is no per-feature API key setup.

**The opinionated workflow:** Plan → Build → Review → Operate → Library. Five first-class spaces, keyboard-navigable throughout. `Intent`, `Agent`, and `Ship` remain transitional/internal identifiers during migration, not the canonical shell vocabulary. `Ship` is the legacy label for `Operate`. See [`ARCHITECTURE/SHELL_VOCABULARY.md`](../ARCHITECTURE/SHELL_VOCABULARY.md) for the canonical shell language and grouping model.

**The native moat:** None of the AI-first competitors — Cursor, Windsurf, Zed — are native macOS apps. Anvil is Swift 6, SwiftUI, AppKit interop, targeting macOS 15+ (Sequoia). The native shell is the product differentiator.

**Reference design pillars:**
- Raycast — command palette as the primary interaction surface, every entity is actionable
- Linear — opinionated workflow, single-key shortcuts, typographic precision
- Xcode — native shell ownership (navigator, inspector, utility area), selection-driven detail
- GitKraken — sidebar-driven multi-view layout with graph visualization
- Superhuman — inbox-zero interaction model, `j/k` navigation, batch actions

---

## Architecture Layers

Anvil follows hexagonal architecture (ports and adapters) with Domain-Driven Design. The dependency graph is strictly one-directional.

```
AnvilDomain
    ^
    |
AnvilApplication  <--  AnvilACP
    ^
    |
AnvilInfrastructure     AnvilGit     AnvilGitHub
    ^
    |
AnvilUI  (never imports AnvilInfrastructure directly)

AnvilPluginSDK  (public API, third-party plugins use this)
AnvilEditor     (future: Tree-sitter, LSP client)
AnvilTerminal   (future: SwiftTerm PTY)
```

### AnvilDomain

Pure Swift, zero dependencies. This is the heart of the system.

Contains:
- **Primitives (Ports)** — abstract protocol contracts, 25+ defined. Each represents a capability: `AgentPort`, `TicketPort`, `DatabasePort`, `CodeReviewPort`, `SourceControlCloudPort`, etc.
- **Entities and value objects** — `AgentSession`, `AgentMessage`, `Ticket`, `Board`, `Review`, `ReviewComment`, `PullRequest`, `DatabaseConnection`, `Schema`, `AgentPlan`, `SynthesisRoom`, `ToolCall`, etc.
- **Domain events** — `DomainEvent` base type, published via `EventBus` for cross-layer coordination
- **Core infrastructure** — `EntityID`, `PrimitiveRegistry`, `ProviderRegistry`, `InterPrimitiveLink`, `DomainError`
- **ACP types** — `ACPPort`, `ACPRequest`, `ACPResponse`, `ACPStreamEvent`, `ACPModelSelection`, `ACPCostTracker`, `ACPToolDefinition`

Key primitives defined in domain:
`AgentPort`, `TicketManagementPort`, `CodeReviewPort`, `ReviewManagementPort`, `DatabasePort`, `DocumentationPort`, `DesignPort`, `SchedulePort`, `SecretsPort`, `PackageManagementPort`, `PersonalTaskPort`, `AnalyticsPort`, `CICDPort`, `ContainerPort`, `APIClientPort`, `AgentMarketplacePort`, `SourceControlCloudPort`

### AnvilApplication

Use cases, services, and the event bus. Depends on AnvilDomain only.

Contains:
- **EventBus** — domain event pub/sub. Handlers: `OnAgentCompleted`, `OnBuildFailed`, `OnDeploymentStarted`, `OnPRMerged`
- **Use cases** — `StartAgentSessionUseCase`, `SwitchAgentProviderUseCase`, `CreateProjectUseCase`, `OpenFileUseCase`, `AIReviewUseCase`, `CreateReviewUseCase`, `SubmitReviewUseCase`, `UpdateReviewUseCase`, `CreateDeploymentUseCase`, `AutoCommitUseCase`, `CreateWorktreeUseCase`, `GenerateCommitMessageUseCase`, `CreateTicketUseCase`
- **Services** — `ACPRouter`, `ContextBuilder`, `DatabaseService`, `DesktopNotificationService`, `NotificationAggregator`, `ObservabilityService`, `PluginManager`, `ProjectManager`, `SearchIndexer`, `WorktreeOrchestrator`
- **In-memory services (stubs)** — `InMemoryDeploymentService`, `InMemoryDocumentationService`, `InMemoryMessagingService`, `InMemoryNotificationService`, `InMemoryObservabilityService`, `InMemoryReviewService`, `InMemoryScheduleService`, `InMemoryTestingService`, `InMemoryTicketService`

The in-memory services are functional enough to drive the UI but are not production provider integrations. Real providers are implemented in AnvilInfrastructure.

### AnvilACP

The universal AI backbone. Every AI feature routes through ACP.

Contains:
- **Protocol** — `ACPProtocol`, `ACPTransport`, `ACPProcessTransport`, JSON-RPC layer (`ACPJsonRpc`)
- **Client** — `ACPClient`, `ZedACPClient`
- **Providers** — `AnthropicProvider`, `OpenAIProvider`, `OllamaProvider`, `ClaudeCLIProvider`, `ClaudeProcessProvider`, `ZedACPProvider`
- **Tools** — `ToolRegistry`, `FileTools`, `TerminalTools`
- **Streaming** — `SSEParser`
- **Cost tracking** — `BudgetEnforcer`, `CostCalculator`, `TokenCounter`
- **Types** — `ACPTypes`

### AnvilInfrastructure

Concrete adapters (providers). Depends on Domain and Application.

Contains:
- **Adapters** — `SQLiteDatabaseAdapter`, `SlackMessagingAdapter`, `VercelHostingAdapter`, `LinearTicketProvider`, `GitHubIssuesTicketProvider`, `SentryObservabilityAdapter`, `DockerAdapter`
- **Persistence** — `SQLiteStore`, `FileStore`, `KeychainStore`

### AnvilUI

SwiftUI presentation layer. Depends on Application and Domain. Never imports AnvilInfrastructure.

Contains:
- **Shell** — `MainWindow`, `Sidebar`, `ContentArea`, `StatusBar`, `ModeTabBar`, `CommandPalette`, `CommandPaletteViewModel`, `InspectorPanel`, `TerminalPanel`, `SourceControlPanel`, `ProjectSwitcher`, `QuickCapture`, `SearchPanel`, `WelcomePage`, `BranchPicker`, `CodebaseQAView`
- **Shell sidebar sections** — `BuildSidebar`, `LibrarySidebar`, `OperateSidebar`, source control panel sections (`SCPBranchSection`, `SCPHistorySection`, `SCPRemoteSection`, `SCPStashSection`, `SCPTagSection`)
- **Build space** — `AgentMode`, `AgentSidebar`, `AgentChatPanel`, `AgentModeView`, `AgentViewModel`, `SessionDetailView`, `SessionDashboard`, `SynthesisRoomView`
- **Plan space** — `IntentMode`, `IntentSidebar`, `IntentViewModel`, `BoardView`, `TicketListView`, `TicketDetailView`
- **Review space** — `ReviewMode`, `ReviewSidebar`, `ReviewViewModel`, `DiffReviewView`, `GitHubPRDetailView`, `GitHubPRViewModel`, `ReviewInboxView`, `GitGraphView`
- **Operate space** — `ShipMode`, `ShipSidebar`, `ShipViewModel`, `DeployDashboardView`, `EnvVarManagerView`, `BuildLogView`
- **Auxiliary spaces** — `DatabaseMode`, `TerminalMode`, `DocsMode`, `MessagingMode`, `NotificationsMode`, `ObservabilityMode`, `ScheduleMode`, `TestingMode`, and their respective ViewModels and sub-views
- **Settings** — `SettingsWindow`, `IntegrationSettingsView`
- **Keyboard** — `KeyEventRouter`, `ChordTracker`

### AnvilGit

Git operations package. Future home of libgit2 bindings. Currently provides CLI-based git operations used by AnvilUI and AnvilApplication.

### AnvilGitHub

GitHub-specific integration separate from the generic source control primitives.

Contains: `GitHubClient`, `GitHubModels`, `GitHubNotification`, `GitHubOAuthService`, `GitHubSourceControlCloudAdapter`, `KeychainHelper`

### AnvilPluginSDK

Public SDK for plugin developers. First-party plugins use this same API — no private APIs granted to bundled features.

### AnvilEditor

Future: Tree-sitter based syntax highlighting, LSP client. Currently a placeholder package.

### AnvilTerminal

Future: SwiftTerm PTY integration. Currently a placeholder package.

---

## Key Design Decisions

### Hexagonal Architecture (Ports and Adapters)

Every capability is defined as a protocol (port) in AnvilDomain. Concrete implementations (adapters) live in AnvilInfrastructure or ACP packages. Providers are swappable at runtime through `ProviderRegistry`. This means the UI and use cases never care whether the database is SQLite or PostgreSQL — they call a `DatabasePort`.

### DDD Entity Model

Core entities follow Domain-Driven Design conventions: rich value objects, entity identity via `EntityID`, domain events emitted by use cases, aggregates for complex state. The domain layer has zero external dependencies.

### ACP as First-Class Infrastructure

The Agent Communication Protocol is not a feature — it is the electrical system. Every AI-capable surface routes through `ACPPort` in the domain. The application layer routes through `ACPClient`. Providers (Anthropic, OpenAI, Ollama, Zed) are swappable. Plugins get ACP access through the Plugin SDK without any setup.

### Strict Layer Isolation

`AnvilUI` never imports `AnvilInfrastructure`. This is enforced by the module graph: the Swift packages do not declare the dependency. All communication from the UI to infrastructure goes through application-layer protocols.

### Provider Model

Every provider integration must expose: `connect`, `disconnect`, `discover`, `list`, `browse`, `execute`, `stream`, `inspect`, `search`, `history`, `export`, `sync`. Provider states are `unconfigured`, `connecting`, `connected`, `capability-degraded`, `disconnected`, `error`. Shared UI never hardcodes provider brand names in labels — only in setup/configuration flows. See `ARCHITECTURE/PROVIDER_MODEL.md`.

### UX Shell Ownership

Defined in `ARCHITECTURE/SHELL_VOCABULARY.md` and summarized in `ARCHITECTURE/UX_SHELL.md`. Key contract:
- Workspace rail owns workspace switching and global badges
- Sidebar owns navigation (entities, views, collections)
- Canvas owns the active artifact or workflow
- Inspector owns metadata and secondary actions for the selected entity
- Utility deck owns terminal, logs, problems, notifications
- Chat is a Library-space canvas surface: channel navigation lives in the sidebar, conversation view lives in the canvas, and provider state belongs in setup/settings/inspector.
- No surface duplicates another's job

### Swift 6 Strict Concurrency

All types must be `Sendable`. No shared mutable state without actors. Every domain event flows through the `EventBus`. Agent sessions get isolated git worktrees automatically via `WorktreeOrchestrator`.

---

## Current Feature Status (2026-03-28)

Based on static analysis of all packages. ~270 files, ~21K LOC.

### Working (non-stub)

- App entry point and window layout (MainWindow, AppState, DependencyContainer)
- Mode tab bar with keyboard shortcuts (Cmd+1 through Cmd+9)
- Command palette with fuzzy search, three modes (commands/files/symbols), keyboard nav
- Status bar with branch picker, agent activity, cursor position, encoding
- Agent mode: conversation view, tool call rendering, streaming, session list, slash commands, @ references, inline code edit suggestions (accept/reject), model picker, token usage visualization, streaming code blocks, background sessions, cost budget, session memory (.anvil/memory.md), smart session naming, multi-agent synthesis rooms, agent guardrails, worktree engine, event bus, agent plan view, queued message input, autonomous mode with tool call approval
- Intent mode: ticket list, board view, ticket detail, priority colors, drag-and-drop on kanban, quick-create inline, ticket linking, due date highlighting, ticket-to-branch-to-agent pipeline
- Review mode: side-by-side and unified diff, per-hunk approve/reject, review inbox, comment threads with replies, merge button, rebase/update branch, git blame in diff, git graph visualization (interactive DAG)
- Ship mode: deploy dashboard, environment variable manager, build log view
- Source control panel: changed files, staging, commit, branch picker (create/switch/delete), push/pull/fetch, stash management, tag management, cherry-pick/rebase/revert, remote management
- GitHub integration: OAuth login, PR list and detail, CI status display
- Codebase Q&A: ask questions with file citations
- Auto-PR from agent session
- Desktop notifications (macOS native), notification preferences, GitHub notification polling
- Editor: find/replace (current file and project), split editor, indent guides, word wrap, breadcrumb navigation, read-only indicator, whitespace visualization, git decorations in gutter, AI inline edit (Cmd+K), file encoding indicator
- Command palette: file search, symbol search, recent files, action history, contextual commands, nested commands
- Plugin marketplace browser (UI only)
- Welcome/start page with recent projects
- Settings window with integration settings

### Partial (architecture exists, implementation incomplete)

- Sidebar: collapse/expand works, auxiliary sidebar tap handlers missing
- Inspector panel: present, not fully selection-driven
- Terminal: UI shell present, no real PTY (no SwiftTerm integration)
- Database mode: UI present, SQLite adapter exists, no live connection flow
- Docs mode: UI present, in-memory only
- Chat: UI present, Library-space canvas surface with Slack adapter stub
- Observability mode: UI present, Sentry adapter stub
- Operate space: Vercel adapter stub, no real deployment triggers
- Testing mode: UI present, in-memory only
- Schedule mode: UI present, in-memory only
- @ context references: partial (files, basic), not full (no @web, @git, @docs, @recommended)

### Known Critical Bugs

1. **KeyEventRouter intercepts typing** — Root-level `.onKeyPress(phases: .down)` in MainWindow.swift intercepts characters when a chord is pending (user typed `g`). Makes text fields unreliable. Files: `KeyEventRouter.swift`, `ChordTracker.swift`, `MainWindow.swift`.

2. **Sidebar items unclickable when overlays open** — CommandPalette, QuickCapture, ProjectSwitcher, CodebaseQAView all render full-screen `Color.black.opacity(0.4)` backdrops that sit on top of sidebar, consuming all taps. Also: `navItem()` in `Sidebar.swift` has no `.onTapGesture` or `Button` action. Files: `MainWindow.swift`, `CommandPalette.swift`, `QuickCapture.swift`, `CodebaseQAView.swift`, `Sidebar.swift`.

### Not Yet Implemented (high priority)

- Real PTY terminal (SwiftTerm integration)
- LSP client for autocomplete, diagnostics, go-to-definition
- AI ghost text code completion
- Tree-sitter syntax highlighting
- Code folding
- Multi-cursor editing
- Editor minimap
- Merge conflict resolution UI
- @Recommended auto-context inference
- Two-tier memory (auto-memories + project rules)
- Real-time action tracking as implicit context
- Parallel agent launch with agent management sidebar
- Subagent dispatch
- Session search across all conversations
- Suggested changes in PR review
- Contextual Cmd+K (entity-aware action panel)
- Single-key action shortcuts per entity type
- Activity timeline linking entities across workspaces
- Real database connections (PostgreSQL)
- Real deployment provider integration
- Real Slack integration
- Real Sentry integration

---

## Window Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Traffic lights    [Space tabs: Plan Build Review Operate Library] │
│                    Title / Context indicator        [Search Cmd+K]│
├────────┬─────────────────────────────────┬───────────────────────┤
│        │                                 │                       │
│  Side  │                                 │    Inspector          │
│  bar   │       Main Content Area         │    Panel              │
│        │                                 │    (Cmd+Shift+I)      │
│  Nav   │       (mode-specific)           │                       │
│  list  │                                 │                       │
│        │                                 │                       │
│  48px  │                                 │                       │
│  when  │                                 │                       │
│  coll- │                                 │                       │
│  apsed │                                 │                       │
├────────┴─────────────────────────────────┴───────────────────────┤
│  Status Bar: branch  provider  agent status  cost  clock         │
└──────────────────────────────────────────────────────────────────┘
```

Spaces: Plan, Build, Review, Operate, Library (core) + Editor, Database, Terminal, Docs, Chat, Notifications, Testing, Schedule, Observability (auxiliary)

---

## Build Instructions

### First-time setup

```bash
xcode-select -p                    # verify Xcode is active developer dir
xcodegen --version                 # verify XcodeGen 2.40+
cd <repo>
./scripts/dev                      # generate Anvil.xcodeproj and open in Xcode
```

### Daily workflow

```bash
# Option 1: Xcode (preferred)
open Anvil.xcodeproj               # open project
# Select Anvil scheme, press Cmd+R

# Option 2: Command line build
./scripts/dev --generate-only      # regenerate project without opening Xcode
xcodebuild -project Anvil.xcodeproj -scheme Anvil -derivedDataPath /tmp/anvil-derived build

# Option 3: Swift package tests only
./scripts/test-packages
```

**Do not open the repo root folder directly in Xcode.** This causes Xcode to treat the repo as a Swift package workspace, which breaks the app lifecycle. Always open `Anvil.xcodeproj`.

### Project structure

```
App/                    macOS app target sources, assets, plist
Packages/               local Swift packages (AnvilDomain, AnvilApplication, etc.)
Tests/UITests/          macOS XCUITest suite
project.yml             XcodeGen source (single source of truth for project config)
Anvil.xcodeproj         generated Xcode project, committed for Cmd+R convenience
scripts/dev             regenerate project + optional Xcode open
scripts/test-packages   run tests across all packages
```

### Tooling requirements

- Xcode 16+
- Swift 6+
- XcodeGen 2.40+

---

## Governance Documents

These documents govern what ships and how:

| Document | Purpose |
|---|---|
| `ARCHITECTURE/OVERVIEW.md` (this file) | Single authoritative architecture and status summary |
| `ARCHITECTURE/SHELL_VOCABULARY.md` | Canonical shell vocabulary and workspace hierarchy |
| `ARCHITECTURE/UX_SHELL.md` | Shell contract: rail, sidebar, canvas, inspector, utility deck ownership |
| `ARCHITECTURE/PROVIDER_MODEL.md` | Rules for multi-provider UI, capability sets, provider states |
| `ARCHITECTURE/COMPETITIVE_IA_RESEARCH_2026.md` | IA patterns synthesized from Xcode, VS Code, JetBrains, Cursor, Claude Code, Codex, Raycast |
| `ARCHITECTURE/COMPETITOR_GAP.md` | Feature gap analysis vs Cursor, Windsurf, Zed, Xcode, Linear, GitHub, Raycast with 60-feature table and top 20 priorities |
| `ARCHITECTURE/TASK_REGISTRY.md` | Master task list: 200+ tasks organized by category with priority |
| `ROADMAP_NATIVE_2026.md` | Canonical 100-task execution roadmap, phased |
| `TRUTH_MATRIX.md` | Anti-stub ledger: every visible affordance mapped to a real handler |
| `UI_IMPLEMENTATION_GOVERNANCE.md` | Rules for what can ship and what cannot |
| `SPEC.md` | Full product specification: vision, design language, component library, all mode specs |
| `DESIGN_VISION.md` | Competitive research, differentiators, v0.2 prioritization |

---

## Critical Rules

1. `AnvilUI` never imports `AnvilInfrastructure`. All communication goes through Application layer protocols.
2. First-party plugins use the same `AnvilPluginSDK` API as third-party. No private APIs.
3. All types must be `Sendable` (Swift 6 strict concurrency).
4. Every domain event flows through the `EventBus`.
5. Agent sessions get isolated git worktrees automatically.
6. No visible affordance ships unless it is in `TRUTH_MATRIX.md` with a real handler.
7. No shortcut label appears in UI unless the command exists and is wired.
8. No demo or placeholder data in production mode unless the UI explicitly labels it "Demo."
9. Shared UI speaks in capabilities, not provider brand names.
10. Shell work (rail, sidebar, inspector, utility deck) lands before or with feature breadth — never after.
