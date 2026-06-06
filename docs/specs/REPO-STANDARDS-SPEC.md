# Repository Standards Specification

> **Machine-readable standard for the `agent-pmo` skill.**
> Defines the exact configuration files, targets, job names, and templates every repo in this
> portfolio must conform to. The skill reads this to MINT a new repo or REMEDIATE an existing one.

---

## [DESIGN] Design Principles

1. **Docs are the source of truth.** `specs/` defines behavior; `plans/` defines how to achieve goals. All plan docs MUST end with a TODO checklist (tracked across agents and sessions, unlike in-agent TODO lists).
2. **Templates are starting points, not copy-paste targets.** Every required config has a template in [`templates/`](templates/). The skill MUST customize it for the target repo — strip irrelevant language sections, fill placeholders, remove unused examples. See [MODES-CUSTOMIZE].
3. **Fail fast, fail loud.** Lint before test. Coverage threshold blocks merge. Zero warnings — all linters in errors-as-warnings mode. Every `make test` MUST stop at the first failure (see [TEST-RULES]).
4. **No git in Claude sessions.** CI and GitHub Actions do the git work.
5. **Multi-language repos are the norm.** Each language adds its targets/jobs orthogonally without breaking the uniform interface.
5a. **Prefer the generic/open standard over agent-specific variants.** When a vendor-neutral file or location and a Claude-specific one both work, the generic one is canonical: `AGENTS.md` over `CLAUDE.md`, the open Agent Skills directory `.agents/skills/` over `.claude/skills/`. Generic artifacts serve every agent at once. This is a tie-breaker, **not** a licence to break Claude — Claude-specific files still exist as pointers/mirrors so Claude keeps working (see [AGENT-PLACEMENT], [SKILL-PLACEMENT]). Follow the open Agent Skills standard ([agentskills.io](https://agentskills.io/home)).
6. **Spec IDs are hierarchical descriptive slugs, NEVER numbered.** Format: `[GROUP-TOPIC]` or `[GROUP-TOPIC-DETAIL]`. Uppercase, hyphen-separated, no sequential numbers.

   The first word is the **group**; sections sharing a group MUST appear together in the TOC. Depth varies (`[AUTH-LOGIN]`, `[AUTH-TOKEN-VERIFY]`, `[AUTH-OAUTH-REFRESH-FLOW]`) and MUST mirror heading structure.

   - Good: `[AUTH-LOGIN]`, `[CI-TIMEOUT]`, `[LINT-ESLINT]`, `[FEAT-DARK-MODE]`
   - Bad: `[SPEC-001]`, `[FEAT-AUTH-01]` (numbered), `[TIMEOUT]` (no group)

   **Cross-referencing is mandatory.** Code, tests, and design docs implementing a spec section MUST reference its ID in a comment (`// Implements [AUTH-TOKEN-VERIFY]`). The `spec-check` skill enforces this by grepping for IDs. Descriptive slugs are self-documenting, naturally unique, stable across refactors, and greppable (`[AUTH-` finds every auth section and its implementations).

---

## [MAKE] Universal Makefile Standard

Every repo MUST have a root `Makefile`. The target *names* below are canonical: a
repo uses these names for the concepts that apply to it. It does NOT have to deploy
all of them — only the ones that mean something for this repo. Language-specific work
is delegated internally; when a standard target is present, its name and behaviour
never change.

### [MAKE-CROSS-PLATFORM] Cross-Platform Requirements (Linux, macOS, Windows)

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
- Use `$(RM)` and `$(MKDIR)`, not `rm -rf`/`mkdir -p`. Use forward slashes for paths.
- `dotnet`, `npm`, `gh`, `cargo`, `go`, `flutter`, `dart`, `python`/`pip` are cross-platform — no wrapping needed.
- For commands that can't run on Windows (`launchd`, `cron`, `chmod`, `ln -s`), provide both Unix and Windows variants and dispatch on `$(OS)`.
- The `grep`/`awk`/`jq` coverage parsing in `_coverage_check` is Unix-only. Acceptable because CI runs on Linux; Windows devs use WSL or Git Bash.
- Platform-specific repos (e.g., macOS-only apps) document the limitation at the top of the Makefile but still use OS detection for portable targets.

### [MAKE-TARGETS] Standard Targets (canonical names, applicable subset)

Every Makefile is organised into two sections:

1. **`Standard Targets`** — the portfolio-wide targets below that apply to this repo. Implementations vary per language; the names never do.
2. **`Repo-Specific Targets`** — targets unique to this repo (e.g. `dashboard`, `website-build`, `rebuild-install-vsix`). This section is owned by the repo, not the skill. See [MAKE-REPO-SPECIFIC].

The standard target vocabulary:

| Target | What it does | When to include |
|--------|-------------|-----------------|
| `make test` | Run full test suite **fail-fast** (stop on first failure) **with coverage collection AND threshold enforcement**. See [TEST-RULES]. | Any repo with tests (≈ all). |
| `make lint` | Run all linters/analyzers (read-only). Does NOT format — that's `make fmt`. | Any repo with a linter/analyzer. |
| `make ci` | The local CI simulation: chains whichever of `lint` / `test` / `build` exist. | Any repo with at least one of those. |
| `make fmt` | Format all code in-place | Any repo with a formatter. |
| `make clean` | Delete all build artifacts | Any repo that produces build artifacts. |
| `make build` | Compile/assemble all artifacts | Repos that produce a build artifact. Omit for interpreted/docs-only repos with nothing to compile (don't add an empty no-op). |
| `make setup` | Post-create dev environment setup (devcontainer hook) | Any repo with a devcontainer or non-trivial setup. |

**Rules:**

- **Only deploy the targets that apply.** Do NOT add a target whose body would be empty or a meaningless no-op just to "have all 7". A docs-only repo with nothing to compile has no `build`; a repo with no formatter has no `fmt`. Including a hollow target is a defect, not compliance.
- **Use the canonical name for any concept that has one.** If the repo has the concept, it uses the standard name — never a synonym. No `test-all`, `build-release`, `lint-fix`, `check`, `tidy`: merge those into `test` / `build` / `lint` / `fmt`.
- The `Standard Targets` section contains ONLY standard public targets. Anything else belongs in `Repo-Specific Targets`.
- Internal sub-recipes (`_test_unit`, `_coverage_check`) chain inside standard recipes but MUST be underscore-prefixed and MUST NOT appear in `.PHONY`.
- Agent-pmo-stamped public targets that duplicate a standard concept under a non-standard name are orphans ([MARKER-CLEANUP]). Non-stamped public targets are preserved.

### [MAKE-REPO-SPECIFIC] Repo-Specific Targets are owned by the repo — do not clobber

The `Repo-Specific Targets` section belongs to the repo, not the skill. Most repos
have one, and it sits **after** the agent-pmo standard targets.

- **NEVER delete, rename, reorder, or rewrite a repo-specific target** during remediation just because it isn't in the standard vocabulary. They are intentional.
- **NEVER overwrite the whole Makefile** to "regenerate" it. Edit surgically: add a missing standard target, fix a broken one — leave everything else byte-for-byte.
- The ONLY repo-specific target a skill may touch is one it stamped itself (`# agent-pmo:<sha>`) that has since been orphaned ([MARKER-CLEANUP]).
- If a repo-specific target *shadows* a standard concept under a different name (e.g. `make test-all`), merge its logic into the standard target and remove the shadow — but preserve any unique behaviour. When unsure, leave it and report it for human review rather than deleting.

### [MAKE-IDE-EXT] IDE / Editor Extension Targets

If the repo builds one or more editor extensions (VS Code `.vsix`, Zed, JetBrains
plugin, Sublime, etc.), add **one repo-specific target per extension** that does a
full clean rebuild-and-reinstall cycle. These live in `Repo-Specific Targets`, not
the standard vocabulary.

**Naming:** `rebuild-install-<kind>` — e.g. `rebuild-install-vsix`, `rebuild-install-zed`. One per extension the repo produces; suffix with the extension name if a repo ships several of the same kind.

Each target chains these steps in order (skip a step only if the toolchain has no equivalent):

1. **Uninstall** the currently-installed extension (e.g. `code --uninstall-extension <publisher>.<name>`).
2. **Clean** the extension's build output (delete the packaged artifact + build dir; use `$(RM)`).
3. **Rebuild** the extension from source (compile/bundle).
4. **Package** the extension into its distributable (`vsce package`, `zed extension package`, etc.).
5. **Install** the freshly-packaged artifact **if the toolchain supports local install** (e.g. `code --install-extension <file>.vsix`). If there's no local-install path, stop after packaging and echo where the artifact landed.

Implement the steps as underscore-prefixed sub-recipes (`_vsix_uninstall`, `_vsix_package`, …) chained from the public `rebuild-install-<kind>` target, consistent with [MAKE-TARGETS].

### [MAKE-TEMPLATE] Standard Makefile Template

**File:** [`templates/Makefile`](../../agent-pmo-skill/templates/Makefile)

---

## [CI] CI/CD Standard

### [CI-WORKFLOWS] Required Workflow Files

| File | Trigger | Purpose |
|------|---------|---------|
| `.github/workflows/ci.yml` | **PR to `main` only** | Lint → test → build validation |
| `.github/workflows/release.yml` | **Push tag `v*` only** | Build release artifacts, publish, deploy website |
| `.github/workflows/deploy-pages.yml` | `workflow_dispatch` (triggered by release.yml) | Deploy static site (if applicable) |

**Trigger rules (non-negotiable):**

- **CI runs on PR to the default branch (`main`) only.** That is the gate.
- **Merges/pushes to `main` trigger NOTHING.** No CI, no deploy, no release on a push to `main`. `main` is already-validated code — every commit on it arrived through a green PR. Re-running CI on the merge is wasted runner time. `ci.yml` MUST NOT have `push: branches: [main]`.
  - Exception: if a repo permits commits to `main` *outside* the verified-PR flow, CI MAY also run on push to `main` to catch them. Default is PR-only; add push only with a comment explaining why.
- **Release happens ONLY when a version tag (`v*`) is pushed.** No release on merge to `main`, no release on a schedule. Tag → release. Model repos: **Basilisk, TooManyCooks, Deslop**.
- **The release workflow MUST deploy the website if the repo has one.** `release.yml` triggers `deploy-pages.yml` via `workflow_dispatch` at the release ref, after the GitHub release is created. **Website deploys ONLY on release** — never on push to `main` — so the site never gets ahead of the released artifact. A repo with a website and no website-deploy step in `release.yml` is non-compliant.

### [CI-JOBS] Standard CI Job Names (exact — do not deviate)

All `ci.yml` files MUST use these exact job names:

```
lint      — runs all linters/analyzers (no formatting)
test      — runs all tests + coverage collection
build     — compiles artifacts (depends on test)
```

Optional jobs (exact names):
```
security  — vulnerability scanning (cargo audit, npm audit, etc.)
deploy    — deploy preview/staging (depends on build)
```

### [CI-TEMPLATE] ci.yml Template

**File:** [`templates/.github/workflows/ci.yml`](templates/.github/workflows/ci.yml)

### [CI-RELEASE] release.yml Template

**File:** [`templates/.github/workflows/release.yml`](templates/.github/workflows/release.yml)

Runs on tag push (`v*`) and executes these jobs in order:

1. **version** — extract version from tag and expose the exact tagged source SHA.
2. **build-cross-platform** — check out the tagged SHA, stamp versions in the runner working tree,
   then build platform-independent packages on ubuntu.
3. **build-platform** — check out the tagged SHA, stamp versions in the runner working tree, then
   build platform-specific binaries on their respective OS.
4. **release** — download artifacts, create GitHub release with notes.
5. **publish** — push to registries (npm, NuGet, PyPI, pub.dev, crates.io, VS Code Marketplace). Requires secrets in repo Settings.
6. **deploy-pages** — trigger `deploy-pages.yml` via `workflow_dispatch` at the release ref.

Critical release rules:

- **Release fires ONLY on a version tag push (`v*`).** Never on merge/push to `main`, never on a schedule. Model repos that follow this exactly: **Basilisk, TooManyCooks, Deslop**.
- **If the repo has a website, the release MUST deploy it** (the `deploy-pages` job above). No website-deploy in `release.yml` for a repo that has a site = non-compliant ([CI-WORKFLOWS]).
- Source-controlled deployable versions SHOULD remain a valid placeholder such as `0.0.0-dev`.
- Version stamping MUST be a first-class script or build target that accepts the tag version. Tests
  MUST be able to pass their own semantic version into the same path.
- Tag-triggered releases MUST build the exact source SHA that the tag points at. Do not check out
  `main` in release jobs.
- Release workflows MUST NOT commit, push, or move tags/branches after the tag exists. Stamping is
  a runner-local build step only.
- Stamping MUST update every deployed version carrier: project manifests, package manifests, lock
  files that carry project versions, release manifests, and bundled extension manifests.

### [CI-SHIPWRIGHT] Developer-tool releases — Shipwright audit (CRITICAL)

If the repo ships a developer tool (VS Code `.vsix`, CLI/binary via Homebrew/Scoop/npm/NuGet/PyPI/crates.io, IDE plugin, installer), the agent MUST run the **shipwright-compliance** skill and follow it end to end. It is authoritative for VSIX bundling, manifest, version stamping, and publishing — defending the release path against supply-chain attacks.

- Skill: https://github.com/Nimblesite/Shipwright/blob/main/docs/agents/shipwright-compliance/SKILL.md

### [CI-PAGES] deploy-pages.yml Template

**File:** [`templates/.github/workflows/deploy-pages.yml`](templates/.github/workflows/deploy-pages.yml)

### [CI-DESLOP] Duplication gate — Deslop (CRITICAL, ratcheted)

Code duplication is debt. Every repo whose primary language Deslop supports — **Rust, C#, Dart, Python** (more coming) — MUST run Deslop as a CI gate. Repos in no supported language skip this section. Authoritative docs: https://deslop.live/docs/for-ai/

**The duplication score is STORED and RATCHETED.** It lives in a committed `.deslop.toml` at the repo root — the single source of truth, versioned with the code (PR-reviewable, blamed, revertable), exactly like `coverage-thresholds.json`. **NOT a GitHub variable, NOT a CI env var, NOT a hardcoded number in CI YAML.**

**File:** `.deslop.toml` (repo root):

```toml
[threshold]
# Maximum repo-wide duplication percent. CI runs `deslop .`, which reads this value
# and exits non-zero (deslop exit code 3) the moment measured duplication exceeds it.
max_duplication_percent = 5.0
```

**Ratchet rule — monotonically DECREASING (the inverse of coverage).** Duplication only ever goes down. When a PR reduces duplication, lower `max_duplication_percent` to the new measured value in the SAME PR. **RAISING the threshold is forbidden without explicit written PR justification — the build MUST tank when duplication climbs back up.** Apply a small rounding buffer (round the measured value UP by ~0.1–0.5%) only to absorb cross-runner float jitter, and only when the buffered value is still strictly below the current stored threshold.

**CI wiring.** `ci.yml` installs the pinned Deslop CLI and runs `deslop .` (reads `.deslop.toml`) as a dedicated step after `make lint`. Exit codes: `0` ok, `1` runtime error, `2` usage error, `3` threshold breached (the full report is still written). **Pin the version** — see the [Releases page](https://github.com/Nimblesite/Deslop/releases). Canonical report: `deslop-report.json`, with the repo-wide score at `metrics.duplication_percent`.

**Templates:** [`templates/.deslop.toml`](../../agent-pmo-skill/templates/.deslop.toml) and the Deslop step in [`templates/.github/workflows/ci.yml`](../../agent-pmo-skill/templates/.github/workflows/ci.yml).

**Agent loop — prevention beats cleanup.** Deslop also ships MCP tools the coding agent MUST use before and after editing code. The canonical instruction file MUST state this (see [AGENT] and `templates/AGENTS.md`). The loop:

- **BEFORE authoring** any function, method, class, helper, fixture, or test setup → call the `find-similar` MCP tool. `signals.fused ≥ 0.85` or an `identical`/`nearly_identical` bucket → **reuse the existing code, do not duplicate**; `0.6 ≤ fused < 0.85` → review the canonical occurrence and bias toward reuse; `fused < 0.6` or empty → proceed.
- **AFTER changing code** → `rescan`, then `top-offenders` (worst clusters, by severity) and `cluster-by-id` (full member list + signals for a cluster you plan to merge). Use `report-for-file` / `report-for-range` to surface clusters touching a specific file or selection. Call `schema-doc` once per session to learn the report shape.
- **NEVER silence findings** by widening the threshold, marking code `hidden`, or splitting it into trivially different shapes.

---

## [TEST] Coverage Standards

### [TEST-RULES] Every `make test` is fail-fast AND computes coverage

> ⚠️ **NON-NEGOTIABLE.** ⚠️

Two rules apply to every test target:

1. **FAIL FAST.** The runner MUST stop at the first failing test. Use the runner's native fail-fast flag (table below). Never "run everything, report at the end" — CI minutes are expensive and agents block on the exit.
2. **COVERAGE IS MANDATORY.** `_coverage_check` (reading `coverage-thresholds.json`) runs as the final step of `_test` before `make test` exits. No `--no-coverage` flag, no "tests without coverage" mode.

**Per-language fail-fast flags:**

| Language | Test runner | Fail-fast flag |
|----------|-------------|----------------|
| Rust | `cargo test` | `cargo test -- --fail-fast` (use `--no-fail-fast` ONLY if you know why) |
| Rust (nextest) | `cargo nextest run` | `--fail-fast` (default) |
| TypeScript / Jest | `jest` | `--bail` |
| TypeScript / Vitest | `vitest` | `--bail=1` |
| Python / pytest | `pytest` | `-x` (or `--maxfail=1`) |
| Dart / Flutter | `flutter test` / `dart test` | `--fail-fast` |
| C# / .NET (xUnit) | `dotnet test` | `-- xunit.stopOnFail=true` (or `RunConfiguration.StopOnFail` in `.runsettings`) |
| F# | Same as C# | Same as C# |
| Go | `go test` | `-failfast` |

If a runner has no native fail-fast flag, wrap it in a script that exits non-zero on the first failing test name parsed from output.

**Coverage is part of the same target.** `make test`:
1. Runs tests fail-fast with coverage instrumentation.
2. On success, invokes `_coverage_check` (reads `coverage-thresholds.json` via `jq`) to assert measured ≥ threshold.
3. Exits non-zero if either step fails.

No `make test-no-coverage`, no `make test-fast`. To debug a single test, call the runner directly — that is not a Makefile target.

### [COVERAGE-THRESHOLDS] Thresholds by Repo Type

| Repo type | Line coverage | Branch coverage |
|-----------|--------------|----------------|
| Library / SDK / LSP | 90% | 80% |
| CLI tool | 85% | 75% |
| Application / Service | 80% | 70% |
| VS Code / Zed extension | 80% | 70% |
| Static site / docs only | N/A | N/A |

### [COVERAGE-TOOLS] Coverage Tools by Language

| Language | Tool | Install |
|----------|------|---------|
| Rust | `cargo-llvm-cov` | `cargo install cargo-llvm-cov` |
| TypeScript/Node | `c8` | `npm install -D c8` |
| Python | `pytest-cov` | `pip install pytest-cov` |
| Dart/Flutter | Built-in + `lcov` | `sudo apt-get install lcov` |
| C#/.NET | Coverlet + `reportgenerator` | NuGet in test projects |
| F# | Same as C# | Same as C# |
| Go | Built-in `go tool cover` | Built-in |

### [COVERAGE-THRESHOLDS-JSON] Coverage thresholds live in `coverage-thresholds.json`

Every repo MUST have `coverage-thresholds.json` at the project root (or per sub-project for multi-project repos). **Single source of truth.** The `_coverage_check` recipe reads it; CI calls only `make test`. **No GitHub repo variables, no env-var thresholds, no hardcoded numbers in CI YAML, no public `make coverage-check` target.**

Why a JSON file (not GitHub repo variables): versioned with code (PR-reviewable, blamed, revertable — GH variables are invisible state in Settings with no audit trail); local runs match CI (same file, no `COVERAGE_THRESHOLD=85` env hack); per-project granularity in one file; branch-aware (a PR can ratchet thresholds up alongside coverage improvements).

**File format** (canonical example: `ai_cms/DataProvider/coverage-thresholds.json`):

```json
{
  "default_threshold": 90,
  "projects": {
    "path/to/project-a": {
      "threshold": 88,
      "include": "[Project.A]*,[Project.A.Shared]*"
    },
    "path/to/project-b": {
      "threshold": 75
    }
  }
}
```

- **`default_threshold`** (integer, required): Fallback for projects without an entry; the default for single-project repos.
- **`projects`** (object, optional): Map of project path → `{ "threshold": int, "include": string }`. The `include` field is language-specific (e.g., coverlet assembly filters); omit when not needed.

Single-project repos still create the file with at least `default_threshold`.

**Tests MUST FAIL below threshold.** `_coverage_check` exits non-zero if measured < threshold for any project, making `make test` exit non-zero and blocking the PR. No warning mode, no separate `make coverage-check` target.

**Ratchet rule:** Thresholds are monotonically increasing — never down. When coverage improves, bump the number in the same PR. Lowering a threshold requires explicit PR justification.

**Rounding buffer when bumping:** subtract 1% from measured coverage to absorb floating-point differences across runners/tools (e.g., 92.4% measured → threshold 91, not 92). Prevents flaky failures when one runner reports 91.97% and another 92.01%. Only apply the buffer when the buffered value still strictly exceeds the current threshold.

**Template:** [`templates/coverage-calc/coverage-thresholds.json`](../../agent-pmo-skill/templates/coverage-calc/coverage-thresholds.json)

### [COVERAGE-COVERLET] coverlet.runsettings (C#/.NET)

**File:** [`templates/coverage-calc/coverlet.runsettings`](../../agent-pmo-skill/templates/coverage-calc/coverlet.runsettings)

### [COVERAGE-JEST] jest.coverage.config.js (TypeScript / Jest)

**File:** [`templates/coverage-calc/jest.coverage.config.js`](../../agent-pmo-skill/templates/coverage-calc/jest.coverage.config.js)

---

## [LINT] Linting Standards — Exact Configurations

Turn all rules on and turn them up to error unless there is a comment explaining why the rule should not be turned on.

### [LINT-RUST] Rust — Cargo.toml workspace lints

The basic principle is to turn ALL lints on and turn them up to ERROR. The only exception would be that the existing configuration already has a documented reason NOT to turn the lint run on.

Every Rust workspace Cargo.toml MUST include these lint sections.

**File:** [`templates/linting/cargo-workspace-lints.toml`](templates/linting/cargo-workspace-lints.toml)

### [LINT-RUST-FMT] Rust — rustfmt.toml

**File:** [`templates/linting/rustfmt.toml`](templates/linting/rustfmt.toml)

### [LINT-TS-ESLINT] TypeScript — eslint.config.mjs (flat config, ESLint v9+)

**File:** [`templates/linting/eslint.config.mjs`](templates/linting/eslint.config.mjs)

### [LINT-TS-PRETTIER] TypeScript — .prettierrc.json

**File:** [`templates/linting/.prettierrc.json`](templates/linting/.prettierrc.json)

### [LINT-TS-STRICT] TypeScript — tsconfig.json (strict baseline)

**File:** [`templates/linting/tsconfig.json`](templates/linting/tsconfig.json)

### [LINT-PYTHON-BASILISK] Python — Basilisk is the PRIMARY linter AND type checker

> ⚠️ **Non-negotiable for every Python project.** ⚠️

Basilisk is the mandated primary linter AND type checker for all portfolio Python code. Every Python repo MUST configure Basilisk before any other lint/type-check tool.

**Layer order:**

1. **Basilisk** — primary linter + type checker; source of truth. Configured in `pyproject.toml [tool.basilisk]`. CI MUST fail on any violation. See [Basilisk docs](https://basilisk-python.dev/docs/configuration/).
2. **ruff** — secondary linter + auto-formatter. `pyproject.toml [tool.ruff]` with `select = ["ALL"]`. Also handles `make fmt`.
3. **pyright** — secondary type checker. `pyproject.toml [tool.pyright]`. Safety net under Basilisk.

`make lint` runs Basilisk first; if it fails, ruff and pyright don't run. Forces every project to keep Basilisk green.

**Migration:** for repos with only ruff/pyright/mypy/flake8, add Basilisk ahead of the existing tools. Don't delete the others — they become the secondary layer.

**File:** [`templates/linting/pyproject.toml`](../../agent-pmo-skill/templates/linting/pyproject.toml)

### [LINT-DART] Dart/Flutter — analysis_options.yaml

**File:** [`templates/linting/analysis_options.yaml`](templates/linting/analysis_options.yaml)

### [LINT-GO] Go — .golangci.yml

**File:** [`templates/linting/.golangci.yml`](templates/linting/.golangci.yml)

### [LINT-CSHARP] C# — Static Analysis via Directory.Build.props

Do not add style rules to `.editorconfig` (can destroy formatting). Do add all code analysis rules, especially null safety. If the repo has a rules config file, use it instead.

### [LINT-FSHARP] F# — Analyzer Configuration

F# analyzer rules are configured via project files.

---

## [FMT] Formatting Standards

`make fmt`, `make lint`, and `make test` are three separate, non-overlapping targets:

- **`make fmt`** — format code in-place. Nothing else.
- **`make lint`** — run all linters/analyzers (read-only). Does NOT format or verify formatting.
- **`make test`** — run tests fail-fast with coverage and threshold enforcement.

Do not mix their responsibilities.

### [FMT-TOOLS] Formatting Tools by Language

| Language | Formatter | `_fmt` (format in-place) | `_fmt` check mode (CI verification) |
|----------|-----------|---------------|---------------|
| C# | CSharpier | `dotnet csharpier .` | `dotnet csharpier --check .` |
| F# | Fantomas | `dotnet fantomas .` | `dotnet fantomas --check .` |
| Rust | rustfmt | `cargo fmt --all` | `cargo fmt --all --check` |
| Python | ruff format | `ruff format .` | `ruff format --check .` |
| TypeScript/JavaScript | Prettier | `npx prettier --write .` | `npx prettier --check .` |
| Dart/Flutter | dart format | `dart format .` | `dart format --set-exit-if-changed .` |
| Go | gofmt + goimports | `gofmt -w . && goimports -w .` | `gofmt -l . \| grep . && exit 1 \|\| true` |

### [FMT-PYTHON] Python formatting note

ruff format is the formatter (`make fmt`). `make lint` runs: Basilisk (primary linter + type checker, see [LINT-PYTHON-BASILISK]) → ruff lint → pyright.

### [FMT-MULTI] Multi-language repos

For multi-language repos, `_fmt` chains all formatters and `_lint` chains all linters/analyzers. They do not overlap.

---

## [LOG] Logging Standards

Every repo MUST use structured logging. `print` / `console.log` / `println!` / `Debug.WriteLine` are prohibited for diagnostics.

### [LOG-RULES] Universal Logging Rules

1. **Structured logging library required** ([LOG-LIBS]).
2. **Log at entry/exit of significant operations.** Levels: `error`, `warn`, `info`, `debug`, `trace`.
3. **Structured fields, not string interpolation.** `{ "userId": 42, "action": "checkout" }` not `"User 42 performed checkout"`.
4. **Async I/O sinks.** DB/file log writes MUST be async or background — never block the request/UI thread.
5. **NEVER log PII.** Names, emails, addresses, phone numbers, IPs (unless documented security-audit consent).
6. **NEVER log secrets.** No keys, tokens, passwords, connection strings. To confirm a key is loaded, log a truncated hash or `"API key: present"`.

### [LOG-LIBS] Logging Libraries by Language

| Language | Library | Install |
|----------|---------|---------|
| Rust | `tracing` + `tracing-subscriber` | `cargo add tracing tracing-subscriber` |
| TypeScript/Node | `pino` | `npm install pino` (`pino-pretty` for dev) |
| Python | `structlog` | `pip install structlog` |
| Dart/Flutter | `dart_logging` | `dart pub add dart_logging` |
| C# | `Microsoft.Extensions.Logging` + `Serilog` | NuGet: `Serilog.Extensions.Logging` |
| F# | `Microsoft.Extensions.Logging` + `Serilog` | Same as C# |
| Go | `log/slog` (stdlib) | Built-in (Go 1.21+) |

### [LOG-VSCODE] VS Code Extension Logging

- Detailed structured logs → file in the extension's state folder (`.vsixname/` in workspace root).
- Basic errors/diagnostics → VS Code **Output Channel** (so users see them without hunting for files).
- Both sinks active simultaneously.

### [LOG-SAAS] SaaS / Server Application Logging

- Log to the DB for persistence and queryability (async / background only — never block the request path).
- Also emit structured logs to stdout/stderr for container orchestrators and aggregation services.

### [LOG-CHECKLIST] Repo State Checklist Addition

The [CHECKLIST] checklist gains these items under a new LOGGING section:

```
LOGGING
[ ] Structured logging library installed (per [LOG-LIBS])
[ ] No raw print/console.log/println!/Debug.WriteLine for diagnostics
[ ] Log calls present at entry/exit of significant operations
[ ] VS Code extensions: Output Channel + file logging configured
[ ] SaaS apps: async database logging configured
[ ] No PII or secrets in log output
```

---

## [GITIGNORE] .gitignore Standard

### [GITIGNORE-RULES] What to ignore and what NOT to ignore

**Never ignore** (must be committed and tracked):

| Category | Paths | Reason |
|----------|-------|--------|
| VS Code | `.vscode/` | Settings, extensions, launch configs, title-bar colors — shared dev tooling |
| JetBrains | `.idea/` | Shared run configs and code style settings |
| Claude Code | `.claude/` | Skills and instructions |
| OpenAI Codex | `.codex/`, `.agents/` | Skills and instructions |
| Cline / Roo | `.cline/`, `.clinerules/` | Rules and skills |
| OpenCode | `.opencode/` | Skills and instructions |
| Cursor | `.cursorrules` | Agent rules |
| Windsurf | `.windsurfrules` | Agent rules |
| GitHub Copilot | `.github/copilot-instructions.md` | Agent instructions |
| Agent instruction files | `AGENTS.md`, `CLAUDE.md` | Agent rules — the whole point of this system |

**Do ignore** (build artifacts, secrets, OS junk, tool caches):
- OS noise: `.DS_Store`, `Thumbs.db`, `._*`
- Build output: `target/`, `dist/`, `build/`, `bin/`, `obj/`, `node_modules/`
- Coverage artifacts: `coverage/`, `htmlcov/`, `*.profraw`, `TestResults/`
- Secrets: `.env`, `.env.local`, `*.pem`, `*.key` (but not `*.pub.key`)
- Tool caches: `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `.dart_tool/`

**Principle:** Ignore generated outputs and secrets. Commit config and tooling. When in doubt, don't ignore — a silently hidden file is harder to debug than a committed one.

### [GITIGNORE-BASE] Universal .gitignore base (all repos)

**File:** [`templates/gitignore/universal.gitignore`](templates/gitignore/universal.gitignore)

### [GITIGNORE-LANG] Per-language additions (append to repo .gitignore)

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

## [DEVCONTAINER] Dev Container Standard

### [DEVCONTAINER-FILES] Required files

```
.devcontainer/
├── devcontainer.json     # required
└── Dockerfile            # required if not using a pre-built image
```

### [DEVCONTAINER-TEMPLATES] devcontainer.json templates

| Language | File |
|----------|------|
| Rust | [`templates/devcontainer/rust.devcontainer.json`](templates/devcontainer/rust.devcontainer.json) |
| TypeScript/Node | [`templates/devcontainer/typescript.devcontainer.json`](templates/devcontainer/typescript.devcontainer.json) |
| Python | [`templates/devcontainer/python.devcontainer.json`](templates/devcontainer/python.devcontainer.json) |
| Flutter/Dart | [`templates/devcontainer/flutter.devcontainer.json`](templates/devcontainer/flutter.devcontainer.json) |
| C#/.NET | [`templates/devcontainer/csharp.devcontainer.json`](templates/devcontainer/csharp.devcontainer.json) |
| F# | [`templates/devcontainer/fsharp.devcontainer.json`](templates/devcontainer/fsharp.devcontainer.json) |
| Go | [`templates/devcontainer/go.devcontainer.json`](templates/devcontainer/go.devcontainer.json) |

### [DEVCONTAINER-SETUP] Setup

Dev environment setup is handled by `make setup` (defined in the Makefile). All devcontainer.json templates use `"postCreateCommand": "make setup"`.

---

## [PR-TEMPLATE] PR Template Standard

### [PR-TEMPLATE-FILE] .github/pull_request_template.md

**File:** [`templates/.github/pull_request_template.md`](templates/.github/pull_request_template.md)

---

## [AGENT] Agent Instructions Standard (Agent-Agnostic)

Rules content (hard rules, logging, testing, build commands, architecture) is agent-neutral. The file it lives in depends on the target repo's primary agent.

### [AGENT-DOCS] Critical Reference Documentation

Before touching any agent instruction or skill files, read the official docs for the target agent. Each agent has its own syntax and conventions — do not guess.

The `AGENTS.md` open standard ([agents.md](https://agents.md)) rule: **one file is canonical (holds all rules); every other agent file is a minimal pointer to it.** Identify the canonical file before touching anything, and never duplicate its contents elsewhere.

#### Agent Instruction File Docs

| Agent | Instruction file | Official docs |
|---|---|---|
| Claude Code | `CLAUDE.md` (uses `@file` imports) | https://code.claude.com/docs/en/memory#claude-md-files |
| OpenAI Codex | `AGENTS.md` (walks up directory tree) | https://developers.openai.com/codex/guides/agents-md |
| GitHub Copilot | `.github/copilot-instructions.md` + `AGENTS.md` | https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions |
| Cline / Roo | `.clinerules/*.md` (supports `paths:` frontmatter) | https://docs.cline.bot/customization/cline-rules |
| OpenCode | `AGENTS.md` (falls back to `CLAUDE.md`) | https://opencode.ai/docs/rules/ |

#### Agent Skill Docs

Open standard: [agentskills.io](https://agentskills.io/home) — the vendor-neutral Agent Skills format (`SKILL.md` + generic `.agents/skills/`). Prefer it; agent-specific dirs below are for agents that need their own ([DESIGN] 5a, [SKILL-PLACEMENT]).

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

### [AGENT-TEMPLATE] Canonical Template

**File:** [`templates/AGENTS.md`](templates/AGENTS.md) — contains ALL rules in agent-neutral language, regardless of which agent consumes it.

### [AGENT-CANONICAL] Canonical File Identification (Do This First)

Before placing or modifying any file, identify the canonical file:

| Priority | Condition | Canonical file |
|----------|-----------|----------------|
| 1 | `AGENTS.md` exists with substantial content (>10 lines, not a pointer) | `AGENTS.md` |
| 2 | `CLAUDE.md` exists with substantial content (>10 lines, not a pointer) | `CLAUDE.md` |
| 3 | Neither exists (uninitiated repo) | Create `AGENTS.md` per [AGENT-PLACEMENT] |

For an uninitiated repo (priority 3), default to the generic `AGENTS.md` even when Claude Code is the agent ([DESIGN] 5a). `CLAUDE.md` becomes a pointer that imports it (`@AGENTS.md`), so Claude still works.

If a canonical file exists, **merge into it — never replace**. Preserve existing structure and repo-specific context; cut redundant prose while adding what's missing. The file should get leaner, not longer. All other agent files become pointers.

### [AGENT-PLACEMENT] File Placement Rules

When creating from scratch, **default to the generic `AGENTS.md` as canonical for every agent, including Claude Code** ([DESIGN] 5a). The generic file serves all agents at once; Claude-specific files are pointers, never the source of truth.

| Primary Agent | Canonical file |
|---|---|
| Claude Code | `AGENTS.md` (canonical) + `CLAUDE.md` pointer importing it (`@AGENTS.md`, plus any Claude-specific addendum) |
| Cursor / Cline / Roo / Windsurf / GitHub Copilot / Unknown | `AGENTS.md` |

Keep a `CLAUDE.md` only as a non-canonical artifact if a pre-existing canonical `CLAUDE.md` was detected per [AGENT-CANONICAL] (priority 2) — in that case merge into it, don't fight it.

All non-canonical agent files become pointers to the canonical one.

- When `AGENTS.md` is canonical (the default): `CLAUDE.md` uses `@AGENTS.md` import (plus any Claude-specific addendum); other files point to `AGENTS.md`. `.claude/skills/` is still placed if Claude is used at all — it doesn't interfere with other agents.
- When a pre-existing `CLAUDE.md` is canonical: `AGENTS.md` and all other files point to it.

**Pointer syntax is agent-specific** (use the docs in [AGENT-DOCS]):
- **Claude Code**: `@AGENTS.md` import in `CLAUDE.md`
- **Copilot / Cline / Roo / Cursor / Windsurf**: plain text "read {{CANONICAL_FILE}}" in the respective rules file
- **OpenCode**: `opencode.json` `"instructions"` array references the canonical file

### [AGENT-POINTERS] Pointer Files

Every repo gets pointer files for agents that are NOT primary. Each redirects to the canonical file.

| Agent / Tool | File | Template |
|--------------|------|----------|
| Claude Code | `CLAUDE.md` (pointer when not primary) | [`templates/CLAUDE.md`](templates/CLAUDE.md) |
| Cline / Roo | `.clinerules/00-read-instructions.md` | [`templates/.clinerules/00-read-instructions.md`](templates/.clinerules/00-read-instructions.md) |
| Cursor | `.cursorrules` | [`templates/.cursorrules`](templates/.cursorrules) |
| Windsurf | `.windsurfrules` | [`templates/.windsurfrules`](templates/.windsurfrules) |
| GitHub Copilot | `.github/copilot-instructions.md` | [`templates/.github/copilot-instructions.md`](templates/.github/copilot-instructions.md) |
| OpenCode | `opencode.json` | [`templates/opencode.json`](templates/opencode.json) |

**Rules:**
- NEVER add project rules to pointer files. All rules live in the canonical file.
- Pointer files MUST be minimal — single redirect, no preamble, no copied rules. Strip any existing pointer to the bare minimum.
- New agent tool? Add a pointer file — never a second set of rules.

---

## [SKILL] Skills Standard (Agent-Agnostic)

Skills are portable, on-demand instruction packages following the open Agent Skills standard ([agentskills.io](https://agentskills.io/home)): a folder with a `SKILL.md` (`name` + `description` frontmatter + body). Prefer this vendor-neutral format and the generic `.agents/skills/` location over agent-specific variants ([DESIGN] 5a). Templates in `templates/skills/` use the generic format; convert to the target agent's native format/directory only where the agent requires it.

### [SKILL-DOCS] CRITICAL — Read the target agent's skill docs first

Before placing or converting skill files, read the target agent's official skill docs (see [AGENT-DOCS]). Agents differ on:
- **Directory** (`.claude/skills/`, `.agents/skills/`, `.github/skills/`, `.cline/skills/`, `.opencode/skills/`)
- **Frontmatter** (some require `name` to match directory, some have `compatibility` fields)
- **Size constraints** (Cline: <5000 tokens; others vary)
- **Discovery** (some walk up directories, some only check project root)

### [SKILL-PLACEMENT] Skill placement by agent

| Agent | Primary skill directory | Also scanned |
|---|---|---|
| Claude Code | `.claude/skills/<name>/SKILL.md` | — |
| OpenAI Codex | `.agents/skills/<name>/SKILL.md` | — |
| GitHub Copilot | `.github/skills/<name>/SKILL.md` | `.agents/skills/`, `.claude/skills/` |
| Cline / Roo | `.cline/skills/<name>/SKILL.md` | `.claude/skills/`, `.clinerules/skills/` |
| OpenCode | `.opencode/skills/<name>/SKILL.md` | `.agents/skills/`, `.claude/skills/` |

Placement rules:
1. **Prefer the generic open-standard directory `.agents/skills/`** ([DESIGN] 5a). It is the open Agent Skills location ([agentskills.io](https://agentskills.io/home)) and is scanned by Copilot, Cline, and OpenCode — one copy serves the most agents. Make it the canonical skill home whenever it works.
2. **Claude Code is the exception — it reads ONLY `.claude/skills/`.** So when Claude is used, skills MUST live in `.claude/skills/` too, or Claude can't see them. Preferring generic does NOT mean dropping `.claude/skills/` — that would break Claude. Place skills in `.claude/skills/` for Claude; mirror to / prefer `.agents/skills/` for the rest.
3. **Other primary agents get their native directory** when it isn't `.agents/skills/` (Copilot → `.github/skills/`, etc.).
4. **SKILL.md format is universal.** YAML frontmatter (`name`, `description`) + markdown body, per the open standard. Content is portable.

### [SKILL-INSTALLATION] Install every skill unless clearly irrelevant

**Default: every skill in [`templates/skills/`](../../agent-pmo-skill/templates/skills/) MUST be installed into the target repo.** That directory IS the authoritative skill list. Do NOT hard-code a subset in this spec, in the agent-pmo skill, or anywhere else — always enumerate `templates/skills/` at runtime. New skills appear there and become automatically required; removed skills become orphaned per [MARKER-CLEANUP] and are deleted from target repos.

**Procedure (agent-pmo MUST follow this verbatim):**

1. **List** the immediate subdirectories of `templates/skills/`. Each one is a skill.
2. **For each skill, decide install vs skip** using the criteria below. **Default is install.** The burden of proof is on skipping.
3. **Install** every skill that is not clearly irrelevant, tailoring per [MODES-CUSTOMIZE].
4. **Report** the install/skip decision for EVERY skill in the Step 5 report, with a one-line reason per skip. A silent skip is a bug.

**Skip a skill ONLY when ALL of these hold:**

- The skill is scoped to a capability the repo **clearly does not have** (e.g., `website-audit` in a repo with no website templates, no static site generator, and no deployed site).
- There is no plausible near-future use for it — don't skip just because the capability is rarely used.
- Skipping saves the user real cost — otherwise, install it.

**When in doubt, install.** An unused skill costs nothing; a missing skill means the agent does the wrong thing when the user asks for that capability.

**Examples of valid skips:**

| Skill | Valid skip when... |
|-------|--------------------|
| `website-audit` | Repo has no website, no SSG, no HTML templates, no deployed site. |
| `spec-check` | Repo has no `docs/specs/` and no spec-ID conventions — even then, prefer installing. |
| `upgrade-packages` | Repo has no package manifest at all (rare; usually install anyway). |

**Examples of INVALID skips (do NOT skip for these reasons):**

- "The skill mentions languages the repo doesn't use" — tailor it (strip irrelevant sections), don't skip it.
- "The skill contains a step the repo won't need" — tailor it.
- "The user hasn't asked for this capability yet" — install it; skills are on-demand.
- "The previous run only installed 3 skills" — re-enumerate the templates directory; the spec does not hard-code a list.

**Tailoring (per [MODES-CUSTOMIZE]):**

- **Language-customizable skills** (multi-language examples, e.g., `code-dedup`, `ci-prep`, `upgrade-packages`) — strip sections that don't apply, fill placeholders with repo-specific tool names, Makefile targets, and paths.
- **Content-preserving skills** (step-by-step procedures with URLs and checklists, e.g., `fix-bug`, `spec-check`, `submit-pr`, `website-audit`) — copy the full procedure verbatim. You may add repo-specific context (which site, which directories, which test runners) but never drop, merge, summarize, or rewrite steps, URLs, or checklists.

**Authoritative list:** `ls agent-pmo-skill/templates/skills/` at the standards repo HEAD. That directory IS the required-skills list.

---

## [BRANCH] Branch Strategy Standard

### [BRANCH-DEFAULT] Default branch

All repos: `main` (never `master`)

### [BRANCH-NAMING] Branch naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/[ISSUE]-[slug]` | `feature/42-add-coverage` |
| Bug fix | `fix/[ISSUE]-[slug]` | `fix/17-null-ref` |
| Chore | `chore/[slug]` | `chore/update-deps` |
| Release | `release/[semver]` | `release/1.2.0` |
| Claude agent | `claude/[slug]-[random5]` | `claude/refactor-XYZab` |

### [BRANCH-RULES] Rules

- All changes via PR — no direct pushes to `main`
- CI must pass before merge
- Squash-merge preferred for feature branches
- Delete branch after merge

### [BRANCH-AGENT] Agent git discipline (canonical instruction file MUST state these)

These rules exist because agents reliably get git wrong. The canonical instruction file
([AGENT-TEMPLATE]) MUST carry every one of them, verbatim in intent:

- **NEVER push to the default branch (`main`) directly.** Every change ships through CI on a PR, then merges. The flow is always PR → CI green → merge. No exceptions.
- **NEVER list yourself (the agent) as a commit co-author.** No `Co-Authored-By` trailer, no
  agent attribution in the commit message.
- **Work on exactly ONE branch at a time. Always.** Even when multiple agents work the repo
  concurrently. Reuse the existing feature branch; never open a second.
- **NEVER start a new branch when a feature branch already exists.** Check first; if one is open,
  work on it.
- **If multiple feature branches already exist, merge them into one IMMEDIATELY, before doing any
  other work.** Converge to a single branch first — do not start the task on top of a fragmented
  set of branches.
- **Worktrees are forbidden.** Never run `git worktree`. (Not a judgement on the feature — agents
  consistently corrupt their state with it.)

### [AGENT-AUTONOMY] Autonomous operation (canonical instruction file MUST state this)

The canonical instruction file ([AGENT-TEMPLATE]) MUST direct the agent to operate autonomously:

- **Act autonomously. Do NOT stop to ask the user questions.** When something is ambiguous,
  choose the most reasonable default, record the assumption, and continue to completion.
- **No mid-task pauses for confirmation, clarification, or approval.** Deliver finished work plus
  a short summary of any assumptions made.
- This applies to *instruction files*. A skill MAY still ask up-front scoping questions when the
  repo's purpose is genuinely unclear (e.g. the agent-pmo standards skill) — but once work is
  underway, the autonomy rule governs.

### [AGENT-AUTOMEMORY] Auto-memory OFF in every repo

**Disable the agent's automatic-memory / auto-learning feature in EVERY repo.** Agents that
silently accrete "memories" pollute the repo's instructions with unreviewed, unversioned state.
All durable rules live in the canonical instruction file ([AGENT-TEMPLATE]) and the spec — nowhere
else.

- The agent-pmo skill MUST turn auto-memory off via the agent's own settings file (consult
  [AGENT-DOCS] for the exact key). For **Claude Code**, set `"autoMemoryEnabled": false` in
  `.claude/settings.json` (committed). For other agents, disable the equivalent feature per their docs.
- The canonical instruction file SHOULD state that auto-memory is off and that all persistent rules
  go through a reviewed PR to the instruction file, not auto-captured memory.

---

## [GITHUB-SETTINGS] GitHub Repository Settings

Every repo MUST have these GitHub settings applied. The authoritative reference is [`templates/.github/common-repo-settings.md`](templates/.github/common-repo-settings.md).

### [GITHUB-MERGE] Merge Settings

| Setting | Value |
|---|---|
| Allow squash merge | **true** (only merge strategy allowed) |
| Allow merge commit | **false** |
| Allow rebase merge | **false** |
| Allow auto merge | **true** |
| Delete branch on merge | **true** |
| Squash merge commit title | **PR_TITLE** |
| Squash merge commit message | **PR_BODY** |

### [GITHUB-FEATURES] Features

| Setting | Value |
|---|---|
| Issues | **true** |
| Wiki | **false** |
| Projects | **false** |
| Discussions | **true** (public repos only) |

### [GITHUB-PROTECTION] Branch Protection

**Every repo MUST protect its default branch (`main`).** If no branch protection exists, add a ruleset requiring:
- A PR to `main` — no direct pushes
- The `ci` status check (the job from `ci.yml`, [CI-JOBS]) passes before merge

This is the other half of the trigger model in [CI-WORKFLOWS]: CI runs on the PR, protection makes that green check mandatory to merge, and nothing re-runs on the merge itself.

If protection already exists, leave it alone.

### [GITHUB-CLI] Applying Settings via `gh` CLI

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

## [PKG-SCRIPTS] package.json Scripts Standard (TypeScript/Node repos)

Every `package.json` MUST define these script names.

**File:** [`templates/linting/package-scripts.json`](templates/linting/package-scripts.json)

The Makefile delegates to these. `make lint` calls `npm run lint && npm run fmt:check && npm run typecheck`.

---

## [CHECKLIST] Repo State Assessment Checklist

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
[ ] Skills in agent-native directory ([SKILL-PLACEMENT]: .claude/, .agents/, .github/, .cline/, or .opencode/)
[ ] Every skill in `templates/skills/` installed (enumerate at runtime, install-all unless clearly irrelevant per [SKILL-INSTALLATION])
[ ] All agent-pmo managed files have `agent-pmo:<hash>` marker ([MARKER])
[ ] No orphaned agent-pmo files (marked files whose source template no longer exists)
[ ] .gitignore (comprehensive)
[ ] .prettierrc.json                       (TypeScript repos)
[ ] eslint.config.mjs                      (TypeScript repos)
[ ] rustfmt.toml                           (Rust repos)
[ ] .golangci.yml                          (Go repos)
[ ] analysis_options.yaml                  (Dart/Flutter repos)
[ ] pyproject.toml [tool.ruff]             (Python repos)
[ ] coverlet.runsettings                   (C#/.NET repos)
[ ] coverage-thresholds.json               (every repo — single source of truth, [COVERAGE-THRESHOLDS-JSON])
[ ] .deslop.toml + ci.yml `deslop .` gate   (Rust/C#/Dart/Python repos — stored, ratcheted-down threshold, [CI-DESLOP])
[ ] Canonical instruction file has the Deslop MCP agent-loop section (Rust/C#/Dart/Python repos, [CI-DESLOP])
[ ] Makefile uses canonical names for every standard target that applies; no hollow no-op targets, no synonyms ([MAKE-TARGETS])
[ ] Repo-specific targets (if any) are in a separate `Repo-Specific Targets` section and were left intact ([MAKE-REPO-SPECIFIC])
[ ] Editor extensions (.vsix/Zed/etc.) each have a `rebuild-install-<kind>` target ([MAKE-IDE-EXT])
[ ] Makefile `_lint` runs linters/analyzers only (no formatting)
[ ] Makefile has OS detection block ([MAKE-CROSS-PLATFORM])
[ ] Makefile uses $(RM)/$(MKDIR) instead of rm -rf/mkdir -p
[ ] Makefile internal `_coverage_check` recipe is called from `_test` (not exposed as a public target)
[ ] Canonical instruction file has all required sections (AGENTS.md by default, or CLAUDE.md if pre-existing per [AGENT-PLACEMENT])
[ ] Non-canonical instruction file is a pointer to canonical file ([AGENT-POINTERS])
[ ] Auto-memory disabled ([AGENT-AUTOMEMORY]) — Claude: `"autoMemoryEnabled": false` in `.claude/settings.json`
[ ] .clinerules/00-read-instructions.md (pointer → canonical file)
[ ] .cursorrules (pointer → canonical file)
[ ] .windsurfrules (pointer → canonical file)
[ ] .github/copilot-instructions.md (pointer → canonical file)
[ ] opencode.json (instructions array referencing canonical file)

LOGGING ([LOG])
[ ] Structured logging library installed (per [LOG-LIBS])
[ ] No raw print/console.log/println!/Debug.WriteLine for diagnostics
[ ] Log calls present at entry/exit of significant operations
[ ] VS Code extensions: Output Channel + file logging configured
[ ] SaaS apps: async database logging configured
[ ] No PII or secrets in log output

CI
[ ] ci.yml triggers on PR to `main` ONLY — no `push: branches: [main]` (merges to main trigger nothing) ([CI-WORKFLOWS])
[ ] release.yml triggers on `v*` tag push ONLY — no release on merge/schedule ([CI-WORKFLOWS], [CI-RELEASE])
[ ] release.yml deploys the website if the repo has one ([CI-WORKFLOWS])
[ ] ci.yml has a single `ci` job with sequential steps: `make lint` → `make test` → `make build`
[ ] ci.yml has concurrency cancel-in-progress
[ ] ci.yml: `make lint` runs linters/analyzers only
[ ] ci.yml: `make test` is the ONLY test invocation. It MUST collect coverage AND enforce thresholds from `coverage-thresholds.json`.
[ ] ci.yml: NO `COVERAGE_THRESHOLD` env vars and NO references to GitHub repo variables for thresholds
[ ] ci.yml: artifacts uploaded

COVERAGE
[ ] `coverage-thresholds.json` exists at the repo root (or per sub-project) with `default_threshold` set
[ ] No GitHub repo variables used for coverage thresholds (deprecated — JSON file only)
[ ] No hardcoded `COVERAGE_THRESHOLD` values in `ci.yml`
[ ] Makefile `_coverage_check` target reads `coverage-thresholds.json` and FAILS the build below threshold
[ ] `make test` collects coverage AND enforces the threshold (fails non-zero below)
[ ] `make test` (and every test sub-target) runs the test runner with its fail-fast flag ([TEST-RULES] [TEST-RULES])
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
[ ] Agent git discipline in canonical instruction file ([BRANCH-AGENT]): no direct push to default branch, no agent co-author, exactly one branch at a time, never branch when one exists, merge multiple branches immediately, no worktrees
[ ] Developer-tool repos: Shipwright supply-chain audit run ([CI-SHIPWRIGHT])

GITHUB REPO SETTINGS ([GITHUB-SETTINGS])
[ ] Squash merge only (merge commit and rebase disabled)
[ ] Auto merge enabled
[ ] Delete branch on merge enabled
[ ] Squash commit title = PR_TITLE, message = PR_BODY
[ ] Wiki disabled, Projects disabled, Discussions enabled (public only)
[ ] Branch protection on main (require PR + CI pass)

IDE
[ ] VS Code title bar colorized with project brand colors (.vscode/settings.json workbench.colorCustomizations)
```

---

## [MARKER] File Markers

### [MARKER-FORMAT] Agent-PMO file marker

Every file created or substantively edited by agent-pmo MUST contain a marker near the top (after any shebang, frontmatter, or XML declaration) identifying it as agent-pmo-managed and including the 7-char commit hash of the AgentPMOWorkflow repo at write time.

**Format:** `agent-pmo:<short-hash>` (where `<short-hash>` = `git rev-parse --short HEAD` inside the standards repo).

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

1. Marker MUST appear in the first 10 lines.
2. For files with required headers (shebang, YAML `---`, `<?xml?>`), place the marker immediately after.
3. For SKILL.md files, place it on the line after the closing `---` of the frontmatter.
4. Only stamp files agent-pmo creates or substantively modifies. Don't stamp unchanged files.
5. On re-run, update existing marker hashes to the current commit.
6. **NEVER stamp a file unless its source template/skill exists RIGHT NOW at an exact path in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/`.** Verify by reading the source before stamping. A marker is a provenance claim — stamping without a source is a lie.

### [MARKER-CLEANUP] Orphaned artifact cleanup

Any `agent-pmo:`-stamped artifact (file, Makefile target, CI step) whose source no longer exists in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/` is orphaned.

**Process:**
1. Scan target repo for all `agent-pmo:` markers.
2. Verify each source still exists in the standards repo.
3. If orphaned: merge useful logic into the correct standard artifact (e.g., orphaned Makefile target → the matching standard target), then delete the orphan.
4. If merging is unsafe or purpose unclear, alert the user instead of deleting.
5. Report all handled orphans.

Keeps target repos clean when templates are consolidated or removed upstream (e.g., `fmt`/`lint`/`test` skills → `ci-prep`).

### [MARKER-AUDIT] Provenance auditing

The hash enables traceability: `git log --oneline <hash>..HEAD` in the standards repo shows what changed since stamp. Stale markers (>50 commits behind HEAD) SHOULD be flagged for re-application.

---

## [MODES] Mint vs Remediate Modes

### MINT mode (new repo)

1. Create directory structure.
2. Copy configs from [`templates/`](templates/), substituting `{{REPO_NAME}}`, `{{PRIMARY_LANGUAGE}}`, `{{CANONICAL_FILE}}`.
3. Select devcontainer + Makefile sections for the primary language.
4. Detect primary agent ([AGENT-CANONICAL]) and determine canonical file ([AGENT-PLACEMENT]).
5. Generate canonical instruction file from `templates/AGENTS.md` — **customize all placeholders** for the repo's actual languages, architecture, and purpose. Add Claude-specific skill links to `CLAUDE.md` if Claude is primary.
6. Create all pointer files ([AGENT-POINTERS]) with `{{CANONICAL_FILE}}` filled in.
7. Enumerate `templates/skills/` and install every skill per [SKILL-INSTALLATION], tailoring each per [MODES-CUSTOMIZE]. Skip a skill only if clearly irrelevant to this repo, and report the skip reason.
8. Stamp every created file with `agent-pmo:<hash>` ([MARKER]).
9. Wire `_coverage_check` into `_test` ([TEST-RULES]) and create `coverage-thresholds.json` using [COVERAGE-THRESHOLDS] defaults.
10. Verify `make test` uses the runner's fail-fast flag ([TEST-RULES]).

### REMEDIATE mode (existing repo)

1. Run [CHECKLIST] against the repo.
2. MISSING items: add from [`templates/`](templates/).
3. WRONG items:
   - CI job names wrong → rename to `lint`, `test`, `build`.
   - Makefile uses a synonym for a standard concept (`test-all`, `lint-fix`) → merge into the canonical target, delete the synonym. Leave non-stamped repo-specific targets ALONE — do not delete, reorder, or regenerate them ([MAKE-REPO-SPECIFIC]).
   - Makefile missing a standard target that DOES apply → add it. Do NOT add a target that has nothing to do (no empty `build` on a docs repo) ([MAKE-TARGETS]).
   - Repo builds an editor extension with no `rebuild-install-<kind>` target → add one ([MAKE-IDE-EXT]).
   - `make test` not fail-fast → add the runner's flag ([TEST-RULES]).
   - `make test` not enforcing coverage → call `_coverage_check` from `_test`.
   - `make lint` doing formatting → remove; formatting belongs in `make fmt`.
   - Thresholds in env vars / GH repo variables / hardcoded YAML → migrate to `coverage-thresholds.json` and DELETE the old storage.
   - `.gitignore` missing tool dirs → append standard patterns.
   - Canonical file missing sections → append (detect primary agent first per [AGENT-CANONICAL]).
   - Default branch is `master` → flag for human action (cannot change remotely).
4. When two configs serve the same purpose, merge into the normative file and delete the old one (e.g., `.eslintrc.js` → `eslint.config.mjs`). Don't leave duplicates.
5. Report changes vs. human-action items.

### [MODES-CUSTOMIZE] Template Customization Rule (CRITICAL)

**Templates are STARTING POINTS.** Strip irrelevant languages, fill placeholders, remove unused examples. A generated repo must be ready to go — no leftover references to languages/tools not used.

1. **Skills** fall into two categories:

   **Language-customizable** (`code-dedup`, `ci-prep`, `upgrade-packages`) contain multi-language examples. When applying:
   - Remove language sections that don't apply (Python repo's `code-dedup` mentions only `pyright`/`ruff`/`pytest-cov`).
   - Replace generic file lists with the repo's actual files (Go repo → `go.mod`, not `Cargo.toml`/`package.json`/`pubspec.yaml`).
   - Match tool references to the repo's Makefile targets, CI steps, linter configs.

   **Content-preserving** (`website-audit`, `spec-check`, `submit-pr`, any skill without multi-language examples) contain detailed procedures, checklists, and reference URLs. Customization is limited to filling repo-specific placeholders. **Never change** steps, URLs, validation criteria, tool commands, report formats, numbering, or structure.

   **Test:** diff source vs. output — only repo-specific additions should differ. Missing steps/URLs/instructions = wrong.

2. **Canonical instruction file:** strip non-applicable Hard Rules language sections; fill all `{{placeholders}}` with real project description, architecture, and languages.
3. **Makefile / CI workflows:** keep only the language blocks that apply; delete commented-out ones.
4. **Config files:** only include configs for languages actually present.

**Test:** a dev reading any generated file should see ZERO references to unused languages/tools.

### Substitution variables

| Variable | Value |
|----------|-------|
| `{{REPO_NAME}}` | Repository directory name |
| `{{PRIMARY_LANGUAGE}}` | `rust` / `typescript` / `python` / `dart` / `csharp` / `fsharp` / `go` |
| `{{REPO_TYPE}}` | `library` / `cli` / `application` / `vscode-extension` / `static-site` |
| `{{DESCRIPTION}}` | One-line repo description |
| `{{CANONICAL_FILE}}` | `CLAUDE.md` or `AGENTS.md` (determined by [AGENT-PLACEMENT] agent detection) |

Note: coverage thresholds are NOT substituted into templates — they live in `coverage-thresholds.json` ([COVERAGE-THRESHOLDS-JSON]). Never bake a threshold number into a Makefile, CI workflow, or any other file.

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
├── coverage-calc/
│   ├── coverage-thresholds.json   # Single source of truth for thresholds ([COVERAGE-THRESHOLDS-JSON])
│   ├── coverlet.runsettings
│   └── jest.coverage.config.js
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
