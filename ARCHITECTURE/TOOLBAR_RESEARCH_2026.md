# Toolbar and Top Chrome Research — 2026
# Agent-Native IDE Design Vision for Anvil

**Status:** Research synthesis, product design direction
**Scope:** Toolbar, title bar, top chrome design for an AIDE spanning Plan → Build → Review → Operate
**Date:** March 2026

---

## Executive Summary

Every current AI-native IDE treats the toolbar as an afterthought — a VS Code-derived chrome strip bolted onto a conversational AI panel. None of them have designed the top of the window for a workflow that spans planning, multi-agent execution, code review, and deployment in a single persistent shell. Anvil has a genuine opportunity to define what an agent-native toolbar looks like. This document synthesizes research across nine tools and proposes a concrete design direction.

---

## Per-Tool Findings

### 1. Cursor

**Topology:** VS Code foundation with minimal customization to the title bar. The top chrome is largely inherited from Electron's standard window frame.

**What's there:**
- A mode/layout toggle in the top-left area (Agent vs. Editor mode), though this was removed in a later update and buried in settings — causing widespread user frustration. The community explicitly asked for it to be restored as a visible top-bar control.
- A model selector dropdown lives inside the chat panel, not in the toolbar. It is not always visible.
- No project or branch information is surfaced in the toolbar by default; this defers to VS Code's status bar.
- The right side has the standard VS Code panel toggles.

**Key problems identified from user research:**
- Layout preferences reset on every update, forcing users to reconfigure their Agent/Editor split.
- Mode switching is buried — users spent 15 minutes searching for how to return to Editor mode after a forced update.
- No persistent AI status in the top chrome. You have to open the chat panel to know if an agent is running.
- No sense of "where am I in my workflow" from the toolbar. It is spatially ambiguous — the same chrome appears whether you are coding, reviewing, or browsing.

**Design lesson:** Toolbar ownership of mode/space state is critical. When you remove or hide it, users feel lost. The chrome must hold context, not hide it.

---

### 2. Windsurf

**Topology:** VS Code fork with Cascade (AI agent) in a right sidebar. Interface feels familiar to VS Code users. Status bar integration for login/auth.

**What's there:**
- The AI (Cascade) is represented entirely via a sidebar panel, not the toolbar.
- Bottom status bar has a Windsurf authentication widget at the right edge.
- No persistent agent status in the top chrome.
- "Windsurf Tab" as an action key — a keyboard-first entry point to suggestions — is the closest thing to a top-level AI affordance.

**Design lesson:** Cascade's contextual awareness (it reads terminal output, watches file changes, understands the full codebase) is genuinely excellent — but you would never know from the chrome. Windsurf hides its most powerful capability in a sidebar toggle. There is no ambient sense that the AI is aware of your context. Anvil should make ambient AI awareness visible from the toolbar, not tucked behind a panel.

---

### 3. Zed

**Topology:** Native Rust/GPUI application. Minimal title bar by design. The team explicitly values removing visual chrome to maximize content.

**What's there:**
- Title bar shows: branch icon + branch name, project name, collaboration status (live cursors, avatar pile), sign-in button, update notifications, and a plan/tier chip.
- The branch name is in the title bar, not the status bar — a notable difference from VS Code.
- Collaboration is surface-level visible: other users' avatars appear in the title bar, making multiplayer presence feel real.
- Agent panel is a toggleable right-side panel with no persistent toolbar indicator.
- Thin, compact UI. Recent PRs have reduced padding, removed unnecessary borders, and made the toolbar feel lighter.

**Design lesson:** Zed's title bar is the best example among current tools of treating the top chrome as informational context, not just buttons. The project/branch/collaborator grouping answers "where am I and who is here" at a glance. Anvil should take this further: replace "collaborators" with "agent sessions" and make AI-context as visible as human collaboration is in Zed.

---

### 4. Linear

**Topology:** Electron app (cross-platform), recently shipped a major macOS Liquid Glass-style mobile redesign and a desktop UI refresh. Exceptional design quality relative to the category.

**What they do with navigation:**
- An inverted-L chrome: left sidebar + top tab strip. The tab strip spans the full width — recently made more compact, with rounded corners, and reduced text/icon sizing.
- Navigation sidebar deliberately dimmed so the content area takes visual precedence. The sidebar is structure you feel, not structure you read.
- Headers, navigation controls, and view controls are now consistent across every surface (projects, issues, reviews, documents). Consistency is the organizing principle.
- Icons were redrawn and reduced in prominence throughout — less icon noise, more content signal.

**Context-switching model:** Space-level navigation lives in the sidebar rail. Within a space, the top tab strip shows the current entity or view, not a list of all spaces. You are always inside one context; the chrome reflects that context rather than exposing all contexts simultaneously.

**ProKit philosophy (from their Liquid Glass write-up):** Rather than adopting Apple's consumer Liquid Glass APIs directly, Linear built their own custom implementation because they needed precision control for dense professional workflows. They deliberately excluded refraction effects (which Apple uses) because "refraction can make dense professional interfaces harder to read." They describe this as a "ProKit philosophy: purpose-built, disciplined, and designed for sustained focus."

**Design lesson:** For professional tools, glass as material signals elevation and hierarchy — not decoration. Reduce refraction. Let structure be felt, not seen. Never let the chrome compete with the content.

---

### 5. Arc Browser

**Topology:** Fully inverted tab model. Everything traditional browsers put at the top (address bar, tabs, navigation) moved to a left sidebar. The top chrome is essentially eliminated; the content fills the window.

**What happened:** Arc was retired in mid-2025 when The Browser Company pivoted to an AI-first assistant (Dia), subsequently acquired by Atlassian. Arc still receives security patches but no new features.

**The innovation while it lasted:**
- Spaces as first-class chrome: switching between Work, Personal, or Project spaces changes the entire left sidebar context, including pinned tabs, folder structure, and theme color. Space identity is always visible as a colored accent on the rail.
- Peek model: clicking a link from a pinned tab opens it as an ephemeral overlay — lightweight, dismissable — rather than a full navigation. This is the browser equivalent of Anvil's inspector panel.
- Zero top chrome when browsing. The URL bar, tabs, history buttons — all hidden by default. The content is the window.

**Design lesson for Anvil:** Spaces deserve stronger visual identity than an icon in a rail. When you switch from Plan to Build to Review, the app should *feel* different — not just show different content with the same chrome. Accent color per space, distinct toolbar composition per space, distinct sidebar personality per space. Arc got this right. Nobody building dev tools has implemented it.

---

### 6. Raycast

**Topology:** macOS-native launcher. No persistent window; invoked via hotkey as a floating command bar. The entire interaction model is the bar itself.

**Design philosophy:** Three principles — fast, simple, delightful. Every interaction goes through search. The right side of the bar shows available actions with keyboard shortcuts, teaching the user the shortcut while they use the mouse path. Compact mode makes the default state smaller and more focused.

**What Raycast does with context:** The search bar adapts its meaning based on context. There is no toolbar that changes — the bar *is* the context. Typing changes the candidate list, and the right panel shows contextual actions for the selected candidate. This is fundamentally different from a persistent toolbar: it's an ambient launcher that becomes context-specific the moment you type.

**Design lesson:** Anvil's Command Palette (`⌘K`) should behave this way. The palette is not just a search box — it is a context-adaptive action surface. The recent addition of `CodebaseQAView` as a distinct overlay suggests Anvil is heading toward multiple distinct palette-like surfaces. These should probably unify into one adaptive palette that changes its candidate set and action panel based on the current space. The toolbar does not replace the palette; they serve different roles.

---

### 7. Notion

**Topology:** Web-first (Electron) workspace tool. Top chrome shows breadcrumb trail + page actions.

**What Notion does:**
- Breadcrumbs in the title bar show the hierarchy path to the current page. Each segment is clickable. This answers "where am I in the information hierarchy" without requiring sidebar awareness.
- The breadcrumb is functional navigation, not just labeling.
- The top bar is minimal on purpose — breadcrumb + a few page-level action icons (share, comment, favorite). No global nav in the title bar.
- Workspace switching happens in the sidebar, not the title bar.

**Design lesson:** Breadcrumbs as primary navigation context are powerful in document-centric apps but awkward in task/workflow apps where you are not traversing a hierarchy so much as switching between phases. Anvil should use the toolbar to show *phase context* (which Space, which Source, which branch), not a deep breadcrumb trail. The question the toolbar answers is "what phase of work am I in and on which project" — not "where am I in a document tree."

---

### 8. Figma

**Topology:** Web-based design tool (Electron desktop version). Historically had a full top toolbar. Controversial UI3 redesign moved the primary tool palette from the top to a floating bottom bar, aligned with FigJam and Figma Slides.

**The top toolbar in Figma (classic):**
- Left: file/project breadcrumb, team selector
- Center: drawing tools (move, frame, shape, pen, text, etc.) — mode-based, context-sensitive
- Right: share, zoom controls, comment mode, prototype mode, present mode

**The UI3 controversy:** Moving the toolbar bottom-center was motivated by aligning with simpler sibling products (FigJam, Slides). It generated significant community backlash because:
- The toolbar being bottom-center means constant downward attention shift, disrupting the top-left-to-bottom-right reading/work flow.
- The floating toolbar overlaps design content in shared screens and screen recordings.
- Users can not customize toolbar position.

**Design lesson:** Tool-mode selection (the equivalent of selecting a drawing tool vs. a text tool in Figma) belongs at the top, not floating over content. In Anvil's context, space-mode switching (Plan, Build, Review, Operate) is the equivalent — it should live in the top chrome, in a fixed, predictable location. Never float the primary mode switcher.

---

### 9. Apple's Native Apps: Xcode, Keynote, Final Cut Pro

**macOS Tahoe (macOS 26) toolbar model:**
The WWDC25 session "Build an AppKit app with the new design" specifies the canonical Tahoe toolbar pattern:

- Toolbar elements sit on Liquid Glass material that floats above the content.
- AppKit auto-groups multiple toolbar buttons on one glass element by control type.
- Non-interactive items (status text, titles) should set `isBordered = false` so they do not appear on glass.
- Use `NSItemBadge` for numeric or text badges on toolbar items (e.g., a count of uncommitted files on a branch button).
- Use `.style = .prominent` to tint glass with the accent color for state emphasis or important actions.
- The glass adapts to the content behind it: if the scrolled content is bright, the glass switches to dark; if dark, it goes light. Appearance changes use `NSAppearance`.
- Remove `NSVisualEffectView` from sidebars — it prevents glass from showing through.

**Xcode's toolbar model:**
- Left cluster: run controls, scheme/destination picker, build status indicator
- Center: activity viewer (shows build progress, current task, diagnostics count) with a spinner during builds
- Right cluster: panel toggles (navigator, inspector, utility area), layout controls

The activity viewer in Xcode is the clearest precedent for what Anvil's toolbar needs: a persistent, center-positioned status area that shows what the system is currently doing (building, indexing, running, waiting) without requiring you to open a panel. Xcode's center is never empty — it always tells you something about system state.

**Keynote's toolbar model:**
- Context-sensitive: adds text formatting tools when text is selected, image tools when an image is selected
- Always visible: the tool cluster changes with selection, but the toolbar height and position are constant
- Right cluster: format panel toggle, collaboration indicators, presenter mode

**Final Cut Pro's toolbar model:**
- Tool palette is a small, always-visible segment in the upper left (blade, arrow, zoom, etc.)
- Center: timeline ruler and playhead context
- Right: inspector toggle, effects browser toggle, media browser toggle

**Key insight from Apple's own apps:** The toolbar is split into stable zones. Left is about navigation/orientation (project, location). Center is about current activity (status, context, selection). Right is about surface control (inspector, panels, layout). This three-zone model is not arbitrary — it matches how humans scan: left for "where am I," center for "what's happening," right for "how is this laid out."

---

## Pattern Synthesis

### What Works Across Tools

1. **Three-zone toolbar is universal and functional.** Left = context/navigation. Center = activity/state. Right = panel controls. Every professional app (Xcode, Final Cut, Keynote, VS Code) uses this. Deviate from it at user cost.

2. **The branch/project indicator is table stakes and belongs in the left zone.** Zed puts it in the title bar. VS Code puts it in the status bar. Xcode buries it in the scheme picker. The top-left is the most natural home because it answers "where am I working" — which is the first question a user asks every time they look at the window.

3. **AI status must be ambient, not panel-gated.** Every current AI tool (Cursor, Windsurf, Zed) hides agent status behind a panel toggle. Xcode's activity viewer shows what the build system is doing at all times. Anvil should apply this exact pattern to agent sessions: the center of the toolbar always tells you what the AI is doing.

4. **Space/mode switching must be visible and persistent.** Cursor removing their Agent/Editor toggle from the toolbar was their biggest UX mistake of 2025. Users felt lost. The space switcher must live in the toolbar, be always visible, and not require hunting through settings.

5. **Information density must be calibrated, not maximized.** Linear's recent refresh added *nothing* — they removed icons, softened borders, dimmed the sidebar, and made tabs smaller. The result feels less cluttered and more premium. More chrome is not more capability. Fewer, calmer signals communicate confidence.

6. **Glass is a hierarchy signal, not decoration.** For Tahoe-native apps, Liquid Glass on toolbar items signals "this is interactive, this is elevated." Non-interactive status text should not be on glass. Use `isBordered = false` for labels. Use `.prominent` style for the single most important state indicator (active agent run, active branch with dirty state, etc.).

### What Fails Across Tools

1. **Floating toolbar position (Figma UI3).** Moving primary mode switching to a floating or bottom position creates constant attention misdirection and content occlusion. Fixed, top-positioned, three-zone toolbar is the right answer for an app spanning 5 spaces.

2. **AI hidden behind panel toggles (Cursor, Windsurf).** If a developer does not see the agent is running, they feel the app is idle. Ambient AI awareness must be visible at a glance, from the top chrome.

3. **Generic chrome across all spaces.** Current IDEs show the same toolbar regardless of whether you are in a planning view, an editor, a review surface, or a deployment dashboard. Anvil should let each space compose its toolbar zone differently — same three-zone structure, different center content.

4. **Status bar overload.** VS Code and Xcode push too much into the status bar: branch, encoding, line/column, problems count, extension status, git sync, language mode, active debug session. It becomes unreadable noise. Anvil's status bar should be spare. The toolbar carries the important context; the status bar carries only what is truly persistent and compact.

---

## Design Vision: What Anvil's Toolbar Should Be

### The Core Idea

Anvil's toolbar should answer three questions simultaneously, without requiring the user to open any panel:

1. **What project and branch am I on?** (Left zone)
2. **What is the app doing right now, and in what phase?** (Center zone)
3. **What can I toggle to see more?** (Right zone)

For an AIDE that spans Plan → Build → Review → Operate, this is not enough if the toolbar shows the same three zones in every space. The center zone should be *compositionally different* depending on the active space — not different items placed in a fixed grid, but a genuinely different semantic context.

### Zone-by-Zone Specification

#### Left Zone: Context Anchor

Always shows:
- **Project name** (clickable, opens project switcher) — the name of the current workspace root
- **Branch pill** (clickable, opens branch picker) — branch name + dirty file count badge via `NSItemBadge`

The project name and branch together answer "where am I and is there unsaved/uncommitted work." This replaces the current approach where project lives in the status bar (too low) and branch is in the center of the toolbar (crowding the space/source picker).

#### Center Zone: Space Compositor (the AIDE differentiator)

The center zone is the key differentiator. It shows different content per space.

**In Plan:**
The center shows: `Plan` label + active sprint/project scope pill. No source picker (single-source space). If an AI agent is currently triaging tickets or generating a plan, a compact "Thinking..." pulse replaces the scope pill.

**In Build:**
The center shows: source picker tabs (Sessions, Files, Terminal, Data, Tests) + agent activity indicator. The agent activity indicator is always visible — not just when running. It shows one of: "Idle," "Running: [tool name] [elapsed]," or "Failed." This is Xcode's activity viewer applied to AI sessions. When multiple background agents are running, a badge count appears on the activity indicator without hiding the primary indicator.

**In Review:**
The center shows: `Review` label + current PR title or repository context + CI status icon. If no PR is selected, shows the repository and branch being reviewed.

**In Operate:**
The center shows: source picker tabs (Deploy, Monitor) + active environment chip (e.g., "production" in orange or "staging" in green). The environment chip uses `.prominent` NSToolbarItem style with `backgroundTintColor` set to the environment's semantic color.

**In Library:**
The center shows: source picker tabs (Docs, Rules, Extensions, Inbox, Chat, Schedule). Minimal — no active indicator needed. Library is configuration and reference, not action.

#### Right Zone: Panel Controls

Fixed set, always in the same order:
1. Command Palette (`⌘K`) — search/magnifier icon
2. Notifications bell (badge when unread)
3. Inspector toggle (`⌘⇧I`) — `info.circle`
4. Agent Chat toggle — `sparkles` — this stays but gets a visual state: filled/colored when agent chat is active or has unread messages

The right zone should not change per space. Its role is layout control, not workflow context.

### Agent Status as First-Class Toolbar Citizen

The single most important change Anvil can make to its toolbar is elevating agent status from the status bar to the center toolbar zone.

Currently: agent status lives in the status bar (bottom), between cost display and background session badge. It is easy to miss and visually low-priority.

Proposed: in the Build space, the center zone always shows agent activity as the primary element. The source picker (Sessions, Files, etc.) is secondary. The agent activity indicator is the "activity viewer" equivalent — always present, always telling you something.

Concretely:
- Idle: small gray dot + "Idle" in `.secondary` color — no glass, `isBordered = false`
- Running: accent-green Liquid Glass pill with pulsing indicator + current tool name + elapsed timer — `.prominent` style
- Failed: red Liquid Glass pill — `.prominent` + `backgroundTintColor = .systemRed`
- Background sessions: badge count on the Build space icon in the workspace rail, not a separate toolbar element

### Space-Differentiated Identity

Following Arc's lesson about spaces having visual personality: each Anvil space should use a distinct accent within the toolbar's glass elements. Not a different color scheme for the whole window, but the toolbar's active source indicator and any prominent state badges should use the space's semantic color:

- **Plan:** blue (task/project color)
- **Build:** green (execution/running color)
- **Review:** orange (code review, attention required)
- **Operate:** purple (production, infrastructure)
- **Library:** gray/neutral (reference, non-active)

This is a subtle identity signal — it does not change the sidebar or canvas background, only the toolbar's interactive glass elements. Users will develop a visceral sense of "I'm in Build right now" from the green activity indicator, without any explicit label.

### Information Density Target

Looking at Linear's design refresh lesson: more information is not better. The right question is not "what can we fit in the toolbar" but "what does the user need to know without thinking about it."

The answer for Anvil is three things:
1. What project/branch am I on (left)
2. What space am I in and is the AI doing anything (center)
3. What panels are open (right)

Everything else belongs elsewhere:
- File encoding, line/column → status bar (only when relevant to the Build/Files context)
- Cost → status bar (always, but small)
- Provider health → status bar (small indicator, popover on click)
- Background agent count → workspace rail badge on the Build space icon
- Notification count → bell badge in right toolbar zone

### Tahoe Glass Implementation Notes

Based on WWDC25 guidance:

- Branch pill: `.bordered` control size `.small` — gets automatic glass from AppKit
- Agent activity indicator (when running): custom `NSToolbarItem` with `style = .prominent` and `backgroundTintColor = .systemGreen`
- Agent activity indicator (idle): `isBordered = false` — just text, no glass
- Source picker tabs: grouped via `NSToolbarItemGroup` — AppKit will place them on a single shared glass element
- Notification bell with badge: `NSItemBadge.count(unreadCount)` — native badging, no custom orange dot
- Space color accent on environment chip: `backgroundTintColor = .systemOrange/.systemGreen` depending on environment

Remove `NSVisualEffectView` from the sidebar when adopting Tahoe glass — it prevents the toolbar glass from rendering correctly.

---

## Competitive Gaps Anvil Can Close

### Gap 1: No AI-native tool has a "what is the AI doing" toolbar indicator

Cursor, Windsurf, Zed — none of them show agent activity in the persistent toolbar. Anvil's Build center zone agent activity indicator would be a genuine first. Xcode has the closest precedent with its activity viewer, but Xcode's viewer is for build/compile, not AI agents.

### Gap 2: No AI tool has space-differentiated toolbar composition

Every current AI IDE shows the same chrome regardless of workflow phase. Anvil's center-zone composition changing per space is a product differentiator that also makes the app feel more intentional.

### Gap 3: No AI tool has made branch + project + AI status the first three visible things

Zed puts project/branch in the title bar. VS Code puts branch in the status bar. Cursor has no visible project context in the toolbar. Linear has consistent cross-surface navigation. Combining project context (left), AI activity (center), and panel controls (right) into a coherent three-zone toolbar is something none of these tools have done.

### Gap 4: The "everything app" problem — most tools optimize for one phase

Cursor is built for Build. Linear is built for Plan. GitHub is built for Review. Vercel is built for Operate. Anvil spans all four. The toolbar is where this promise becomes visible or fails. If the toolbar looks the same in Plan as in Operate, users will not believe the app spans those phases. The space-differentiated center zone is the design pattern that makes the "everything app" promise legible.

---

## Implementation Priority

These changes should be sequenced:

1. **Move project name from status bar to left toolbar zone.** Currently in status bar. Should be in the left toolbar zone alongside the branch pill. Low risk, high orientation value.

2. **Move agent activity from status bar to center toolbar zone (Build space only).** The `AgentActivityIndicator` currently lives in `StatusBar.swift`. It should be a `ToolbarItem(placement: .principal)` element when `currentSpace == .build`. The status bar item should be removed or reduced to a minimal icon-only presence.

3. **Add environment chip to Operate center zone.** When in the Operate space, the center zone should show the active environment (staging/production) as a prominent pill.

4. **Add CI status indicator to Review center zone.** When in the Review space and a PR is selected, the center zone shows PR title + CI status icon.

5. **Adopt Tahoe NSItemBadge for branch dirty count.** Replace the current custom orange badge (custom `RoundedRectangle` + hardcoded orange `Color`) with `NSItemBadge.count()`.

6. **Adopt prominent NSToolbarItem style for running agent.** Replace the current custom green background clip shape with `style = .prominent` + `backgroundTintColor = .systemGreen`.

---

## Files Referenced

Current toolbar implementation: `/Users/allie/Develop/anvil/Packages/AnvilUI/Sources/Shell/MainWindow.swift`
Current agent activity indicator: `/Users/allie/Develop/anvil/Packages/AnvilUI/Sources/Shell/StatusBar.swift`
Source picker: `/Users/allie/Develop/anvil/Packages/AnvilUI/Sources/Shell/ToolbarSourcePicker.swift`
Shell vocabulary canon: `/Users/allie/Develop/anvil/ARCHITECTURE/SHELL_VOCABULARY.md`
North star shell: `/Users/allie/Develop/anvil/ARCHITECTURE/NORTH_STAR_SHELL.md`
UX shell contract: `/Users/allie/Develop/anvil/ARCHITECTURE/UX_SHELL.md`

---

## Sources

- [Linear: How We Redesigned the Linear UI](https://linear.app/now/how-we-redesigned-the-linear-ui)
- [Linear: A Calmer Interface for a Product in Motion](https://linear.app/now/behind-the-latest-design-refresh)
- [Linear: A Linear Spin on Liquid Glass](https://linear.app/now/linear-liquid-glass)
- [Linear: UI Refresh Changelog March 2026](https://linear.app/changelog/2026-03-12-ui-refresh)
- [Zed: Agentic Editing](https://zed.dev/agentic)
- [Apple WWDC25: Build an AppKit App with the New Design](https://developer.apple.com/videos/play/wwdc2025/310/)
- [Arc Browser: UI/UX Design Analysis](https://medium.com/design-bootcamp/arc-browser-rethinking-the-web-through-a-designers-lens-f3922ef2133e)
- [Raycast: A Fresh Look and Feel](https://www.raycast.com/blog/a-fresh-look-and-feel)
- [UX Patterns: Model Selector](https://uxpatterns.dev/patterns/ai-intelligence/model-selector)
- [10 Things Developers Want From Agentic IDEs in 2025](https://redmonk.com/kholterhoff/2025/12/22/10-things-developers-want-from-their-agentic-ides-in-2025/)
- [Cursor UI Megathread: Layout and Feedback](https://forum.cursor.com/t/megathread-cursor-layout-and-ui-feedback/146790)
- [Windsurf IDE Review 2025](https://www.secondtalent.com/resources/windsurf-review/)
- [Figma UI3 Toolbar Position Discussion](https://forum.figma.com/t/allow-us-to-dock-move-the-new-ui3-toolbar/78995)
- [Liquid Glass in Swift: Official Best Practices](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo)
