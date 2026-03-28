# Anvil

Agent-native development environment for macOS. Swift 6, SwiftUI, macOS 15+.

For the full architecture, current feature status, and build instructions see:
`ARCHITECTURE/OVERVIEW.md`

## Architecture (summary)

Hexagonal architecture (ports and adapters) with DDD:
- **AnvilDomain** — Pure Swift domain layer. Zero dependencies. Primitives (ports), entities, value objects, domain events.
- **AnvilApplication** — Use cases, event bus, services. Depends on Domain only.
- **AnvilACP** — AI provider protocol and implementations. The universal AI backbone.
- **AnvilInfrastructure** — Adapters (providers). Depends on Domain + Application.
- **AnvilUI** — SwiftUI presentation. Depends on Application + Domain. NEVER imports Infrastructure directly.
- **AnvilPluginSDK** — Public SDK for plugin developers.
- **AnvilEditor** — Editor engine (future: Tree-sitter, LSP).
- **AnvilTerminal** — Terminal emulator (future: SwiftTerm).
- **AnvilGit** — Git operations (future: libgit2).

## Key Concepts

- **Primitives** = Ports (abstract contracts). 25 total defined in SPEC.md.
- **Providers** = Adapters (concrete implementations). Swappable at runtime.
- **ACP** = Agent Communication Protocol. Every AI feature flows through ACP. Plugins get AI for free.
- **Workspaces** = Intent, Agent, Review, Ship (core) + Editor, Database, Terminal, Docs, Messaging, Notifications, Testing, Schedule, Observability (auxiliary).

## Build

```bash
./scripts/dev --generate-only
xcodebuild -project Anvil.xcodeproj -scheme Anvil -derivedDataPath /tmp/anvil-derived build
./scripts/test-packages
```

Open `Anvil.xcodeproj` for normal development. Do not open the repo root as a Swift package workspace.

## Critical Rules

- AnvilUI NEVER imports AnvilInfrastructure. All communication goes through Application layer protocols.
- First-party plugins use the same API as third-party. No private APIs.
- All types must be Sendable (Swift 6 strict concurrency).
- Every domain event flows through the EventBus.
- Agent sessions get isolated worktrees automatically.
- No visible affordance ships unless it is in `TRUTH_MATRIX.md` with a real handler.
- No shortcut label appears in UI unless the command exists and is wired.
- Shell work (rail, sidebar, inspector, utility deck) lands before or with feature breadth.

## Governance Documents

| Document | Purpose |
|---|---|
| `ARCHITECTURE/OVERVIEW.md` | Full architecture, feature status, build instructions |
| `ARCHITECTURE/TASK_REGISTRY.md` | Master task list: 338 tasks with priorities |
| `ARCHITECTURE/UX_SHELL.md` | Shell contract: ownership rules for every window region |
| `ARCHITECTURE/PROVIDER_MODEL.md` | Multi-provider rules and capability sets |
| `ARCHITECTURE/COMPETITOR_GAP.md` | Gap analysis vs Cursor, Windsurf, Zed, Xcode, Linear, GitHub, Raycast |
| `ROADMAP_NATIVE_2026.md` | Canonical 100-task phased roadmap |
| `TRUTH_MATRIX.md` | Anti-stub ledger: every visible affordance mapped to a real handler |
| `UI_IMPLEMENTATION_GOVERNANCE.md` | Rules for what can ship and what cannot |
| `SPEC.md` | Full product specification |
