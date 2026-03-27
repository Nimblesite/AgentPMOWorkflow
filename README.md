# Agent PMO Workflow

Stop watching one agent. Start running twenty. See [AGENT-PMO-WORKFLOW.md](AGENT-PMO-WORKFLOW.md) for the full vision.

## What's in here

### PMO Dashboard (`repo-report.fsx`)

An F# script that scans a directory of git repos and generates a self-contained HTML dashboard showing:

- Uncommitted file count, current branch, last commit date
- Push status (ahead/behind upstream)
- Open pull requests and CI check status (via `gh`)
- Latest GitHub release
- Community PRs and issues across GitHub owners

### Repo Standards Enforcement (`enforce-repo-standards/` + `templates/`)

Portfolio-wide standards toolkit. Provides templates, linter configs, CI workflows, devcontainer definitions, and a Claude skill to apply consistent standards across all repos. Every repo gets the same build interface, same CI pipeline, same quality gates.

The authoritative spec is [REPO-STANDARDS-SPEC.md](REPO-STANDARDS-SPEC.md).

## Requirements

- [.NET SDK](https://dotnet.microsoft.com/download) (for `dotnet fsi`)
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated (`gh auth login`)

## Running the dashboard

```bash
dotnet fsi repo-report.fsx
```

The report is written to `repo-report.html` (or to `REPORT_OUTPUT_PATH` if set).

## Installing the enforce-repo-standards skill

```bash
make install-skill
```

This symlinks `enforce-repo-standards` into `~/.claude/skills/` so `/enforce-repo-standards` is available in any Claude Code session.

## Configuration (environment variables)

| Variable | Default | Description |
|---|---|---|
| `REPO_SCAN_DIR` | Parent directory of the script | Directory to scan for git repos |
| `REPORT_OUTPUT_PATH` | `<script-dir>/repo-report.html` | Where to write the HTML report |
| `GITHUB_OWNERS` | _(empty)_ | Comma-separated GitHub owners/orgs for community PRs/issues |
| `GITHUB_EXCLUDE_AUTHOR` | _(none)_ | GitHub username to exclude from community results |
| `GITHUB_EXCLUDE_REPO_DOMAIN` | _(none)_ | Substring to filter out repos from community results |

## Docker

```bash
cp .env.example .env
# Edit .env with your GITHUB_TOKEN and GITHUB_OWNERS
docker compose up -d
docker compose logs -f scheduler
```

## launchd polling (macOS)

A launchd agent can run the report on a 180-second interval:

```bash
# Check status
launchctl list | grep repo-report

# Reload after changes
launchctl unload ~/Library/LaunchAgents/com.christianfindlay.repo-report.plist
launchctl load  ~/Library/LaunchAgents/com.christianfindlay.repo-report.plist

# Run once manually
dotnet fsi repo-report.fsx
```

## Tests

```bash
dotnet fsi test-report.fsx
```

## Flutter UI (WIP)

`project_status_ui/` contains a Flutter application that will eventually display the same data via a live dashboard.

## Build commands

```bash
make build            # compile Flutter app
make test             # run tests with coverage
make lint             # run all linters
make fmt              # format all code
make ci               # lint + test + build
make install-skill    # symlink enforce-repo-standards globally
make uninstall-skill  # remove the global skill symlink
```
