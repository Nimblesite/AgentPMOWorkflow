# Launchpad - macOS launchd Manager

A native macOS app (Flutter) and CLI for viewing, editing, and managing launchd jobs.
Replaces the need for LaunchControl ($16) or Lingon X ($15).

## What is launchd?

launchd is the macOS service management framework. Jobs are defined as `.plist` files in:

| Location | Scope | Requires root |
|----------|-------|---------------|
| `~/Library/LaunchAgents/` | Current user agents | No |
| `/Library/LaunchAgents/` | All users agents | Yes |
| `/Library/LaunchDaemons/` | System daemons | Yes |
| `/System/Library/LaunchAgents/` | Apple agents (read-only) | SIP protected |
| `/System/Library/LaunchDaemons/` | Apple daemons (read-only) | SIP protected |

## Core Package (`packages/core`)

Shared Dart library for both CLI and Flutter app.

### Models

**LaunchdJob**
- `label` (String) - unique job identifier
- `path` (String) - plist file path
- `scope` (enum: userAgent, globalAgent, globalDaemon, systemAgent, systemDaemon)
- `isLoaded` (bool) - currently loaded in launchd
- `pid` (int?) - process ID if running, null if not
- `lastExitStatus` (int?) - last exit code
- `program` (String?) - executable path
- `programArguments` (List<String>?) - command + args
- `startInterval` (int?) - run every N seconds
- `startCalendarInterval` (Map?) - cron-like schedule
- `runAtLoad` (bool)
- `keepAlive` (bool/Map?)
- `standardOutPath` (String?)
- `standardErrorPath` (String?)
- `workingDirectory` (String?)
- `environmentVariables` (Map<String, String>?)
- `disabled` (bool)
- `plistContent` (String) - raw plist XML

### Services

**LaunchdService**
- `listJobs()` -> `List<LaunchdJob>` - List all jobs from all plist directories + merge runtime state from `launchctl list`
- `loadJob(String plistPath)` - Load a job
- `unloadJob(String plistPath)` - Unload a job
- `startJob(String label)` - Start (kick) a job
- `stopJob(String label)` - Stop a running job
- `enableJob(String plistPath)` - Remove disabled flag
- `disableJob(String plistPath)` - Set disabled flag
- `getJobDetail(String label)` -> `LaunchdJob` - Full details for one job
- `getLog(String path, {int lines})` -> `String` - Read stdout/stderr log tail

**PlistService**
- `parse(String path)` -> `Map` - Parse a plist file to a Map
- `read(String path)` -> `String` - Read raw plist content
- `write(String path, String content)` - Write plist content
- `validate(String content)` -> `List<String>` - Validate plist structure, return errors
- `createTemplate(String label)` -> `String` - Generate a blank plist template

## CLI (`packages/cli`)

```
launchpad                     # List all jobs (table view)
launchpad list                # Same as above
launchpad list --scope user   # Filter: user, global, system, all (default: all)
launchpad list --loaded       # Only loaded jobs
launchpad list --running      # Only currently running jobs
launchpad list --filter <text># Filter by label

launchpad info <label>        # Show full details for a job
launchpad log <label>         # Tail the stdout/stderr logs
launchpad log <label> -f      # Follow log output

launchpad load <plist-path>   # Load a job
launchpad unload <plist-path> # Unload a job
launchpad start <label>       # Kick/start a job
launchpad stop <label>        # Stop a running job
launchpad enable <label>      # Enable a disabled job
launchpad disable <label>     # Disable a job

launchpad edit <label>        # Open plist in $EDITOR
launchpad create              # Interactive: create a new job plist
```

### Table columns
Label | Status | PID | Last Exit | Interval | Plist Path

### Color coding
- Status: green=loaded+idle, blue=running, red=error (non-zero exit), dim=not loaded
- PID: shown when running, dash when not
- Last Exit: green=0, red=non-zero, dash=never run

## Flutter App (`packages/app`)

### Design Language
- Dark theme (Linear/Raycast aesthetic)
- Background: #0f1119
- Surface: #1a1d2e
- Borders: #2a2d3e
- Accent: #6c63ff
- Success: #2dd4a8
- Warning: #f5a623
- Error: #ff4757
- Text: #e8eaf6
- Muted: #6b7394
- No default Material widgets for data display
- Custom table, pills, badges
- System font (SF Pro via default), monospace for labels/paths

### Layout

```
+--sidebar--+------------------main-area------------------+
|           |  toolbar: search, filter, scope dropdown     |
| Scopes    |----------------------------------------------|
|  User (n) |                                              |
|  Global(n)|  Job list table                              |
|  System(n)|  - Label                                     |
|           |  - Status (badge)                            |
| --------- |  - PID                                       |
| Filters   |  - Schedule (interval or calendar)           |
|  All      |  - Last Exit (badge)                         |
|  Loaded   |  - Plist path                                |
|  Running  |                                              |
|  Errored  |  Click row -> detail panel slides in         |
|           |                                              |
+-----------+----------------------------------------------+
```

### Detail Panel (slides in from right, replaces table or splits view)

```
+--detail-panel------------------------------------------+
| [Back]  com.example.myjob                    [actions] |
|                                                         |
| Status: Loaded (idle)        PID: -                     |
| Last Exit: 0                 Scope: User Agent          |
|                                                         |
| --- Schedule ---                                        |
| StartInterval: 300 (every 5 min)                        |
| RunAtLoad: true                                         |
|                                                         |
| --- Command ---                                         |
| /usr/bin/python3 /path/to/script.py --flag              |
|                                                         |
| --- Paths ---                                           |
| Working Dir: /Users/foo                                 |
| Stdout: /tmp/myjob.log                                 |
| Stderr: /tmp/myjob.err                                 |
|                                                         |
| --- Environment ---                                     |
| PATH=/usr/bin:/usr/local/bin                            |
| HOME=/Users/foo                                         |
|                                                         |
| --- Log Preview ---                                     |
| [last 50 lines of stdout log, monospace, scrollable]    |
|                                                         |
| --- Raw Plist ---                                       |
| [collapsible XML viewer with syntax highlighting]       |
|                                                         |
| [Load] [Unload] [Start] [Stop] [Edit] [Delete]         |
+---------------------------------------------------------+
```

### Actions (toolbar buttons in detail view)
- **Load/Unload** toggle - loads or unloads the job
- **Start** - kicks the job to run now
- **Stop** - stops a running job
- **Edit** - opens an inline plist editor (editable text field with XML)
- **Delete** - removes the plist file (with confirmation dialog)
- All destructive actions require confirmation
- System jobs (under /System/) are read-only - hide edit/delete buttons

### Job List Features
- Sortable columns (click header)
- Search/filter by label (instant, as-you-type)
- Scope filter in sidebar
- Status filter in sidebar
- Auto-refresh every 10 seconds (configurable)
- Show total count per scope in sidebar
- Right-click context menu with quick actions (load/unload/start/stop)

### Create New Job Dialog
- Form fields for: label, program/arguments, interval, runAtLoad, working dir, stdout/stderr paths
- Preview generated plist XML
- Save to ~/Library/LaunchAgents/ by default
- Auto-load after creation

## File Structure

```
launchpad/
  SPEC.md
  packages/
    core/
      lib/
        core.dart
        src/
          models/
            launchd_job.dart
          services/
            launchd_service.dart
            plist_service.dart
    cli/
      bin/
        launchpad.dart
    app/
      lib/
        main.dart
        theme.dart
        screens/
          dashboard.dart
        widgets/
          job_table.dart
          job_detail.dart
          sidebar.dart
          status_badge.dart
          create_job_dialog.dart
          log_viewer.dart
          plist_editor.dart
```

## Permissions & Security
- User agents: no special permissions needed
- Global agents/daemons: may need sudo - prompt user or show "requires admin" badge
- System agents/daemons: read-only, cannot modify (SIP protected)
- App sandbox: will need to be unsigned/unsandboxed to access launchctl and plist files
- Never delete system plists
- Always confirm destructive actions
