# Agent PMO Workflow — Claude Instructions

> Read this entire file before writing any code.
> These rules are NON-NEGOTIABLE. Violations will be rejected in review.

## Project Overview

Agent PMO Workflow — a unified system for running 20+ AI agents across multiple projects simultaneously. Two components in one repo:

1. **PMO Dashboard** (`repo-report.fsx`) — F# script that scans repos and generates an HTML status dashboard
2. **Repo Standards Enforcement** (`enforce-repo-standards/` + `templates/`) — portfolio-wide templates, linter configs, CI workflows, and a Claude skill to apply consistent standards to any repo

See `AGENT-PMO-WORKFLOW.md` for the full vision.

**Primary language(s):** Dart/Flutter, F#
**Build command:** `make ci`
**Test command:** `make test`
**Lint command:** `make lint`

## Too Many Cooks (Multi-Agent Coordination)

If the TMC server is available:
1. Register immediately: descriptive name, intent, files you will touch
2. Before editing any file: lock it via TMC
3. Broadcast your plan before starting work
4. Check messages every few minutes
5. Release locks immediately when done
6. Never edit a locked file — wait or find another approach

## Hard Rules — Universal (no exceptions)

- **DO NOT use git commands.** No `git add`, `git commit`, `git push`, `git checkout`, `git merge`, `git rebase`, or any other git command. CI and GitHub Actions handle git.
- **ZERO DUPLICATION.** Before writing any code, search the codebase for existing implementations. Move code, don't copy it.
- **NO THROWING EXCEPTIONS.** Return `Result<T,E>`, `Option<T>`, or the language equivalent. Exceptions are only for unrecoverable bugs (panic-level).
- **NO REGEX on structured data.** Never parse JSON, YAML, TOML, code, or any structured format with regex. Use proper parsers, AST tools, or library functions.
- **NO PLACEHOLDERS.** If something isn't implemented, leave a loud compilation error (`todo!()`, `raise NotImplementedError`, `failwith "TODO"`). Never write code that silently does nothing.
- **Functions < 20 lines.** Refactor aggressively. If a function exceeds 20 lines, split it.
- **Files < 500 lines.** If a file exceeds 500 lines, extract modules.
- **100% test coverage is the goal.** Never delete or skip tests. Never remove assertions.
- **Prefer E2E/integration tests.** Unit tests are acceptable only for pure transformation functions.
- **Heavy logging everywhere.** Use structured logging. Log at entry/exit of all significant operations. Use appropriate levels (error, warn, info, debug).
- **No suppressing linter warnings.** Fix the code, not the linter.
- **When making changes, you are not allowed to modify the tests.**
- **You must run the tests after making changes and you must keep fixing until the tests pass.**

## Hard Rules — Language-Specific

### Dart/Flutter
- No `late` keyword — it hides null-safety violations
- No `!` (bang operator) — use `?` and handle the null case
- No `dynamic` — use proper types or generics
- No `as Type` casts — use `is` checks and smart casts
- No `.then()` on futures — use `async`/`await`
- State management: SUDF (Single Unidirectional Data Flow) only
- Tests: Widget tests for UI, unit tests for business logic, integration tests for flows

## Testing Rules

- **Never delete a failing test.** Fix the code or fix the test expectation — never delete.
- **Never skip a test** (`@pytest.mark.skip`, `xit`, `test.skip`, `#[ignore]`) without a ticket number and expiry date in the skip reason.
- **Assertions must be specific.** `assert True` or `assert.ok(true)` without a condition is illegal.
- **No try/catch in tests** that swallows the exception and asserts success.
- **Tests must be deterministic.** No sleep(), no relying on timing, no random state.
- **E2E tests: black-box only.** Only interact via public APIs, UI commands, or CLI. Never call internal methods or manipulate internal state from a test.

## Skills

Follow these carefully

https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf

## Build Commands (exact)

```bash
make build            # compile everything
make test             # run tests with coverage
make lint             # run all linters
make fmt              # format all code
make fmt-check        # check formatting (CI uses this)
make clean            # remove build artifacts
make check            # lint + test (pre-commit)
make ci               # lint + test + build (full CI simulation)
make coverage         # generate and open coverage report
make coverage-check   # assert coverage thresholds
make install-skill    # symlink enforce-repo-standards into ~/.claude/skills/
make uninstall-skill  # remove the global skill symlink
```

## Repo Report Dashboard

The core of this project is an F# script (`repo-report.fsx`) that scans all git repos under `~/Documents/Code/`, gathers status info (uncommitted changes, branch, push status, open PRs, CI status), and generates an HTML dashboard (`repo-report.html`).

### How it works

1. `repo-report.fsx` scans `~/Documents/Code/` for git repositories
2. For each repo it collects: uncommitted file count, current branch, last commit date, push status (ahead/behind), open PRs (via `gh`), CI status (via `gh`), and latest GitHub release

### Critical: PR detection

**Open PRs must always be shown.** The PR lookup first checks for a PR matching the current branch (`--head <branch>`). If none is found, it falls back to listing any open PR in the repo. This is critical because the local branch may differ from the PR branch (e.g., on `TestExplorer` locally while the PR is from `Stuff2`). The "PR Branch" column shows which branch the PR is actually from.
3. Generates a self-contained HTML report at `repo-report.html`
4. Logs stdout to `repo-report.log`, stderr (debug) to `repo-report-debug.log`

### launchd polling (runs every 3 minutes)

A macOS launchd agent polls the report on a 180-second interval:

- **Plist:** `~/Library/LaunchAgents/com.christianfindlay.repo-report.plist`
- **Command:** `dotnet fsi repo-report.fsx`
- **Interval:** 180 seconds (3 minutes)
- **RunAtLoad:** true (starts on login)
- **Stdout log:** `repo-report.log`
- **Stderr log:** `repo-report-debug.log`

### launchd management commands

```bash
# Check if loaded and running
launchctl list | grep repo-report

# Unload (stop)
launchctl unload ~/Library/LaunchAgents/com.christianfindlay.repo-report.plist

# Load (start)
launchctl load ~/Library/LaunchAgents/com.christianfindlay.repo-report.plist

# Run manually
dotnet fsi repo-report.fsx
```

### Test files

- `repo-report-tests.fsx` — tests for the report generation logic
- `test-report.fsx` — test runner script

## Architecture

```
project_status/
├── .claude/
│   └── skills/                    # Project-specific Claude skills
├── .devcontainer/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   └── release.yml
│   └── pull_request_template.md
├── project_status_ui/             # Flutter app (WIP)
│   ├── app/                       # Flutter app scaffold
│   ├── cli/                       # CLI tool
│   └── core/                      # Shared core library
├── enforce-repo-standards/        # Global Claude skill for standards enforcement
│   ├── SKILL.md
│   └── templates/                 # Portfolio-wide repo templates
│       ├── CLAUDE.md              # Template for other repos
│       ├── Makefile               # Universal Makefile template
│       ├── .github/               # CI/CD workflow templates
│       ├── devcontainer/          # Language-specific devcontainer configs
│       ├── gitignore/             # Language-specific gitignores
│       ├── linting/               # Language-specific linter configs
│       ├── coverage/              # Coverage config templates
│       └── skills/                # Standard skill templates
├── repo-report.fsx                # F# report generator script
├── repo-report-tests.fsx          # Tests for report logic
├── test-report.fsx                # Test runner
├── AGENT-PMO-WORKFLOW.md          # Vision doc
├── REPO-STANDARDS-SPEC.md         # Authoritative standards spec
├── Dockerfile                     # Docker dev environment
├── docker-compose.yml
├── .editorconfig
├── .gitignore
├── CLAUDE.md
└── Makefile
```
