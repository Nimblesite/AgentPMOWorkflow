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

- [ ] **Phase 1: Project Setup & Core Library**
  - [ ] Initialize monorepo structure
  - [ ] Set up core package
  - [ ] Implement `LaunchdJob` model
  - [ ] Implement `PlistService`
  - [ ] Implement `LaunchdService` — listJobs + getJobDetail
  - [ ] Implement `LaunchdService` — action methods + getLog
  - [ ] Unit tests for core
- [ ] **Phase 2: CLI**
  - [ ] Set up cli package and entry point
  - [ ] `list` command with table output and filters
  - [ ] `info` command
  - [ ] `log` command with follow mode
  - [ ] Action commands (load/unload/start/stop/enable/disable)
  - [ ] `edit` and `create` commands
  - [ ] End-to-end CLI testing
- [ ] **Phase 3: Flutter App — Scaffold & Theme**
  - [ ] Set up app package with macOS target
  - [ ] Dark theme implementation
  - [ ] Sidebar widget
  - [ ] Toolbar widget
- [ ] **Phase 4: Flutter App — Job List**
  - [ ] Custom sortable job table
  - [ ] Status badge widget
  - [ ] Filter and search wiring
  - [ ] Auto-refresh
  - [ ] Right-click context menu
- [ ] **Phase 5: Flutter App — Detail Panel**
  - [ ] Detail panel layout
  - [ ] Log viewer widget
  - [ ] Plist XML viewer
  - [ ] Action buttons wired up
  - [ ] Confirmation dialogs
  - [ ] Read-only mode for system jobs
- [ ] **Phase 6: Create & Edit**
  - [ ] Create New Job dialog
  - [ ] Inline plist editor
  - [ ] Auto-load after creation
- [ ] **Phase 7: Polish & Release**
  - [ ] Permissions handling (sudo, admin badges)
  - [ ] Error handling and edge cases
  - [ ] Signing / notarization
  - [ ] README and release packaging
