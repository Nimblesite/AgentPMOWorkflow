# Repository Standards Specification

> **Machine-readable standard for the `enforce-repo-standards` skill.**
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

---

## 1. Universal Makefile Standard

Every repo MUST have a root `Makefile` with **exactly** these target names.
Language-specific work is delegated internally; the external interface never changes.

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

## 10. CLAUDE.md Standard

### 10.1 Template (copy and customise per repo)

**File:** [`templates/CLAUDE.md`](templates/CLAUDE.md)

### 10.2 Cross-Agent Instruction Files

`CLAUDE.md` is the **single source of truth** for all agent instructions. Other AI
coding agents receive pointer files that redirect them to `CLAUDE.md`. No rules or
standards are duplicated — every file below simply says "read `CLAUDE.md`."

| Agent / Tool | File | Purpose |
|--------------|------|---------|
| OpenAI Codex, Cline (auto-detect) | [`templates/AGENTS.md`](templates/AGENTS.md) | `@CLAUDE.md` pointer |
| Cline / Roo (native rules) | [`templates/.clinerules/00-read-claude-md.md`](templates/.clinerules/00-read-claude-md.md) | `@CLAUDE.md` pointer |
| Cursor | [`templates/.cursorrules`](templates/.cursorrules) | `@CLAUDE.md` pointer |
| Windsurf | [`templates/.windsurfrules`](templates/.windsurfrules) | `@CLAUDE.md` pointer |
| GitHub Copilot | [`templates/.github/copilot-instructions.md`](templates/.github/copilot-instructions.md) | `@CLAUDE.md` pointer |
| OpenCode | [`templates/opencode.json`](templates/opencode.json) | `instructions` array referencing `CLAUDE.md` |

**Rules:**
- NEVER add project rules to these files. All rules live in `CLAUDE.md`.
- If a new agent tool appears, add a pointer file here — do not create a second set of rules.

---

## 11. Claude Skills Standard

### 11.1 Required skills directory structure

```
.claude/
└── skills/
    ├── build/
    │   └── SKILL.md
    ├── test/
    │   └── SKILL.md
    ├── lint/
    │   └── SKILL.md
    ├── fmt/
    │   └── SKILL.md
    ├── ci-prep/
    │   └── SKILL.md
    ├── code-dedup/
    │   └── SKILL.md
    └── submit-pr/
        └── SKILL.md
```

### 11.2 Skill file templates

| Skill | File |
|-------|------|
| build | [`templates/skills/build/SKILL.md`](templates/skills/build/SKILL.md) |
| test | [`templates/skills/test/SKILL.md`](templates/skills/test/SKILL.md) |
| lint | [`templates/skills/lint/SKILL.md`](templates/skills/lint/SKILL.md) |
| fmt | [`templates/skills/fmt/SKILL.md`](templates/skills/fmt/SKILL.md) |
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
[ ] .claude/skills/build/SKILL.md
[ ] .claude/skills/test/SKILL.md
[ ] .claude/skills/lint/SKILL.md
[ ] .claude/skills/fmt/SKILL.md
[ ] .claude/skills/ci-prep/SKILL.md
[ ] .claude/skills/code-dedup/SKILL.md
[ ] .claude/skills/submit-pr/SKILL.md
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
[ ] Makefile `_coverage_check` target (language-specific inline check)
[ ] CLAUDE.md (all required sections)
[ ] AGENTS.md (@CLAUDE.md pointer)
[ ] .clinerules/00-read-claude-md.md (@CLAUDE.md pointer)
[ ] .cursorrules (@CLAUDE.md pointer)
[ ] .windsurfrules (@CLAUDE.md pointer)
[ ] .github/copilot-instructions.md (@CLAUDE.md pointer)
[ ] opencode.json (instructions array referencing CLAUDE.md)

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

## 16. Mint vs Remediate Modes

A skill built from this spec operates in two modes:

### MINT mode (new repo)

1. Create directory structure
2. Copy all config files verbatim from [`templates/`](templates/) (substituting `{{REPO_NAME}}`, `{{PRIMARY_LANGUAGE}}`)
3. Select devcontainer template for primary language
4. Select Makefile implementation section for primary language
5. Generate `CLAUDE.md` from §10 template — **customize all placeholder sections** for the repo's actual languages, architecture, and purpose
6. Copy cross-agent pointer files from §10.2 (`AGENTS.md`, `.clinerules/`, `.cursorrules`, `.windsurfrules`, `.github/copilot-instructions.md`, `opencode.json`)
7. Create all 7 skills from §11 templates — **see §16.2 Template Customization Rule**
8. Ensure `_coverage_check` Makefile target has inline coverage check logic per §3.3
9. Set `COVERAGE_THRESHOLD` appropriate for repo type (§3.1)

### REMEDIATE mode (existing repo)

1. Run the checklist from §15 against the repo
2. For each MISSING item: add it (using templates from [`templates/`](templates/))
3. For each WRONG item:
   - CI job names wrong → rename to `lint`, `test`, `build`
   - Makefile target names wrong → add aliases or rename
   - Coverage not enforced → add `coverage-check` step to CI and add `_coverage_check` target to Makefile
   - `.gitignore` missing tool dirs → append standard tool patterns
   - `CLAUDE.md` missing sections → append missing sections
   - Default branch is `master` → note for human action (cannot change remotely)
4. Report what was changed vs what needs human action
5. When two configs serve the same purpose, **merge them into the normative file and delete the old one** (e.g., merge `.eslintrc.js` into `eslint.config.mjs`, then delete `.eslintrc.js`). Merging and renaming to the standard name is expected — do not leave duplicates.

### 16.2 Template Customization Rule (CRITICAL)

**Templates are STARTING POINTS, not copy-paste targets.** Every template that contains language-specific examples, multi-language listings, or placeholder content MUST be tailored to the target repo before writing it. The repo must be **ready to go immediately** — no irrelevant languages, no generic examples, no placeholder text left behind.

What this means in practice:

1. **Skills (`.claude/skills/`):** Skill templates like `code-dedup`, `ci-prep`, etc. contain examples spanning all supported languages (Rust, TypeScript, Python, C#, F#, Go, Dart). When applying to a specific repo:
   - **Remove all language sections that don't apply.** A Python repo's `code-dedup` skill should only mention Python tools (`pyright`, `ruff`, `pytest-cov`), not `tsconfig`, `cargo`, or `dotnet`.
   - **Replace generic examples with repo-specific ones.** If the skill says "check for `Cargo.toml`, `package.json`, `pubspec.yaml`..." and the repo is Go, replace with the actual project files.
   - **Adjust tool references** to match what the repo actually uses (its Makefile targets, its CI steps, its linter configs).

2. **CLAUDE.md:** The template has `{{placeholders}}` and multi-language Hard Rules sections. Strip language-specific rules that don't apply. Fill in all placeholders with real content — project description, architecture, actual languages used.

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

---

## Appendix A: Current State Summary (20 repos, 2026-03-26)

| Repo | Language(s) | CI | Makefile | Coverage | Devcontainer | Skills | CLAUDE.md | PR Template |
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
│   └── 00-read-claude-md.md
├── .cursorrules
├── .github/
│   ├── copilot-instructions.md
│   ├── pull_request_template.md
│   └── workflows/
│       ├── ci.yml
│       ├── deploy-pages.yml
│       └── release.yml
├── .windsurfrules
├── AGENTS.md
├── CLAUDE.md
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
    ├── fmt/
    │   └── SKILL.md
    ├── lint/
    │   └── SKILL.md
    ├── submit-pr/
    │   └── SKILL.md
    └── test/
        └── SKILL.md
```
