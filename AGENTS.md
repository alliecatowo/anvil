# Anvil

Agent-native development environment for macOS. Swift 6, SwiftUI, macOS 15+.

## Architecture

Hexagonal architecture (ports & adapters) with DDD:
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
- **Modes** = Intent, Agent, Review, Ship (core) + Editor, Database, Terminal, Docs, Messaging, Notifications (auxiliary).

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
