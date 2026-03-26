# Launchpad - Implementation Plan

## Phase 1: Project Setup & Core Library
1. Initialize monorepo structure (`packages/core`, `packages/cli`, `packages/app`)
2. Set up `core` package with pubspec, exports, and directory structure
3. Implement `LaunchdJob` model with all fields and scope enum
4. Implement `PlistService` — parse, read, write, validate, createTemplate
5. Implement `LaunchdService` — listJobs, getJobDetail (merge plist data with `launchctl list` output)
6. Implement remaining `LaunchdService` methods — load, unload, start, stop, enable, disable, getLog
7. Write unit tests for models and services (mock launchctl output)

## Phase 2: CLI
8. Set up `cli` package with `args` dependency and entry point
9. Implement `list` command with table output, color coding, and filters (`--scope`, `--loaded`, `--running`, `--filter`)
10. Implement `info <label>` command — full job detail display
11. Implement `log <label>` command with `-f` follow mode
12. Implement action commands — `load`, `unload`, `start`, `stop`, `enable`, `disable`
13. Implement `edit <label>` (open in $EDITOR) and `create` (interactive new job wizard)
14. Test CLI end-to-end against real launchd on macOS

## Phase 3: Flutter App — Scaffold & Theme
15. Set up `app` package with Flutter macOS target
16. Implement dark theme (`theme.dart`) with spec color palette and typography
17. Build sidebar widget — scope sections with counts, status filters
18. Build toolbar — search field, scope dropdown

## Phase 4: Flutter App — Job List & Table
19. Build custom job table widget with sortable columns (Label, Status, PID, Schedule, Last Exit, Path)
20. Implement `StatusBadge` widget with spec color coding
21. Wire up sidebar filters and search to table data
22. Add auto-refresh (default 10s) with configurable interval
23. Add right-click context menu with quick actions

## Phase 5: Flutter App — Detail Panel & Actions
24. Build detail panel layout (slides in from right) with all info sections
25. Implement log viewer widget — last 50 lines, monospace, scrollable
26. Implement raw plist viewer — collapsible XML with syntax highlighting
27. Wire up action buttons — Load/Unload, Start, Stop, Edit, Delete
28. Add confirmation dialogs for destructive actions
29. Hide edit/delete for system jobs (SIP-protected paths)

## Phase 6: Flutter App — Create & Edit
30. Build Create New Job dialog with form fields and plist XML preview
31. Implement inline plist editor (editable text field with XML)
32. Auto-load job after creation, save to `~/Library/LaunchAgents/` by default

## Phase 7: Polish & Release
33. Handle permissions — sudo prompts for global agents/daemons, "requires admin" badges
34. Error handling and edge cases (missing logs, corrupt plists, SIP-protected paths)
35. App signing / notarization decisions (unsandboxed requirement)
36. README, screenshots, and release packaging

---

## TODO

- [x] **Phase 1: Project Setup & Core Library**
  - [x] Initialize monorepo structure
  - [x] Set up core package
  - [x] Implement `LaunchdJob` model
  - [x] Implement `PlistService`
  - [x] Implement `LaunchdService` — listJobs + getJobDetail
  - [x] Implement `LaunchdService` — action methods + getLog
  - [x] Unit tests for core (19/19 passing)
- [x] **Phase 2: CLI**
  - [x] Set up cli package and entry point
  - [x] `list` command with table output and filters
  - [x] `info` command
  - [x] `log` command with follow mode
  - [x] Action commands (load/unload/start/stop/enable/disable)
  - [x] `edit` and `create` commands
  - [x] End-to-end CLI testing (compiled native binary, tested against real launchd)
- [x] **Phase 3: Flutter App — Scaffold & Theme**
  - [x] Set up app package with macOS target
  - [x] Dark theme implementation
  - [x] Sidebar widget
  - [x] Toolbar widget
- [x] **Phase 4: Flutter App — Job List**
  - [x] Custom sortable job table
  - [x] Status badge widget
  - [x] Filter and search wiring
  - [x] Auto-refresh (10s)
  - [x] Right-click context menu
- [x] **Phase 5: Flutter App — Detail Panel**
  - [x] Detail panel layout
  - [x] Log viewer widget (stdout/stderr tabs)
  - [x] Plist XML viewer (collapsible)
  - [x] Action buttons wired up
  - [x] Confirmation dialogs
  - [x] Read-only mode for system jobs
- [x] **Phase 6: Create & Edit**
  - [x] Create New Job dialog (with live XML preview)
  - [x] Inline plist editor (with validate + save)
  - [x] Auto-load after creation
- [ ] **Phase 7: Polish & Release**
  - [x] Permissions handling (scope badges, system job read-only)
  - [x] Error handling and edge cases
  - [ ] Signing / notarization
  - [ ] README and release packaging
