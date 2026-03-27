# PMO Dashboard

F# script that scans git repos and generates an HTML status report.

## Prerequisites

You need all of the following installed and working before the script will do anything useful:

| Prerequisite | Why | Install |
|---|---|---|
| **.NET SDK** (6.0+) | Runs the F# script (`dotnet fsi`) | [dotnet.microsoft.com](https://dotnet.microsoft.com/download) |
| **Git** | Reads repo status (branch, commits, push state) | `brew install git` or [git-scm.com](https://git-scm.com) |
| **GitHub CLI (`gh`)** | Fetches open PRs, CI status, releases, and community issues | `brew install gh` |

### GitHub CLI authentication (required)

The script calls `gh pr list`, `gh release view`, `gh search`, and other commands that **require an authenticated session**. If you skip this step, every PR/CI/release column will be blank.

```bash
gh auth login          # follow the prompts — browser OAuth is easiest
gh auth status         # confirm you are logged in
```

### For running E2E tests (optional)

| Prerequisite | Why | Install |
|---|---|---|
| **Node.js** (18+) | Runs Playwright tests | [nodejs.org](https://nodejs.org) |
| **Playwright browsers** | Headless browser for E2E tests | `npx playwright install` (after `npm install`) |

## Setup

1. Copy `config.example.json` to `config.json` and fill in your values.
2. Run: `dotnet fsi repo-report.fsx`

## Config

| Key | Required | Description |
|-----|----------|-------------|
| `scanDir` | yes | Absolute path to the directory containing your git repos |
| `githubOwners` | yes | Comma-separated GitHub usernames/orgs for community PR/issue search |
| `excludeAuthor` | no | GitHub username to exclude from community results (e.g. bot accounts) |
| `excludeRepoDomain` | no | Domain substring to exclude repos from community results |

Environment variables (`REPO_SCAN_DIR`, `GITHUB_OWNERS`, etc.) override config.json values. See the Docker setup in the root `docker-compose.yml` for the full env var list.

`config.json` is gitignored — it contains machine-specific paths.

## launchd (macOS auto-refresh)

A launchd agent runs the script every 3 minutes:

```bash
# Load
launchctl load ~/Library/LaunchAgents/com.christianfindlay.repo-report.plist

# Unload
launchctl unload ~/Library/LaunchAgents/com.christianfindlay.repo-report.plist

# Check status
launchctl list | grep repo-report
```

The plist must point to `dashboard/repo-report.fsx` (not the root).

## Tests

- `repo-report-tests.fsx` — F# unit tests for report logic
- `test-report.fsx` — F# test runner
- `tests/repo-report.spec.js` — Playwright E2E tests for the generated HTML
