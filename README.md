# Anvil

Anvil is a macOS app built with SwiftUI and modular local Swift packages. This repo is app-first: the primary development entry point is [`Anvil.xcodeproj`](/Users/allie/Develop/anvil/Anvil.xcodeproj), not the repo folder and not a root Swift package workspace.

## Roadmap and Status

- Canonical execution roadmap: [`ROADMAP_NATIVE_2026.md`](/Users/allie/Develop/anvil/ROADMAP_NATIVE_2026.md)
- UI implementation governance: [`UI_IMPLEMENTATION_GOVERNANCE.md`](/Users/allie/Develop/anvil/UI_IMPLEMENTATION_GOVERNANCE.md)
- Mac UI direction: [`MAC_UI_DIRECTION.md`](/Users/allie/Develop/anvil/MAC_UI_DIRECTION.md)
- Shell vocabulary north star: [`ARCHITECTURE/SHELL_VOCABULARY.md`](/Users/allie/Develop/anvil/ARCHITECTURE/SHELL_VOCABULARY.md)
- Whole-app truth matrix: [`TRUTH_MATRIX.md`](/Users/allie/Develop/anvil/TRUTH_MATRIX.md)
- Shell model: [`ARCHITECTURE/UX_SHELL.md`](/Users/allie/Develop/anvil/ARCHITECTURE/UX_SHELL.md)
- Provider model: [`ARCHITECTURE/PROVIDER_MODEL.md`](/Users/allie/Develop/anvil/ARCHITECTURE/PROVIDER_MODEL.md)
- Native UI PR checklist: [`docs/pr-checklists/native-ui.md`](/Users/allie/Develop/anvil/docs/pr-checklists/native-ui.md)
- Feature completeness PR checklist: [`docs/pr-checklists/feature-completeness.md`](/Users/allie/Develop/anvil/docs/pr-checklists/feature-completeness.md)
- Older audit/task docs are historical snapshots only and may contain stale completion claims.

## Quick Start

### First-time setup

```bash
xcode-select -p
xcodegen --version
cd /Users/allie/Develop/anvil
./scripts/dev
```

That will:

1. Generate `Anvil.xcodeproj` from [`project.yml`](/Users/allie/Develop/anvil/project.yml)
2. Open the project in Xcode

### Daily workflow

1. Open [`Anvil.xcodeproj`](/Users/allie/Develop/anvil/Anvil.xcodeproj)
2. Select the `Anvil` scheme
3. Press `Cmd-R`

Do not open the repo root in Xcode. If Xcode opens the folder as a Swift package workspace, you are in the wrong entry point and app lifecycle behavior will be wrong.

## Why This Repo Is Structured This Way

- `project.yml` is the source of truth for the macOS app project.
- `Anvil.xcodeproj` is committed so `Cmd-R` works immediately for contributors.
- `Packages/*` contains the modular Swift packages used by the app.
- There is intentionally no root `Package.swift`, because a root package manifest causes Xcode to treat the repo like a package workspace when you open the folder.
- UI and feature work are governed by the docs above. If a visible control, shortcut, sidebar row, or command is not in `TRUTH_MATRIX.md`, it should not ship.

## Common Commands

Generate or refresh the project:

```bash
./scripts/dev --generate-only
```

Open the project:

```bash
open Anvil.xcodeproj
```

Build the app from the command line:

```bash
xcodebuild -project Anvil.xcodeproj -scheme Anvil -derivedDataPath /tmp/anvil-derived build
```

Run deterministic UI-test scenarios and visual screenshots with:

```bash
ANVIL_UITEST_SCENARIO=review-diff xcodebuild -project Anvil.xcodeproj -scheme Anvil -derivedDataPath /tmp/anvil-derived build
```

Supported seed scenarios live in [`Packages/AnvilUI/Sources/App/UITestScenario.swift`](/Users/allie/Develop/anvil/Packages/AnvilUI/Sources/App/UITestScenario.swift).

Run package tests across all local packages:

```bash
./scripts/test-packages
```

## Repo Layout

- `App/` macOS app target sources, assets, and plist
- `Packages/` local Swift packages
- `Tests/UITests/` macOS UI tests for the app target
- `project.yml` XcodeGen source for the app project
- `Anvil.xcodeproj` generated Xcode project committed for normal app development

## Tooling

- Xcode 16+
- Swift 6+
- XcodeGen 2.40+

If Xcode or Swift look outdated in Terminal, make sure the active developer directory points to full Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
