# project_status

A dashboard for tracking the status of multiple Git repositories. It scans a directory of repos, collects git/CI/PR/release information, and generates a self-contained HTML report.

## What it does

`repo-report.fsx` is an F# script that:

1. Scans a directory for git repositories
2. For each repo collects:
   - Uncommitted file count
   - Current branch and last commit date
   - Push status (ahead/behind upstream)
   - Open pull requests (via `gh`)
   - CI check status with failure logs (via `gh`)
   - Latest GitHub release
3. Optionally fetches open community PRs and issues filed by external contributors against a set of GitHub owners
4. Writes a self-contained tabbed HTML report (`repo-report.html`)

## Requirements

- [.NET SDK](https://dotnet.microsoft.com/download) (for `dotnet fsi`)
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated (`gh auth login`)

## Running

```bash
dotnet fsi repo-report.fsx
```

The report is written to `repo-report.html` in the same directory as the script (or to `REPORT_OUTPUT_PATH` if set).

## Configuration (environment variables)

All personal/environment-specific values are configured via environment variables. No code changes are needed to run against a different machine or organisation.

| Variable | Default | Description |
|---|---|---|
| `REPO_SCAN_DIR` | Parent directory of the script | Directory to scan for git repositories |
| `REPORT_OUTPUT_PATH` | `<script-dir>/repo-report.html` | Where to write the HTML report |
| `GITHUB_OWNERS` | _(empty — community tabs disabled)_ | Comma-separated GitHub owners/orgs to search for community PRs and issues (e.g. `MyOrg,MyOtherOrg`) |
| `GITHUB_EXCLUDE_AUTHOR` | _(none)_ | Lowercase GitHub username to exclude from community item results (typically your own account) |
| `GITHUB_EXCLUDE_REPO_DOMAIN` | _(none)_ | Substring to filter out repos from community results (e.g. `legacy-domain.io`) |

### Example

```bash
export REPO_SCAN_DIR=/workspace/repos
export REPORT_OUTPUT_PATH=/workspace/repo-report.html
export GITHUB_OWNERS=MyOrg,MyOtherOrg
export GITHUB_EXCLUDE_AUTHOR=myghusername
export GITHUB_EXCLUDE_REPO_DOMAIN=archived-domain.io

dotnet fsi repo-report.fsx
```

## Docker

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:9.0

RUN apt-get update && apt-get install -y curl git && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
      dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
      https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh

WORKDIR /app
COPY repo-report.fsx .

ENV REPO_SCAN_DIR=/repos
ENV REPORT_OUTPUT_PATH=/output/repo-report.html

CMD ["dotnet", "fsi", "repo-report.fsx"]
```

```bash
docker build -t repo-report .
docker run \
  -v /path/to/your/repos:/repos:ro \
  -v /path/to/output:/output \
  -e GITHUB_TOKEN=ghp_xxx \
  -e GITHUB_OWNERS=MyOrg \
  -e GITHUB_EXCLUDE_AUTHOR=myghusername \
  repo-report
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

`project_status_ui/` contains a Flutter application that will eventually display the same data via a live dashboard. See `project_status_ui/app/` for the Flutter app scaffold.

## Build commands

```bash
make build          # compile Flutter app
make test           # run tests with coverage
make lint           # run all linters
make fmt            # format all code
make ci             # lint + test + build
```
