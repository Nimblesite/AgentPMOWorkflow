# Repository Standards Specification

> **Machine-readable standard for the `agent-pmo` skill.**
> This document defines the exact configuration files, targets, job names, and templates
> that every repo in this portfolio must conform to. A skill reads this document to
> MINT a new repo or REMEDIATE an existing one.

Generated: 2026-03-26
Source: Analysis of 20 repos from `project_status/repo-report.html`

---

## 0. Design Principles

1. **Docs are the source of truth.** The specs folder holds docs that SPECIFY the behavior of the system. The plans folder holds docs that specify how to achieve some goal. All plan docs MUST have a TODO list with checkboxes at the bottom of the document. We use these instead of inbuilt agent TODO lists because it allows us to track TODOs across agents and sessions
2. **Templates are starting points, not copy-paste targets.** Every config file required by this spec
   has a template in [`templates/`](templates/). The skill uses these as a baseline but MUST customize
   them for the target repo — stripping irrelevant language sections, filling placeholders, and
   removing examples for tools/languages not present. See §16.2.
3. **Fail fast, fail loud.** Lint before test. Test before build. Coverage threshold blocks merge.
   Zero warnings allowed — all linters run in errors-as-warnings mode.
4. **No git in Claude sessions.** Skills and CLAUDE.md rules prohibit git commands.
   CI and GitHub Actions do the git work.
5. **Multi-language repos are the norm.** Standards are designed so each language
   adds its targets/jobs orthogonally without breaking the uniform interface.
6. **Spec IDs are hierarchical descriptive slugs, NEVER numbered.** Every spec section MUST have a
   unique ID in the format `[GROUP-TOPIC]` or `[GROUP-TOPIC-DETAIL]`. IDs are uppercase, hyphen-separated,
   and MUST NOT contain sequential numbers.

   **Hierarchy rule:** The first word is the **group**. All spec sections sharing the same group MUST
   appear together in the document's table of contents. The group defines a logical category; the
   remaining words narrow the topic within that group. The hierarchy depth varies by repo — small
   repos may use two words (`[AUTH-LOGIN]`), most will use three (`[AUTH-TOKEN-VERIFY]`), and complex
   domains may use four (`[AUTH-OAUTH-REFRESH-FLOW]`). The hierarchy MUST mirror the spec document's
   heading structure.

   **Examples by group:**
   ```
   ## Authentication
   ### [AUTH-LOGIN] User login flow
   ### [AUTH-TOKEN-VERIFY] Token verification
   ### [AUTH-TOKEN-REFRESH] Token refresh
   ### [AUTH-OAUTH-CALLBACK] OAuth callback handling

   ## CI/CD
   ### [CI-TIMEOUT] Job timeout policy
   ### [CI-LINT] Lint job configuration
   ### [CI-COVERAGE] Coverage enforcement

   ## Linting
   ### [LINT-ESLINT] ESLint configuration
   ### [LINT-RUFF] Ruff configuration
   ### [LINT-CLIPPY] Clippy configuration
   ```

   - Good: `[AUTH-LOGIN]`, `[CI-TIMEOUT]`, `[LINT-ESLINT]`, `[AUTH-TOKEN-VERIFY]`, `[FEAT-DARK-MODE]`
   - Bad: `[SPEC-001]` (numbered), `[REQ-003]` (numbered), `[FEAT-AUTH-01]` (trailing number),
     `[TIMEOUT]` (no group — where does this belong?), `[CI-004]` (numbered, not descriptive)

   **Cross-referencing is mandatory.** All code, tests, and design documents that implement or relate
   to a spec section MUST reference its ID in a comment (e.g., `// Implements [AUTH-TOKEN-VERIFY]`,
   `# Tests [CI-TIMEOUT]`). This creates a traceable link from spec → code → tests. The `spec-check`
   skill enforces this by searching for spec ID references in code and test files.

   **Why no numbers:** Numbered IDs create merge conflicts, encourage meaningless sequential assignment,
   and tell the reader nothing about what the spec section covers. Descriptive slugs are self-documenting,
   naturally unique, and stable across refactors. The hierarchical grouping means you can grep for
   `[AUTH-` to find every authentication spec section, its implementing code, and its tests.

---

## 1. Universal Makefile Standard

Every repo MUST have a root `Makefile` with **exactly** these target names.
Language-specific work is delegated internally; the external interface never changes.

### 1.0 Cross-Platform Requirements (Linux, macOS, Windows)

Every Makefile MUST support Linux, macOS, and Windows. Add OS detection at the top:

```makefile
ifeq ($(OS),Windows_NT)
  SHELL := powershell.exe
  .SHELLFLAGS := -NoProfile -Command
  RM = Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  MKDIR = New-Item -ItemType Directory -Force
  HOME ?= $(USERPROFILE)
else
  RM = rm -rf
  MKDIR = mkdir -p
endif
```

**Rules:**
- Use `$(RM)` instead of `rm -rf` and `$(MKDIR)` instead of `mkdir -p`
- Use forward slashes for paths (works on all platforms)
- Tools like `dotnet`, `npm`/`npx`, `gh`, `cargo`, `go`, `flutter`, `dart`, `python`/`pip` are already cross-platform — no changes needed for commands that use them
- Where a command genuinely cannot work on Windows (e.g., `launchd`, `cron`, `chmod`, `ln -s`), provide both Unix and Windows targets:
  ```makefile
  ifeq ($(OS),Windows_NT)
  install-schedule: install-schedule-windows
  else
  install-schedule: install-schedule-unix
  endif
  ```
- Coverage check shell scripts that use `grep`/`awk` inline in Makefile recipes are Unix-only — this is acceptable because CI runs on Linux. For local Windows use, developers can run `make coverage-check` via WSL or Git Bash
- Some repos are inherently platform-specific (e.g., a macOS-only app). In those cases, document the limitation with a comment at the top of the Makefile but still include OS detection for the targets that can be portable

### 1.1 Required Targets (identical across all repos)

| Target | What it does |
|--------|-------------|
| `make build` | Compile/assemble all artifacts |
| `make test` | Run full test suite with coverage collection |
| `make lint` | Run all linters in error mode (non-zero exit on any warning) |
| `make fmt` | Format all code in-place |
| `make fmt-check` | Check formatting without modifying (used in CI) |
| `make clean` | Delete all build artifacts |
| `make check` | `lint` + `test` (pre-commit validation; fast) |
| `make ci` | `lint` + `test` + `build` (full CI simulation locally) |
| `make coverage` | Generate and open coverage report |
| `make coverage-check` | Assert coverage thresholds; exit non-zero if below |

### 1.2 Standard Makefile Template

**File:** [`templates/Makefile`](templates/Makefile)

---

## 2. CI/CD Standard

### 2.1 Required Workflow Files

| File | Trigger | Purpose |
|------|---------|---------|
| `.github/workflows/ci.yml` | PR to `main`, push to `main` | Lint → test → build validation |
| `.github/workflows/release.yml` | Push tag `v*` | Build release artifacts, publish, deploy |
| `.github/workflows/deploy-pages.yml` | `workflow_dispatch` (triggered by release.yml) | Deploy static site (if applicable) |

**Website deploys ONLY on release** — never on push to `main`. The website must not get ahead of the actual release. `release.yml` triggers `deploy-pages.yml` via `workflow_dispatch` after the GitHub release is created.

### 2.2 Standard CI Job Names (exact — do not deviate)

All `ci.yml` files MUST use these exact job names:

```
lint      — runs all linters/format checks
test      — runs all tests + coverage collection
build     — compiles artifacts (depends on test)
```

Optional jobs (exact names):
```
security  — vulnerability scanning (cargo audit, npm audit, etc.)
deploy    — deploy preview/staging (depends on build)
```

### 2.3 ci.yml Template

**File:** [`templates/.github/workflows/ci.yml`](templates/.github/workflows/ci.yml)

### 2.4 release.yml Template

**File:** [`templates/.github/workflows/release.yml`](templates/.github/workflows/release.yml)

The release pipeline runs on tag push (`v*`) and executes these jobs in order:

1. **version** — Extract version from tag, stamp it into project manifests, commit/push back to `main`
2. **build-cross-platform** — Build platform-independent packages on ubuntu
3. **build-platform** — Build platform-specific binaries on their respective OS (Linux, macOS, Windows)
4. **release** — Download all artifacts, create GitHub release with release notes
5. **publish** — Push packages/binaries to registries (npm, NuGet, PyPI, pub.dev, crates.io, VS Code Marketplace). Requires secrets configured in repo Settings → Secrets → Actions.
6. **deploy-pages** — Trigger the `deploy-pages.yml` workflow via `workflow_dispatch`

### 2.5 deploy-pages.yml Template

**File:** [`templates/.github/workflows/deploy-pages.yml`](templates/.github/workflows/deploy-pages.yml)

---

## 3. Coverage Standards

### 3.1 Thresholds by Repo Type

| Repo type | Line coverage | Branch coverage |
|-----------|--------------|----------------|
| Library / SDK / LSP | 90% | 80% |
| CLI tool | 85% | 75% |
| Application / Service | 80% | 70% |
| VS Code / Zed extension | 80% | 70% |
| Static site / docs only | N/A | N/A |

### 3.2 Coverage Tools by Language

| Language | Tool | Install |
|----------|------|---------|
| Rust | `cargo-llvm-cov` | `cargo install cargo-llvm-cov` |
| TypeScript/Node | `c8` | `npm install -D c8` |
| Python | `pytest-cov` | `pip install pytest-cov` |
| Dart/Flutter | Built-in + `lcov` | `sudo apt-get install lcov` |
| C#/.NET | Coverlet + `reportgenerator` | NuGet in test projects |
| F# | Same as C# | Same as C# |
| Go | Built-in `go tool cover` | Built-in |

### 3.3 Coverage check (Makefile-based)

Coverage enforcement is handled directly in the Makefile `_coverage_check` target — no shell scripts.
Each language implementation extracts line coverage and compares it to `COVERAGE_THRESHOLD` (default: 90).
The CI `coverage-check` step runs `make coverage-check`.

**Per-project thresholds:** Each project in a repo has its own coverage threshold stored as a
GitHub repo variable (Settings → Variables → Actions). The Makefile default is 90%.
In CI, the skill configures the `coverage-check` step to pass the repo variable as an env var
(e.g., `COVERAGE_THRESHOLD: ${{ vars.COVERAGE_THRESHOLD_PYTHON }}`).

**Ratchet rule:** Thresholds are **monotonically increasing** — they never go down. When
coverage improves past the current threshold, bump the GitHub variable up to match. This
ensures coverage never regresses.

### 3.4 .coveragerc (Python)

**File:** [`templates/coverage/.coveragerc`](templates/coverage/.coveragerc)

### 3.5 coverlet.runsettings (C#/.NET)

**File:** [`templates/coverage/coverlet.runsettings`](templates/coverage/coverlet.runsettings)

---

## 4. Linting Standards — Exact Configurations

Turn all rules on and turn them up to error unless there is a comment explaining why the rule should not be turned on.

### 4.1 Rust — Cargo.toml workspace lints

The basic principle is to turn ALL lints on and turn them up to ERROR. The only exception would be that the existing configuration already has a documented reason NOT to turn the lint run on.

Every Rust workspace Cargo.toml MUST include these lint sections.

**File:** [`templates/linting/cargo-workspace-lints.toml`](templates/linting/cargo-workspace-lints.toml)

### 4.2 Rust — rustfmt.toml

**File:** [`templates/linting/rustfmt.toml`](templates/linting/rustfmt.toml)

### 4.3 TypeScript — eslint.config.mjs (flat config, ESLint v9+)

**File:** [`templates/linting/eslint.config.mjs`](templates/linting/eslint.config.mjs)

### 4.4 TypeScript — .prettierrc.json

**File:** [`templates/linting/.prettierrc.json`](templates/linting/.prettierrc.json)

### 4.5 TypeScript — tsconfig.json (strict baseline)

**File:** [`templates/linting/tsconfig.json`](templates/linting/tsconfig.json)

### 4.6 Python — Basilisk (primary linter/type checker) + pyproject.toml (ruff + pyright)

**Basilisk is the primary linter and type checker for all Python projects.** Configure Basilisk as the main linting tool. The `pyproject.toml` ruff + pyright sections serve as a secondary layer.

**File:** [`templates/linting/pyproject.toml`](templates/linting/pyproject.toml)

### 4.7 Dart/Flutter — analysis_options.yaml

**File:** [`templates/linting/analysis_options.yaml`](templates/linting/analysis_options.yaml)

### 4.8 Go — .golangci.yml

**File:** [`templates/linting/.golangci.yml`](templates/linting/.golangci.yml)

### 4.9 C# — Static Analysis via Directory.Build.props

Do not add style rules to the .editorconfig because this can destroy formatting. 
Do add all code analysis rules, especially null safety rules
If the repo has a rules config file, use this instead

### 4.10 F# — Analyzer Configuration

F# analyzer rules are configured via project files.

---

## 5. Formatting Standards

**CI MUST check formatting and fail hard on any violation.** The `lint` CI job runs `make fmt-check`; any formatting diff = pipeline failure.

### 5.1 Formatting Tools by Language

| Language | Formatter | Format command | Check command |
|----------|-----------|---------------|---------------|
| C# | CSharpier | `dotnet csharpier .` | `dotnet csharpier --check .` |
| F# | Fantomas | `dotnet fantomas .` | `dotnet fantomas --check .` |
| Rust | rustfmt | `cargo fmt` | `cargo fmt --check` |
| Python | Basilisk (lint) → ruff format | `basilisk lint . && ruff format .` | `basilisk lint . && ruff format --check .` |
| TypeScript/JavaScript | Prettier | `npx prettier --write .` | `npx prettier --check .` |
| Dart/Flutter | dart format | `dart format .` | `dart format --set-exit-if-changed .` |
| Go | gofmt + goimports | `gofmt -w . && goimports -w .` | `gofmt -l . \| grep . && exit 1 \|\| true` |

### 5.2 Python formatting note

**Basilisk is the primary linter for all Python projects.** Run Basilisk first for linting, then use the most common formatter (ruff format) for auto-formatting. The `make fmt` target chains both; `make fmt-check` checks both and fails on any issue.

### 5.3 Multi-language repos

For repos with multiple languages, the Makefile `fmt` and `fmt-check` targets MUST chain all applicable formatters. A single `make fmt-check` validates every language in the repo.

---

---

## 6. Logging Standards

Every repo MUST use structured logging throughout the application. `print`/`console.log`/`println!`/`Debug.WriteLine` are prohibited for diagnostics.

### 6.1 Universal Logging Rules

1. **Structured logging library required.** See §6.2 for per-language libraries.
2. **Log at entry/exit of all significant operations.** Use levels: `error`, `warn`, `info`, `debug`, `trace`.
3. **Structured fields over string interpolation.** Log `{ "userId": 42, "action": "checkout" }` not `"User 42 performed checkout"`.
4. **Async/background logging for I/O sinks.** Any log call that writes to a database or file MUST be async or run on a background thread. Never block the request/UI thread with logging I/O.
5. **NEVER log personal data.** No PII: names, emails, addresses, phone numbers, IP addresses (unless required for security audit with explicit documented consent).
6. **NEVER log secrets.** No API keys, tokens, passwords, connection strings, or credentials. To confirm a key is loaded, log a truncated hash or `"API key: present"`.

### 6.2 Logging Libraries by Language

| Language | Library | Install |
|----------|---------|---------|
| Rust | `tracing` + `tracing-subscriber` | `cargo add tracing tracing-subscriber` |
| TypeScript/Node | `pino` | `npm install pino` (`pino-pretty` for dev) |
| Python | `structlog` | `pip install structlog` |
| Dart/Flutter | `dart_logging` | `dart pub add dart_logging` |
| C# | `Microsoft.Extensions.Logging` + `Serilog` | NuGet: `Serilog.Extensions.Logging` |
| F# | `Microsoft.Extensions.Logging` + `Serilog` | Same as C# |
| Go | `log/slog` (stdlib) | Built-in (Go 1.21+) |

### 6.3 VS Code Extension Logging

- Write detailed structured logs to a file inside the extension's state folder (`.vsixname/` in the workspace root).
- Basic errors and diagnostics MUST also be written to the extension's VS Code **Output Channel** so users can see them without hunting for log files.
- Both sinks (file + Output Channel) must be active simultaneously.

### 6.4 SaaS / Server Application Logging

- Log to the database for persistence and queryability.
- Database/file log writes MUST be async or on a background thread — never block the request path.
- In addition to the database, emit structured logs to stdout/stderr for container orchestrators and log aggregation services.

### 6.5 Repo State Checklist Addition

The §15 checklist gains these items under a new LOGGING section:

```
LOGGING
[ ] Structured logging library installed (per §6.2)
[ ] No raw print/console.log/println!/Debug.WriteLine for diagnostics
[ ] Log calls present at entry/exit of significant operations
[ ] VS Code extensions: Output Channel + file logging configured
[ ] SaaS apps: async database logging configured
[ ] No PII or secrets in log output
```

---

## 7. .gitignore Standard

### 7.1 Universal .gitignore base (all repos)

**File:** [`templates/gitignore/universal.gitignore`](templates/gitignore/universal.gitignore)

### 7.2 Per-language additions (append to repo .gitignore)

| Language | File |
|----------|------|
| Rust | [`templates/gitignore/rust.gitignore`](templates/gitignore/rust.gitignore) |
| TypeScript/Node | [`templates/gitignore/typescript.gitignore`](templates/gitignore/typescript.gitignore) |
| Python | [`templates/gitignore/python.gitignore`](templates/gitignore/python.gitignore) |
| Dart/Flutter | [`templates/gitignore/dart.gitignore`](templates/gitignore/dart.gitignore) |
| C#/.NET | [`templates/gitignore/csharp.gitignore`](templates/gitignore/csharp.gitignore) |
| F# | [`templates/gitignore/fsharp.gitignore`](templates/gitignore/fsharp.gitignore) |
| Go | [`templates/gitignore/go.gitignore`](templates/gitignore/go.gitignore) |
| Ruby/Jekyll | [`templates/gitignore/ruby.gitignore`](templates/gitignore/ruby.gitignore) |

---

## 8. Dev Container Standard

### 8.1 Required files

```
.devcontainer/
├── devcontainer.json     # required
└── Dockerfile            # required if not using a pre-built image
```

### 8.2 devcontainer.json templates

| Language | File |
|----------|------|
| Rust | [`templates/devcontainer/rust.devcontainer.json`](templates/devcontainer/rust.devcontainer.json) |
| TypeScript/Node | [`templates/devcontainer/typescript.devcontainer.json`](templates/devcontainer/typescript.devcontainer.json) |
| Python | [`templates/devcontainer/python.devcontainer.json`](templates/devcontainer/python.devcontainer.json) |
| Flutter/Dart | [`templates/devcontainer/flutter.devcontainer.json`](templates/devcontainer/flutter.devcontainer.json) |
| C#/.NET | [`templates/devcontainer/csharp.devcontainer.json`](templates/devcontainer/csharp.devcontainer.json) |
| F# | [`templates/devcontainer/fsharp.devcontainer.json`](templates/devcontainer/fsharp.devcontainer.json) |
| Go | [`templates/devcontainer/go.devcontainer.json`](templates/devcontainer/go.devcontainer.json) |

### 8.3 Setup

Dev environment setup is handled by `make setup` (defined in the Makefile). All devcontainer.json templates use `"postCreateCommand": "make setup"`.

---

## 9. PR Template Standard

### 9.1 .github/pull_request_template.md

**File:** [`templates/.github/pull_request_template.md`](templates/.github/pull_request_template.md)

---

## 10. Agent Instructions Standard (Agent-Agnostic)

The rules content (hard rules, logging standards, testing, build commands, architecture) is **agent-neutral**. The file it lives in depends on which AI coding agent the target repo primarily uses.

### 10.0 Critical Reference Documentation

Before manipulating ANY agent instruction or skill files, the skill MUST read the official documentation for the target agent. Each agent has its own syntax, file locations, and conventions. **Do not guess — read the docs first.**

#### Agent Instruction File Docs

| Agent | Instruction file | Official docs |
|---|---|---|
| Claude Code | `CLAUDE.md` (uses `@file` imports) | https://code.claude.com/docs/en/memory#claude-md-files |
| OpenAI Codex | `AGENTS.md` (walks up directory tree) | https://developers.openai.com/codex/guides/agents-md |
| GitHub Copilot | `.github/copilot-instructions.md` + `AGENTS.md` | https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions |
| Cline / Roo | `.clinerules/*.md` (supports `paths:` frontmatter) | https://docs.cline.bot/customization/cline-rules |
| OpenCode | `AGENTS.md` (falls back to `CLAUDE.md`) | https://opencode.ai/docs/rules/ |

#### Agent Skill Docs

| Agent | Skill directory | Official docs |
|---|---|---|
| Claude Code | `.claude/skills/<name>/SKILL.md` | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview |
| OpenAI Codex | `.agents/skills/<name>/SKILL.md` | https://developers.openai.com/codex/skills |
| GitHub Copilot | `.github/skills/<name>/SKILL.md` or `.agents/skills/<name>/SKILL.md` | https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills |
| Cline / Roo | `.cline/skills/<name>/SKILL.md` or `.claude/skills/<name>/SKILL.md` | https://docs.cline.bot/customization/skills |
| OpenCode | `.opencode/skills/<name>/SKILL.md` or `.agents/skills/<name>/SKILL.md` | https://opencode.ai/docs/skills/ |

#### Key differences between agents

| Concern | Claude Code | OpenAI Codex | GitHub Copilot | Cline/Roo | OpenCode |
|---|---|---|---|---|---|
| **Primary instruction file** | `CLAUDE.md` | `AGENTS.md` | `.github/copilot-instructions.md` | `.clinerules/*.md` | `AGENTS.md` |
| **Import syntax** | `@path/to/file` | N/A (concatenates) | N/A | N/A | `instructions` in JSON |
| **Skill directory** | `.claude/skills/` | `.agents/skills/` | `.github/skills/` or `.agents/skills/` | `.cline/skills/` or `.claude/skills/` | `.opencode/skills/` or `.agents/skills/` |
| **Reads `AGENTS.md`** | No (needs `@AGENTS.md` import in `CLAUDE.md`) | Yes (native) | Yes | Yes (auto-detect) | Yes (native) |
| **Reads `CLAUDE.md`** | Yes (native) | No | No | No | Yes (fallback) |

### 10.1 Canonical Template

**File:** [`templates/AGENTS.md`](templates/AGENTS.md) — contains ALL rules in agent-neutral language. This is the authoritative template for project instructions regardless of which agent consumes them.

### 10.2 Agent Detection

Before placing files, the skill MUST detect which AI coding agent the target repo primarily uses. Check these signals in priority order:

| Priority | Signal | Indicates |
|----------|--------|-----------|
| 1 | `.claude/settings.json` or `.claude/settings.local.json` exists | Claude Code |
| 2 | `.claude/skills/` has custom skills (not just template skills) | Claude Code |
| 3 | `.cursor/` directory exists | Cursor |
| 4 | `.cline/` or `.clinerules/` with custom rules (not just a pointer) | Cline / Roo |
| 5 | `.windsurf/` directory exists | Windsurf |
| 6 | `.github/copilot-instructions.md` with substantial content (not just a pointer) | GitHub Copilot |
| 7 | `CLAUDE.md` exists with substantial content (not just a pointer) | Claude Code |
| 8 | `AGENTS.md` exists with substantial content | Agent-neutral (keep as-is) |
| 9 | None of the above | Default → AGENTS.md |

"Substantial content" = more than 10 lines AND not just a redirect/pointer to another file.

### 10.3 File Placement Rules

Based on detection, the skill places the full rules content in the **canonical file** and makes all other agent files into pointers.

| Primary Agent | Canonical file (full content) | All other agent files |
|---|---|---|
| Claude Code | `CLAUDE.md` (AGENTS.md content + Claude addendum) | Pointer → `CLAUDE.md` |
| Cursor | `AGENTS.md` | Pointer → `AGENTS.md` |
| Cline / Roo | `AGENTS.md` | Pointer → `AGENTS.md` |
| Windsurf | `AGENTS.md` | Pointer → `AGENTS.md` |
| GitHub Copilot | `AGENTS.md` | Pointer → `AGENTS.md` |
| No agent / Unknown | `AGENTS.md` | Pointer → `AGENTS.md` |

When Claude IS the primary agent:
- `CLAUDE.md` gets the full AGENTS.md template content plus Claude-specific skill links at the bottom
- `AGENTS.md` becomes a pointer to `CLAUDE.md`
- All other agent files point to `CLAUDE.md`

When Claude is NOT the primary agent:
- `AGENTS.md` gets the full template content (no Claude addendum)
- `CLAUDE.md` imports `AGENTS.md` using the official `@AGENTS.md` syntax (per Claude Code docs) plus any Claude-specific addendum
- All other agent files point to `AGENTS.md`
- Claude-specific files (`.claude/skills/`) are still placed if Claude Code is used at all (secondary agent), since they don't interfere with other agents

**CRITICAL — Pointer syntax is agent-specific.** Each agent has its own way of importing/referencing another file. The skill MUST use the correct syntax per the docs in §10.0:
- **Claude Code**: `@AGENTS.md` import in `CLAUDE.md` (official import syntax)
- **Copilot**: `.github/copilot-instructions.md` says "read AGENTS.md" in plain text
- **Cline/Roo**: `.clinerules/` file says "read {{CANONICAL_FILE}}" in plain text
- **Cursor/Windsurf**: `.cursorrules`/`.windsurfrules` says "read {{CANONICAL_FILE}}" in plain text
- **OpenCode**: `opencode.json` `"instructions"` array references the canonical file

### 10.4 Pointer Files

Every repo gets pointer files for agents that are NOT the primary agent. Each pointer redirects to the canonical file.

| Agent / Tool | File | Template |
|--------------|------|----------|
| Claude Code | `CLAUDE.md` (pointer when not primary) | [`templates/CLAUDE.md`](templates/CLAUDE.md) |
| Cline / Roo (native rules) | `.clinerules/00-read-instructions.md` | [`templates/.clinerules/00-read-instructions.md`](templates/.clinerules/00-read-instructions.md) |
| Cursor | `.cursorrules` | [`templates/.cursorrules`](templates/.cursorrules) |
| Windsurf | `.windsurfrules` | [`templates/.windsurfrules`](templates/.windsurfrules) |
| GitHub Copilot | `.github/copilot-instructions.md` | [`templates/.github/copilot-instructions.md`](templates/.github/copilot-instructions.md) |
| OpenCode | `opencode.json` | [`templates/opencode.json`](templates/opencode.json) |

**Rules:**
- NEVER add project rules to pointer files. All rules live in the canonical file.
- If a new agent tool appears, add a pointer file here — do not create a second set of rules.

---

## 11. Skills Standard (Agent-Agnostic)

Skills are portable, on-demand instruction packages. The templates in `templates/skills/` are written in a generic SKILL.md format. When applying to a target repo, the skill MUST convert them to the target agent's native format and directory structure.

### 11.0 CRITICAL — Read the target agent's skill docs first

Before placing or converting any skill files, the agent MUST read the official skill documentation for the target agent (see §10.0 Agent Skill Docs table). Each agent has different:
- **Directory locations** (`.claude/skills/`, `.agents/skills/`, `.github/skills/`, `.cline/skills/`, `.opencode/skills/`)
- **Frontmatter requirements** (some require `name` to match directory, some have `compatibility` fields)
- **Size constraints** (Cline: keep under 5,000 tokens; others vary)
- **Discovery conventions** (some walk up directories, some only check project root)

### 11.1 Skill placement by agent

| Agent | Primary skill directory | Also scanned |
|---|---|---|
| Claude Code | `.claude/skills/<name>/SKILL.md` | — |
| OpenAI Codex | `.agents/skills/<name>/SKILL.md` | — |
| GitHub Copilot | `.github/skills/<name>/SKILL.md` | `.agents/skills/`, `.claude/skills/` |
| Cline / Roo | `.cline/skills/<name>/SKILL.md` | `.claude/skills/`, `.clinerules/skills/` |
| OpenCode | `.opencode/skills/<name>/SKILL.md` | `.agents/skills/`, `.claude/skills/` |

When placing skills:
1. **Primary agent gets skills in its native directory.** If Claude is primary, skills go in `.claude/skills/`. If Copilot is primary, skills go in `.github/skills/`.
2. **Cross-compatible directories are acceptable.** Copilot, Cline, and OpenCode all scan `.agents/skills/` as a fallback. If the repo uses multiple agents, placing skills in `.agents/skills/` covers the most agents with one copy.
3. **The SKILL.md format is universal.** All agents use the same `SKILL.md` with YAML frontmatter (`name`, `description`) plus markdown body. The skill content itself is portable.

### 11.2 Required skills

| Skill | Template |
|-------|----------|
| build | [`templates/skills/build/SKILL.md`](templates/skills/build/SKILL.md) |
| ci-prep | [`templates/skills/ci-prep/SKILL.md`](templates/skills/ci-prep/SKILL.md) |
| code-dedup | [`templates/skills/code-dedup/SKILL.md`](templates/skills/code-dedup/SKILL.md) |
| submit-pr | [`templates/skills/submit-pr/SKILL.md`](templates/skills/submit-pr/SKILL.md) |

---

## 12. Branch Strategy Standard

### 12.1 Default branch

All repos: `main` (never `master`)

### 12.2 Branch naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/[ISSUE]-[slug]` | `feature/42-add-coverage` |
| Bug fix | `fix/[ISSUE]-[slug]` | `fix/17-null-ref` |
| Chore | `chore/[slug]` | `chore/update-deps` |
| Release | `release/[semver]` | `release/1.2.0` |
| Claude agent | `claude/[slug]-[random5]` | `claude/refactor-XYZab` |

### 12.3 Rules

- All changes via PR — no direct pushes to `main`
- CI must pass before merge
- Squash-merge preferred for feature branches
- Delete branch after merge

---

## 13. GitHub Repository Settings

Every repo MUST have these GitHub settings applied. The authoritative reference is [`templates/.github/common-repo-settings.md`](templates/.github/common-repo-settings.md).

### 13.1 Merge Settings

| Setting | Value |
|---|---|
| Allow squash merge | **true** (only merge strategy allowed) |
| Allow merge commit | **false** |
| Allow rebase merge | **false** |
| Allow auto merge | **true** |
| Delete branch on merge | **true** |
| Squash merge commit title | **PR_TITLE** |
| Squash merge commit message | **PR_BODY** |

### 13.2 Features

| Setting | Value |
|---|---|
| Issues | **true** |
| Wiki | **false** |
| Projects | **false** |
| Discussions | **true** (public repos only) |

### 13.3 Branch Protection

If no branch protection exists, add a ruleset requiring:
- PRs to `main` (no direct pushes)
- CI status checks must pass before merge

If protection already exists, leave it alone.

### 13.4 Applying Settings via `gh` CLI

```bash
REPO="OWNER/REPO"

gh api -X PATCH "repos/$REPO" \
  -f allow_squash_merge=true \
  -f allow_merge_commit=false \
  -f allow_rebase_merge=false \
  -f allow_auto_merge=true \
  -f delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -f has_wiki=false \
  -f has_projects=false \
  -f has_discussions=true
```

---

## 14. package.json Scripts Standard (TypeScript/Node repos)

Every `package.json` MUST define these script names.

**File:** [`templates/linting/package-scripts.json`](templates/linting/package-scripts.json)

The Makefile delegates to these. `make lint` calls `npm run lint && npm run fmt:check && npm run typecheck`.

---

## 15. Repo State Assessment Checklist

A skill assessing a repo runs through this checklist. Each item is either PRESENT (✓), MISSING (✗), or WRONG (△).

```
STRUCTURE
[ ] docs/ directory exists (not doco/, documentation/, doc/, etc.)
[ ] docs/specs/ subdirectory exists
[ ] docs/plans/ subdirectory exists
[ ] Non-standard doc folders normalised (doco/, documentation/, doc/ → docs/)
[ ] .github/workflows/ci.yml
[ ] .github/workflows/release.yml          (if distributable artifact)
[ ] .github/workflows/deploy-pages.yml     (if static site)
[ ] .github/pull_request_template.md
[ ] .devcontainer/devcontainer.json
[ ] Makefile `setup` target configured
[ ] Skills in agent-native directory (§11.1: .claude/, .agents/, .github/, .cline/, or .opencode/)
[ ] Required skills present: build, ci-prep, code-dedup, submit-pr
[ ] All agent-pmo managed files have `agent-pmo:<hash>` marker (§16)
[ ] No orphaned agent-pmo files (marked files whose source template no longer exists)
[ ] .gitignore (comprehensive)
[ ] .prettierrc.json                       (TypeScript repos)
[ ] eslint.config.mjs                      (TypeScript repos)
[ ] rustfmt.toml                           (Rust repos)
[ ] .golangci.yml                          (Go repos)
[ ] analysis_options.yaml                  (Dart/Flutter repos)
[ ] pyproject.toml [tool.ruff]             (Python repos)
[ ] coverlet.runsettings                   (C#/.NET repos)
[ ] .coveragerc                            (Python repos)
[ ] Makefile (with all 10 required targets)
[ ] Makefile has OS detection block (§1.0 cross-platform support)
[ ] Makefile uses $(RM)/$(MKDIR) instead of rm -rf/mkdir -p
[ ] Makefile `_coverage_check` target (language-specific inline check)
[ ] Canonical instruction file has all required sections (CLAUDE.md or AGENTS.md per §10.3)
[ ] Non-canonical instruction file is a pointer to canonical file (§10.4)
[ ] .clinerules/00-read-instructions.md (pointer → canonical file)
[ ] .cursorrules (pointer → canonical file)
[ ] .windsurfrules (pointer → canonical file)
[ ] .github/copilot-instructions.md (pointer → canonical file)
[ ] opencode.json (instructions array referencing canonical file)

LOGGING (§6)
[ ] Structured logging library installed (per §6.2)
[ ] No raw print/console.log/println!/Debug.WriteLine for diagnostics
[ ] Log calls present at entry/exit of significant operations
[ ] VS Code extensions: Output Channel + file logging configured
[ ] SaaS apps: async database logging configured
[ ] No PII or secrets in log output

CI
[ ] ci.yml has jobs named exactly: lint, test, build
[ ] ci.yml has concurrency cancel-in-progress
[ ] ci.yml: lint job runs `make fmt-check` (formatting failures = hard fail)
[ ] ci.yml: lint runs before test
[ ] ci.yml: test runs before build
[ ] ci.yml: coverage-check step in test job
[ ] ci.yml: artifacts uploaded

COVERAGE
[ ] Per-project COVERAGE_THRESHOLD set as GitHub repo variable (ratchet — never decreases)
[ ] Makefile `_coverage_check` target exists and works
[ ] Coverage tool installed (language-appropriate)

LINTING
[ ] Rust: workspace.lints in Cargo.toml
[ ] TypeScript: eslint.config.mjs with strictTypeChecked
[ ] Python: Basilisk (primary linter) + pyproject.toml [tool.ruff] with select=["ALL"]
[ ] Dart: analysis_options.yaml with strict-casts, strict-inference
[ ] Go: .golangci.yml with default: all
[ ] C#: Directory.Build.props with NetAnalyzers, CA* and IDE* as error

FORMATTING
[ ] Rust: rustfmt.toml
[ ] TypeScript: .prettierrc.json
[ ] Python: Basilisk (primary lint) → ruff format in pyproject.toml
[ ] Dart: dart format via make fmt
[ ] Go: gofmt / goimports
[ ] C#: CSharpier (`dotnet csharpier`)
[ ] F#: Fantomas (`dotnet fantomas`)

BRANCH
[ ] Default branch is 'main' (not 'master')
[ ] Branch naming convention documented in CLAUDE.md

GITHUB REPO SETTINGS (§13)
[ ] Squash merge only (merge commit and rebase disabled)
[ ] Auto merge enabled
[ ] Delete branch on merge enabled
[ ] Squash commit title = PR_TITLE, message = PR_BODY
[ ] Wiki disabled, Projects disabled, Discussions enabled (public only)
[ ] Branch protection on main (require PR + CI pass)
```

---

## 16. File Markers

### [MARKER-FORMAT] Agent-PMO file marker

Every file created or substantively edited by agent-pmo MUST contain a marker comment near the top of the file (after any shebang, frontmatter, or XML declaration). The marker tells agents that the file is managed by agent-pmo and includes the short git commit hash of the agent-pmo repo at the time the file was written.

**Format:**

```
agent-pmo:<short-hash>
```

Where `<short-hash>` is the 7-character abbreviated commit hash from the AgentPMOWorkflow repo (output of `git rev-parse --short HEAD` run inside the standards repo).

**Placement by file type:**

| File type | Marker syntax | Example |
|-----------|--------------|---------|
| YAML (`.yml`, `.yaml`) | `# agent-pmo:abc1234` | CI workflows, analysis_options |
| Makefile | `# agent-pmo:abc1234` | Root Makefile |
| Markdown (`.md`) | `<!-- agent-pmo:abc1234 -->` | AGENTS.md, CLAUDE.md, skills, PR template |
| JSON (`.json`) | Top-level `"_agent_pmo": "abc1234"` field | devcontainer.json, opencode.json, tsconfig |
| TOML (`.toml`) | `# agent-pmo:abc1234` | pyproject.toml, rustfmt.toml |
| JavaScript/TypeScript (`.js`, `.mjs`, `.ts`) | `// agent-pmo:abc1234` | eslint.config.mjs |
| XML (`.props`, `.runsettings`) | `<!-- agent-pmo:abc1234 -->` | Directory.Build.props, coverlet.runsettings |
| Shell (`.sh`) | `# agent-pmo:abc1234` | Any shell scripts |
| Dotfiles (`.gitignore`, `.coveragerc`, etc.) | `# agent-pmo:abc1234` | .gitignore, .coveragerc |

**Rules:**

1. The marker MUST appear within the first 10 lines of the file.
2. For files with required headers (shebang lines, YAML `---` frontmatter, XML `<?xml?>` declarations), place the marker immediately after the header.
3. For SKILL.md files, place the marker on the line immediately after the closing `---` of the YAML frontmatter.
4. Only stamp files that agent-pmo creates or substantively modifies. Do not stamp files that already exist and are left unchanged.
5. When re-running agent-pmo on a repo, update the hash in existing markers to the current commit.
6. **NEVER stamp a file with the `agent-pmo:` marker unless its source template or skill exists at an exact path in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/` RIGHT NOW.** Before stamping ANY file, verify the source exists by reading it. If you cannot read the source file at the expected path, the file MUST NOT be created and MUST NOT be stamped. This is non-negotiable. A marker is a claim of provenance — stamping a file that has no source in the standards repo is a lie.

### [MARKER-CLEANUP] Orphaned file cleanup

During the deduplication check (§17 Step 4), the agent MUST scan for files with an `agent-pmo:` marker that correspond to templates or skills that **no longer exist** in the source standards repo. If a marked file in the target repo has no corresponding source in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/`, the file is orphaned and MUST be deleted.

**Process:**

1. Find all files in the target repo containing `agent-pmo:` markers.
2. For each marked file, determine which template or skill it originated from.
3. Check whether that template or skill still exists in the standards repo.
4. If the source no longer exists, delete the orphaned file from the target repo.
5. Report all orphaned files deleted.

This ensures that when skills or templates are removed from the standards repo (e.g., the `fmt`, `lint`, and `test` skills were consolidated into `ci-prep`), target repos get cleaned up automatically on the next agent-pmo run.

### [MARKER-AUDIT] Provenance auditing

The commit hash in the marker enables traceability:

- `git log --oneline <hash>..HEAD` in the standards repo shows what changed since the file was stamped.
- If a file's marker hash is far behind the current standards repo HEAD, the file may need re-application.
- The `agent-pmo` skill SHOULD note files with stale markers (more than 50 commits behind) and offer to re-apply the current templates.

---

## 17. Mint vs Remediate Modes

A skill built from this spec operates in two modes:

### MINT mode (new repo)

1. Create directory structure
2. Copy all config files verbatim from [`templates/`](templates/) (substituting `{{REPO_NAME}}`, `{{PRIMARY_LANGUAGE}}`, `{{CANONICAL_FILE}}`)
3. Select devcontainer template for primary language
4. Select Makefile implementation section for primary language
5. Detect primary agent (§10.2) and determine canonical file (§10.3)
6. Generate the canonical instruction file from `templates/AGENTS.md` — **customize all placeholder sections** for the repo's actual languages, architecture, and purpose. If Claude is primary, add Claude-specific skill links to CLAUDE.md.
7. Create all pointer files from §10.4, substituting `{{CANONICAL_FILE}}` with the detected canonical file
8. Create all skills from §11 templates — **see §17.2 Template Customization Rule**
9. Stamp every created file with the `agent-pmo:<hash>` marker per §16
10. Ensure `_coverage_check` Makefile target has inline coverage check logic per §3.3
11. Set `COVERAGE_THRESHOLD` appropriate for repo type (§3.1)

### REMEDIATE mode (existing repo)

1. Run the checklist from §15 against the repo
2. For each MISSING item: add it (using templates from [`templates/`](templates/))
3. For each WRONG item:
   - CI job names wrong → rename to `lint`, `test`, `build`
   - Makefile target names wrong → add aliases or rename
   - Coverage not enforced → add `coverage-check` step to CI and add `_coverage_check` target to Makefile
   - `.gitignore` missing tool dirs → append standard tool patterns
   - Canonical instruction file missing sections → append missing sections (detect primary agent per §10.2 first)
   - Default branch is `master` → note for human action (cannot change remotely)
4. Report what was changed vs what needs human action
5. When two configs serve the same purpose, **merge them into the normative file and delete the old one** (e.g., merge `.eslintrc.js` into `eslint.config.mjs`, then delete `.eslintrc.js`). Merging and renaming to the standard name is expected — do not leave duplicates.

### 17.2 Template Customization Rule (CRITICAL)

**Templates are STARTING POINTS, not copy-paste targets.** Every template that contains language-specific examples, multi-language listings, or placeholder content MUST be tailored to the target repo before writing it. The repo must be **ready to go immediately** — no irrelevant languages, no generic examples, no placeholder text left behind.

What this means in practice:

1. **Skills (`.claude/skills/`):** Skill templates like `code-dedup`, `ci-prep`, etc. contain examples spanning all supported languages (Rust, TypeScript, Python, C#, F#, Go, Dart). When applying to a specific repo:
   - **Remove all language sections that don't apply.** A Python repo's `code-dedup` skill should only mention Python tools (`pyright`, `ruff`, `pytest-cov`), not `tsconfig`, `cargo`, or `dotnet`.
   - **Replace generic examples with repo-specific ones.** If the skill says "check for `Cargo.toml`, `package.json`, `pubspec.yaml`..." and the repo is Go, replace with the actual project files.
   - **Adjust tool references** to match what the repo actually uses (its Makefile targets, its CI steps, its linter configs).

2. **Canonical instruction file (CLAUDE.md or AGENTS.md per §10.3):** The template has `{{placeholders}}` and multi-language Hard Rules sections. Strip language-specific rules that don't apply. Fill in all placeholders with real content — project description, architecture, actual languages used.

3. **Makefile:** Uncomment only the language blocks that apply. Delete commented blocks for other languages so the file is clean and unambiguous.

4. **CI workflows:** Uncomment only the language setup steps that apply. Remove commented blocks for unused languages.

5. **Config files:** Only include configs for languages actually present in the repo. Don't create `eslint.config.mjs` for a Rust repo or `rustfmt.toml` for a Python repo.

**The test:** After applying templates, a developer reading any generated file should see ZERO references to languages, tools, or frameworks not used in the repo. If a file mentions "Rust" in a Python-only repo, the customization failed.

### Substitution variables

| Variable | Value |
|----------|-------|
| `{{REPO_NAME}}` | Repository directory name |
| `{{PRIMARY_LANGUAGE}}` | `rust` / `typescript` / `python` / `dart` / `csharp` / `fsharp` / `go` |
| `{{REPO_TYPE}}` | `library` / `cli` / `application` / `vscode-extension` / `static-site` |
| `{{COVERAGE_THRESHOLD}}` | Integer from §3.1 table |
| `{{DESCRIPTION}}` | One-line repo description |
| `{{CANONICAL_FILE}}` | `CLAUDE.md` or `AGENTS.md` (determined by §10.3 agent detection) |

---

## Appendix A: Current State Summary (20 repos, 2026-03-26)

| Repo | Language(s) | CI | Makefile | Coverage | Devcontainer | Skills | Agent Instructions | PR Template |
|------|------------|----|---------|---------|--------------|---------|-----------|----|
| forge | Rust+C#+F#+TS | ✗ | ✓ | partial | ✗ | ✗ | ✓ | ✗ |
| StoryTowns | Flutter+Deno | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| project_status | Flutter | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Books | Markdown | ✗ | ✗ | ✗ | ✗ | ✗ | partial | ✗ |
| Napper | F#+Rust+TS | ✗ | ✓ | partial | ✗ | ✗ | ✓ | ✗ |
| CommandTree | TypeScript | ✓ | ✗ | ✓ 90% | ✗ | partial | ✓ | ✗ |
| tmc | TypeScript | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| gigs | TS+Python+C# | partial | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| alcove | Python+Flutter | ✓ | ✗ | ✓ 70%/60% | ✗ | ✗ | ✓ | ✗ |
| Basilisk | Rust+TS+Python | ✓ | ✗ | ✓ per-crate | ✗* | ✗ | ✓ | ✗ |
| DataProvider | C#+TS | ✗ | ✗ | partial | ✗ | ✓ 7 | ✓ | partial |
| YFNUSYVJRH | Ruby/Jekyll | ✗ | ✗ | ✗ | ✓ | ✗ | minimal | ✗ |
| dart_agent | Dart | ✗ | ✓ | ✗ | ✓ | partial | ✓ | ✗ |
| vscode-copilot-chat | TypeScript | ✗ | ✗ | partial | ✓ | ✗ | ✗ | ✗ |
| spline | TypeScript | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| GrammarApi | Rust | ✓ | ✗ | ✗ | ✗ | ✗ | minimal | ✗ |
| h5-master | C# | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| vexels | Go+TS | ✓ | partial | partial | ✓ | ✗ | ✗ | ✓ |
| osprey_dua | Go+C+TS | ✓ | partial | partial | ✓ | ✗ | ✗ | ✓ |
| dart_mutant | Rust | partial | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |

*Basilisk: devcontainer mentioned in CLAUDE.md but not present on disk

---

## Template Files Index

All template files live in [`templates/`](templates/):

```
templates/
├── .clinerules/
│   └── 00-read-instructions.md
├── .cursorrules
├── .github/
│   ├── copilot-instructions.md
│   ├── pull_request_template.md
│   └── workflows/
│       ├── ci.yml
│       ├── deploy-pages.yml
│       └── release.yml
├── .windsurfrules
├── AGENTS.md                    # Canonical template (all rules, agent-neutral)
├── CLAUDE.md                    # Pointer to AGENTS.md (used when Claude is not primary)
├── Makefile
├── opencode.json
├── coverage/
│   ├── .coveragerc
│   └── coverlet.runsettings
├── devcontainer/
│   ├── csharp.devcontainer.json
│   ├── flutter.devcontainer.json
│   ├── fsharp.devcontainer.json
│   ├── go.devcontainer.json
│   ├── python.devcontainer.json
│   ├── rust.devcontainer.json
│   └── typescript.devcontainer.json
├── gitignore/
│   ├── csharp.gitignore
│   ├── dart.gitignore
│   ├── fsharp.gitignore
│   ├── go.gitignore
│   ├── python.gitignore
│   ├── ruby.gitignore
│   ├── rust.gitignore
│   ├── typescript.gitignore
│   └── universal.gitignore
├── linting/
│   ├── eslint.config.mjs
│   ├── .golangci.yml
│   ├── .prettierrc.json
│   ├── analysis_options.yaml
│   ├── cargo-workspace-lints.toml
│   ├── package-scripts.json
│   ├── pyproject.toml
│   ├── rustfmt.toml
│   └── tsconfig.json
└── skills/
    ├── build/
    │   └── SKILL.md
    ├── ci-prep/
    │   └── SKILL.md
    ├── code-dedup/
    │   └── SKILL.md
    ├── spec-check/
    │   └── SKILL.md
    ├── submit-pr/
    │   └── SKILL.md
    ├── upgrade-packages/
    │   └── SKILL.md
    └── website-audit/
        └── SKILL.md
```
