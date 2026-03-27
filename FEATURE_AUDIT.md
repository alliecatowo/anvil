# Anvil Feature Audit — What We Have vs. What We Need

## Current State: 270 files, 21K LOC, 8 packages, running macOS app

---

## FEATURES WE HAVE (with missing sub-features)

### 1. Agent Mode (AI Conversations)
**Have:** Basic conversation view, tool call rendering, streaming, input bar, session list
**Missing:**
1. Slash commands (/review, /commit, /test, /explain, /fix)
2. @ references (@file, @ticket, @branch with autocomplete)
3. Inline code edit suggestions (accept/reject per hunk in editor)
4. Model picker per session (switch Claude/GPT mid-conversation)
5. Conversation forking (branch from any message)
6. Session search (find across all conversations)
7. Session export (markdown, JSON)
8. Session sharing/linking
9. Multi-agent orchestration (dispatch review agent from coding agent)
10. Context injection (drag files, tickets, errors into conversation)
11. Token usage visualization (progress bar toward context limit)
12. System prompt editor per session
13. Tool approval memory ("always allow read_file")
14. Streaming code blocks with syntax highlighting
15. Image/screenshot attachment support
16. Voice input integration
17. Conversation templates ("Fix bug in {file}", "Review PR #{num}")
18. Cost budget per session with warnings
19. Background agent sessions (run while you work on other things)
20. Agent activity indicator in status bar (what is it doing RIGHT NOW)

### 2. Intent Mode (Tickets/Kanban)
**Have:** Ticket list, board view, ticket detail, priority colors, cycle tracking
**Missing:**
1. Drag-and-drop on kanban board
2. Create ticket inline (quick add)
3. Ticket templates
4. Bulk actions (select multiple, change status)
5. Sprint planning view (drag from backlog to sprint)
6. Velocity/burndown charts
7. Ticket → branch → agent pipeline button
8. Sub-tasks / checklists within tickets
9. Time tracking on tickets
10. Ticket comments/activity log
11. Assignee picker with team members
12. Custom fields per project
13. Filters: saved filters, complex queries
14. Import from Linear/Jira
15. Ticket linking (blocks, blocked by, related)
16. Estimation poker / story point voting
17. Ticket auto-triage (AI suggests priority/labels)
18. Due date reminders / overdue highlighting
19. Ticket search across all projects
20. Archive / done state management

### 3. Review Mode (Diff Review)
**Have:** Side-by-side + unified diff, per-hunk approve/reject, review inbox
**Missing:**
1. Inline comments on specific lines
2. Comment threads with replies
3. Review checklist (customizable per project)
4. "Review against X" — pick base branch
5. File-level approve/reject
6. Suggested changes (edit in review, propose as suggestion)
7. Review summary generation (AI)
8. Code owners / auto-reviewer assignment
9. Review request notifications
10. Merge button (after approval)
11. Rebase/update branch from review
12. Review templates
13. Batch review (review multiple PRs)
14. Coverage overlay on diff (which lines have tests?)
15. Git blame integration in diff view
16. Review statistics (time to review, comments per PR)
17. CI status in review (tests passing?)
18. Linked tickets shown in PR
19. Review history (what did I review before?)
20. Cross-repo review (monorepo support)

### 4. Ship Mode (Deploy Dashboard)
**Have:** Environment cards, build log viewer, env var manager
**Missing:**
1. Real deployment provider (Vercel, Railway, Fly.io)
2. One-click deploy button that actually deploys
3. Deployment history with rollback
4. Preview URL rendering (inline browser)
5. Environment comparison (diff env vars across envs)
6. Deploy locks / freeze indicators
7. Health checks / uptime monitoring
8. Domain management
9. Deployment pipelines visualization
10. Auto-deploy on merge configuration
11. Deploy notifications (Slack/email)
12. Resource usage (CPU, memory, bandwidth)
13. Cost per environment
14. Feature flags integration
15. Canary/blue-green deploy support
16. Deployment approval workflow
17. Secrets rotation reminders
18. Deployment logs search
19. Multi-service deploy coordination
20. Rollback dry-run (preview what rollback changes)

### 5. Editor Mode (Code Editing)
**Have:** Basic syntax highlighting, file tree, symbol outline, line numbers, tabs
**Missing:**
1. Real syntax highlighting (Tree-sitter, not regex)
2. LSP integration (autocomplete, go-to-definition, hover docs)
3. Multi-cursor editing
4. Find and replace (in file + across project)
5. Code folding
6. Minimap
7. Git decorations in gutter (added/modified/deleted lines)
8. Error/warning squiggles from LSP
9. Code actions / quick fixes
10. Bracket matching + auto-close
11. Indent guides
12. Word wrap toggle
13. Whitespace visualization
14. File encoding indicator
15. Cursor position (line:col) in status bar — clicking jumps to line
16. Split editor (vertical/horizontal)
17. Diff editor (compare two files)
18. Read-only file indicator
19. Large file handling (virtualized rendering)
20. AI inline edit (⌘K to edit selection with AI)

### 6. Database Mode
**Have:** Schema explorer, query console, results table
**Missing:**
1. Real database connection (PostgreSQL, MySQL, SQLite)
2. Query autocomplete from schema
3. Query history with timestamps
4. Save/name queries
5. Result export (CSV, JSON)
6. Table data browser (paginated, filterable)
7. ER diagram visualization
8. Migration runner
9. Index analysis
10. Query explain plan visualization
11. Connection profiles (save multiple DBs)
12. Schema diff between environments
13. Data seed generation (AI)
14. Row-level editing
15. Foreign key navigation (click to follow)

### 7. Terminal Mode
**Have:** Fake terminal with sample output
**Missing:**
1. Real PTY shell (spawn zsh/bash)
2. ANSI color rendering
3. Terminal resize handling
4. Multiple terminal tabs/splits
5. Shell integration (CWD tracking)
6. Command history search
7. Link detection (clickable URLs)
8. Copy/paste with proper selection
9. Terminal profiles (different shells, envs)
10. Command output capture (for AI context)
11. Terminal in bottom panel (always available)
12. Terminal in split with editor
13. Kill/restart terminal
14. Environment variable management per terminal
15. Smart command suggestions (AI)

### 8. Docs Mode
**Have:** Doc browser tree, markdown editor with preview
**Missing:**
1. Rich markdown editing (toolbar, shortcuts)
2. Live preview (real-time render)
3. Document versioning (git-backed)
4. Document search (full-text)
5. External docs browsing (DevDocs, MDN, language docs)
6. Document templates
7. Table of contents / outline
8. Collaborative editing indicators
9. Document linking (wiki-style [[links]])
10. Image embedding
11. Code snippet embedding with syntax highlighting
12. Document export (PDF, HTML)
13. API documentation auto-generation
14. README generator
15. Personal vs team vs external doc sections

### 9. Messaging Mode
**Have:** Channel list, chat view, sample messages
**Missing:**
1. Real Slack/Discord integration
2. Thread view
3. Reactions
4. File sharing in messages
5. Code block sharing with syntax highlighting
6. @mention autocomplete
7. Channel creation/management
8. Read/unread tracking
9. Message search
10. Message pinning
11. DM conversations
12. Presence indicators (online/offline)
13. "Turn this into a ticket" from message
14. Notification preferences per channel
15. Message formatting toolbar

### 10. Notifications Mode
**Have:** Inbox view, activity feed
**Missing:**
1. Real notification sources (GitHub, CI, etc.)
2. Notification preferences/rules
3. Snooze functionality
4. Batch actions (mark all read, archive)
5. Filter by source/type
6. Notification badges on mode tabs
7. Desktop notifications (NSUserNotification)
8. Do Not Disturb mode
9. Notification digest (daily summary)
10. Priority-based sorting
11. Action buttons on notifications (approve PR, view error)
12. Notification grouping (by project, by type)
13. Sound preferences
14. Notification center integration (macOS)
15. Smart triage (AI-powered: "3 need attention now")

### 11. Observability Mode
**Have:** Error feed, error detail with stack traces, metrics dashboard
**Missing:**
1. Real Sentry/Datadog integration
2. Error grouping and deduplication
3. Error → code navigation (click stack frame → open file)
4. Error trends over time (charts)
5. Alert configuration
6. Metric time-series charts
7. Service health map
8. Error → deployment correlation
9. Real-time streaming errors
10. Error assignment (assign to team member)

### 12. Schedule Mode
**Have:** Agenda view, time blocks
**Missing:**
1. Real calendar integration (Apple Calendar, Google Cal)
2. Drag to create time blocks
3. Focus mode (block distractions)
4. Meeting join buttons
5. Schedule conflicts detection
6. Availability sharing
7. Calendar week/month views
8. Recurring events
9. Ticket deadline integration
10. AI schedule optimization

### 13. Command Palette
**Have:** Fuzzy search, mode switching, keyboard nav
**Missing:**
1. File search (open any file by name)
2. Symbol search (go to function/class)
3. Recent files list
4. Action history
5. Custom command registration (from plugins)
6. Contextual commands (different per mode)
7. Command categories with section headers that update live
8. Nested commands (e.g., "Git: " prefix shows git commands)
9. Preview pane for file results
10. Parameter input (e.g., "Go to line: ___")

### 14. Settings
**Have:** Provider config, appearance, keybindings tabs
**Missing:**
1. Settings search
2. Per-project settings override
3. Import/export settings
4. Settings sync across machines
5. Theme editor/picker
6. Font picker for editor
7. Extension/plugin management
8. Proxy configuration
9. Telemetry opt-in/out
10. Reset to defaults per section

### 15. Quick Capture + Project Notes
**Have:** ⌘⇧Space overlay, markdown scratchpad
**Missing:**
1. Quick capture → ticket conversion
2. Voice note capture
3. Screenshot capture
4. Link/bookmark saving
5. Tag system for notes
6. Note search
7. Note templates
8. Daily log auto-generation
9. Note → agent context (send note to agent)
10. Timestamped entries with collapsible sections

---

## TOP-LEVEL FEATURES WE'RE COMPLETELY MISSING

### A. Source Control Panel (dedicated git UI)
Not the "Review mode" — a source control panel like VS Code's:
- Changed files list with stage/unstage
- Commit message input + commit button
- Branch picker + create/delete
- Stash management
- Git graph (visual branch topology)
- Merge conflict resolution UI
- Cherry-pick, rebase, revert UI
- Remote management (fetch, pull, push)
- Tag management

### B. Search Across Project
- Full-text search with regex support
- Search and replace across files
- Search results with preview
- Search history
- Search scopes (current file, project, workspace)
- Search filters (file type, folder, gitignored)

### C. Problems / Diagnostics Panel
- LSP errors and warnings list
- Click to navigate to error
- Auto-fix suggestions
- Error counts in status bar
- Per-file error indicators in file tree

### D. Debug / Run Configurations
- Launch configurations (like VS Code's launch.json)
- Breakpoint management
- Debug console
- Variable inspector
- Call stack
- Step through/over/out

### E. Extensions / Plugin Marketplace
- Browse available plugins
- Install/uninstall
- Plugin settings
- Plugin update management
- Plugin recommendations based on project

### F. Snippets System
- Code snippets library
- Snippet insertion with tab stops
- Custom snippet creation
- AI-generated snippets
- Snippet sharing

### G. Refactoring Tools
- Rename symbol (across project)
- Extract function/variable/constant
- Move to file
- Inline variable
- AI-powered refactoring suggestions

### H. AI Inline Edit (Cursor-style ⌘K)
- Select code → ⌘K → describe change → see diff → accept/reject
- Ghost text suggestions
- Multi-file edit proposals
- Edit history

### I. Workspace / Multi-Window
- Multiple windows
- Window layouts (save/restore)
- Detachable panels
- Full-screen mode
- Split screen with other apps

### J. User Profile / Account
- User avatar and name
- Login state (GitHub, etc.)
- Usage statistics
- Billing/subscription info
- Team management

### K. Collaboration
- Shared sessions (pair programming)
- Shared agent sessions
- Team activity feed
- Shared bookmarks/notes
- Code review assignments

### L. AI Autocomplete
- Ghost text code completion
- Multi-line suggestions
- Tab to accept
- Context-aware (uses open files, recent edits)
- Provider-selectable (Claude, Copilot, local)

### M. Diff / Merge Tool
- 3-way merge for conflicts
- File comparison (any two files)
- Folder comparison
- Merge preview

### N. HTTP / API Client Mode
- Request builder (we have the primitive but no real UI for making requests)
- Environment variables
- Request history
- Collection management
- Response visualization

### O. Container Management
- Docker container list
- Container logs
- Docker Compose up/down
- Image management
- Resource monitoring

### P. Package / Dependency Viewer
- Dependency tree visualization
- Outdated package alerts
- Vulnerability scanning
- License compliance
- Update assistant

### Q. Breadcrumb Navigation
- File path breadcrumbs at top of editor
- Click to navigate up
- Dropdown for siblings at each level

### R. Minimap
- Code overview on right side of editor
- Scroll position indicator
- Highlighted search results in minimap
- Git change indicators

### S. Welcome / Start Page
- Recent projects
- New project templates
- Learning resources
- What's new
- Quick actions

### T. Accessibility
- VoiceOver support
- Keyboard navigation for everything
- High contrast mode
- Reduced motion
- Dynamic type

---

## SUMMARY

| Category | Have | Missing Sub-features | Missing Top-level |
|----------|------|---------------------|-------------------|
| Core Modes | 12 | ~200 | 0 |
| Shell UI | 6 | ~50 | 5 (Search, Debug, Problems, Workspace, Welcome) |
| Providers | 4 (ACP) | ~40 | 10+ (GitHub, Sentry, Slack, DB connectors, etc.) |
| AI Features | Basic chat | ~30 | 3 (Autocomplete, Inline edit, Refactoring) |
| Dev Tools | Git adapter | ~40 | 4 (Containers, Packages, HTTP client, Snippets) |
| Platform | Basic app | ~30 | 3 (Accessibility, Collaboration, Extensions) |

**Total: ~400 individual features needed for parity with modern IDEs + agent capabilities.**
