# Agent PMO Workflow — Agent Instructions

> Read this entire file before making changes.

## Project Overview

Agent PMO Workflow — a system for running 20+ AI agents across multiple projects simultaneously. See `AGENT-PMO-WORKFLOW.md` for the full vision. Two components:

1. **PMO Dashboard** (`dashboard/`) — F# script that scans repos under `~/Documents/Code/` and generates an HTML status dashboard
2. **Repo Standards Enforcement** (`agent-pmo-skill/`) — portfolio-wide templates, linter configs, CI workflows, and a skill to apply consistent standards to any repo

## What This Repo Contains

- **Docs and specs** — markdown files defining the system (`AGENT-PMO-WORKFLOW.md`, `docs/specs/REPO-STANDARDS-SPEC.md`)
- **One F# script** — `dashboard/repo-report.fsx` generates the HTML dashboard
- **Playwright E2E tests** — `dashboard/tests/repo-report.spec.js` tests the generated HTML
- **F# tests** — `dashboard/test-report.fsx` unit tests + integration test (generates report from mock repos)
- **An agent skill** — `agent-pmo-skill/SKILL.md` applies standards to other repos
- **Templates** — `agent-pmo-skill/templates/` contains configs, workflows, and instruction files for target repos

This is NOT an application codebase. Most work here is editing docs, specs, templates, and the dashboard script.

## Rules For This Workspace

- **DO NOT use git commands.** CI and GitHub Actions handle git.
- **Do not modify tests.** Fix the code until tests pass.
- **Run tests after changes.** `make test` — keep fixing until green.
- **Docs are the source of truth.** Specs define behavior. Plans define how to achieve goals. All plan docs must have a TODO checklist.
- **Templates are starting points, not copy-paste targets.** See `docs/specs/REPO-STANDARDS-SPEC.md` §16.2 for the customization rule.

## Portfolio-Wide Coding Standards

Hard rules, testing rules, and language-specific rules for target repos live in the templates and specs — not here:

- **Template AGENTS.md for target repos:** `agent-pmo-skill/templates/AGENTS.md`
- **Authoritative spec:** `docs/specs/REPO-STANDARDS-SPEC.md`

When editing those files, that's where coding standards belong. This root AGENTS.md is only for working in this workspace.

## Too Many Cooks (Multi-Agent Coordination)

If the TMC server is available:
1. Register immediately: descriptive name, intent, files you will touch
2. Before editing any file: lock it via TMC
3. Broadcast your plan before starting work
4. Check messages every few minutes
5. Release locks immediately when done
6. Never edit a locked file — wait or find another approach

## Critical Reference Docs — Agent Instructions & Skills

These are the authoritative docs for configuring AI coding agents. When working on templates or the agent-pmo skill, you MUST consult the docs relevant to the target agent.

### Agent Instruction File Docs

| Agent | Instruction file docs |
|---|---|
| Claude Code | https://code.claude.com/docs/en/memory#claude-md-files |
| OpenAI Codex | https://developers.openai.com/codex/guides/agents-md |
| GitHub Copilot | https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions |
| Cline / Roo | https://docs.cline.bot/customization/cline-rules |
| OpenCode | https://opencode.ai/docs/rules/ |

### Agent Skill Docs

| Agent | Skill docs |
|---|---|
| Claude Code | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview |
| OpenAI Codex | https://developers.openai.com/codex/skills |
| Cline / Roo | https://docs.cline.bot/customization/skills |
| OpenCode | https://opencode.ai/docs/skills/ |
| GitHub Copilot | https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills |

## Build Commands

```bash
make build            # generate the HTML dashboard report
make test             # run all tests (F# + Playwright E2E)
make test-fsharp      # run F# tests (alias for test-mock)
make test-mock        # run F# mock fixture tests (generates report for E2E)
make test-local       # generate report from config.json + run Playwright E2E
make test-e2e         # run Playwright E2E tests only
make lint             # validate Playwright test configuration
make fmt              # format code (no-op for F# scripts)
make fmt-check        # check formatting (no-op for F# scripts)
make clean            # remove test artifacts
make check            # lint + test
make ci               # lint + test + build
make install-skill-claude   # install agent-pmo skill for Claude Code
make uninstall-skill-claude # remove the agent-pmo skill
make help             # list all available targets
```

## PMO Dashboard (`dashboard/`)

### How it works

1. `dashboard/repo-report.fsx` scans `~/Documents/Code/` for git repositories
2. For each repo it collects: uncommitted file count, current branch, last commit date, push status (ahead/behind), open PRs (via `gh`), CI status (via `gh`), and latest GitHub release
3. Generates a self-contained HTML report at `dashboard/repo-report.html`
4. Logs stdout to `dashboard/repo-report.log`, stderr (debug) to `dashboard/repo-report-debug.log`

### Critical: PR detection

**Open PRs must always be shown.** The PR lookup first checks for a PR matching the current branch (`--head <branch>`). If none is found, it falls back to listing any open PR in the repo. This is critical because the local branch may differ from the PR branch. The "PR Branch" column shows which branch the PR is actually from.

### launchd polling (runs every 3 minutes)

- **Plist:** `~/Library/LaunchAgents/com.christianfindlay.repo-report.plist`
- **Command:** `zsh -l -c "MAX_REPOS=30 dotnet fsi dashboard/repo-report.fsx"`
- **Interval:** 300 seconds
- **RunAtLoad:** true

```bash
launchctl list | grep repo-report                # check status
launchctl unload ~/Library/LaunchAgents/com.christianfindlay.repo-report.plist  # stop
launchctl load ~/Library/LaunchAgents/com.christianfindlay.repo-report.plist    # start
dotnet fsi dashboard/repo-report.fsx             # run manually
```

## Architecture

```
AgentPMOWorkflow/
├── .devcontainer/                 # Dev container config
├── .github/
│   ├── pull_request_template.md
│   └── workflows/
│       ├── ci.yml                 # CI pipeline (F# tests + Playwright E2E)
│       └── release.yml            # Tag-triggered releases
├── dashboard/                     # PMO Dashboard
│   ├── repo-report.fsx            # F# report generator
│   ├── test-report.fsx            # F# unit + integration tests
│   ├── config.example.json        # Config template
│   ├── package.json               # Playwright deps
│   ├── playwright.config.js
│   ├── README.md
│   └── tests/
│       └── repo-report.spec.js    # Playwright E2E tests
├── agent-pmo-skill/               # Agent-agnostic skill for standards enforcement
│   ├── SKILL.md                   # The skill definition
│   └── templates/                 # Portfolio-wide templates (agent-agnostic)
│       ├── AGENTS.md              # Canonical template (all rules, agent-neutral)
│       ├── CLAUDE.md              # Pointer to AGENTS.md (with Claude-specific skill links)
│       ├── Makefile
│       ├── .github/
│       │   ├── common-repo-settings.md
│       │   ├── copilot-instructions.md
│       │   ├── pull_request_template.md
│       │   └── workflows/         # CI/CD templates
│       ├── linting/               # Linter configs per language
│       ├── coverage/              # Coverage configs
│       ├── devcontainer/          # Devcontainer configs per language
│       ├── gitignore/             # Gitignores per language
│       └── skills/                # Skill templates (agent-agnostic, convert per target)
├── docs/
│   ├── plans/
│   └── specs/
│       └── REPO-STANDARDS-SPEC.md # Authoritative standards spec
├── .env.example
├── AGENT-PMO-WORKFLOW.md          # Vision doc
├── AGENTS.md                      # THIS FILE
├── CLAUDE.md                      # Pointer to AGENTS.md
├── Dockerfile.dev                 # Dev environment container
├── compose.yaml                   # Dev environment orchestration
├── Makefile
└── README.md
```
