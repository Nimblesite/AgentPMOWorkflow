# {{REPO_NAME}} — Agent Instructions

⚠️ **TOKEN DISCIPLINE.** Check file size first. `Grep` over `Read`. Use `offset`/`limit`. Smallest diff that solves the problem. Delete dead code, unused imports, stale comments. Call out irrelevant context before proceeding. Bloat degrades reasoning. ⚠️

⚠️ **ACT AUTONOMOUSLY. DO NOT STOP TO ASK THE USER QUESTIONS.** When something is ambiguous, pick the most reasonable default, note the assumption, and work to completion. Deliver finished work plus a short summary of any assumptions you made. ⚠️

<!--
TEMPLATE NOTE FOR THE AGENT APPLYING THIS FILE (delete after rendering):
This file is a multi-language STARTING POINT. Before writing it to a target repo:
- Strip every language section, package, mandatory-package list, and table row that
  does not apply to {{languages}}. A Python repo MUST NOT mention Rust, Dart, C#, Go, etc.
- Fill every {{placeholder}} with real content. NO {{...}} tokens in the rendered file.
- Remove the example logging-library rows for languages not used.
- Re-order sections to match the ordering here where reasonable.
- Remove this HTML comment.
- The test: a developer reading the rendered file should see ZERO references to
  languages, tools, or frameworks not used in this repo.
-->

## Project Overview

{{One paragraph describing what this repo is and does.}}

**Primary language(s):** {{languages}}

## Hard Rules — Universal (no exceptions)

- **Git discipline — agents get this wrong, so it is spelled out:**
  - **NEVER push to the default branch (`main`) directly.** Always PR → CI green → merge. No exceptions.
  - **NEVER list yourself as a commit co-author.** No `Co-Authored-By` trailer, no agent attribution.
  - **Work on exactly ONE branch at a time, always** — even with multiple agents working concurrently. Reuse it.
  - **NEVER start a new branch when a feature branch already exists.** Check first; work on the open one.
  - **If multiple feature branches exist, merge them into one IMMEDIATELY before doing any other work.**
  - **Worktrees are forbidden.** Never run `git worktree` — agents consistently corrupt their state with it.
- **Auto-memory is OFF.** Persistent rules go through a reviewed PR to this file — never auto-captured memory. (Claude Code: `"autoMemoryEnabled": false` in committed `.claude/settings.local.json`.)
- **ZERO DUPLICATION.** Search before writing. Move code, don't copy it. Use the Deslop MCP tools before AND after every code change — see **Duplication — Deslop** below.
- **DATA MODELS — generate with typeDiagram, NEVER by hand.** Define every data model (types, DTOs, entities, enums, ADTs) in [typeDiagram](https://typediagram.dev/docs/) and generate the language code from it. The model is the source of truth; the build pipeline regenerates the types via typeDiagram codegen — never edit generated files, never hand-craft a model. If typeDiagram can't express your case, file an issue on its repo instead of hand-rolling. Spec: REPO-STANDARDS-SPEC [MODEL-TYPEDIAGRAM].
- **NO EXCEPTIONS for control flow.** Return `Result<T,E>`. Exceptions are panic-level only.
- **NO REGEX on structured data.** Use real parsers for JSON/YAML/TOML/code.
- **NO PLACEHOLDERS.** Use `todo!()` / `raise NotImplementedError` / `failwith "TODO"` — never silently no-op.
- **Functions < 20 lines. Files < 500 lines.** Refactor when over.
- **Never delete or skip tests. Never remove assertions.** 100% coverage is the goal.
- **Prefer E2E/integration tests.** Unit tests only for isolating problems.
- **Heavy structured logging everywhere.** See Logging below.
- **No linter suppressions.** Fix the code.
- **Pure functions over statements.**
- **Spec IDs are hierarchical, non-numeric: `[GROUP-TOPIC]` / `[GROUP-TOPIC-DETAIL]`** (e.g., `[AUTH-TOKEN-VERIFY]`, `[CI-TIMEOUT]`). Same-group sections sit adjacent in the TOC. NO sequential numbers (`[SPEC-001]`). Code/tests/docs that implement a spec section MUST reference its ID in a comment so `grep [AUTH-` finds spec → code → tests in one shot.

### Git discipline — Only for situations where you've been given the green light to use git

  - **NEVER push to the default branch (`main`) directly.** Always PR → CI green → merge. No exceptions.
  - **Once you open a PR, OWN it until it's green.** Enable auto-merge where allowed (`gh pr merge --auto --squash`) so it lands when checks pass — then keep monitoring: on a failure, pull the logs, fix it, push, and loop until every required check passes. Never hand back a red or still-running PR. (Co-author rule below still applies to fix commits.)
  - **NEVER list yourself as a commit co-author.** No `Co-Authored-By` trailer, no agent attribution.
  - **Work on exactly ONE branch at a time, always** — even with multiple agents working concurrently. Reuse it.
  - **NEVER start a new branch when a feature branch already exists.** Check first; work on the open one.
  - **If multiple feature branches exist, merge them into one IMMEDIATELY before doing any other work.**
  - **Worktrees are forbidden.** Never run `git worktree` — agents consistently corrupt their state with it.
- **Auto-memory is OFF.** Persistent rules go through a reviewed PR to this file — never auto-captured memory. (Claude Code: `"autoMemoryEnabled": false` in committed `.claude/settings.local.json`.)

### Duplication — Deslop (MANDATORY)

Keep this section ONLY if this repo's language is Deslop-supported (Rust, C#, Dart, Python).
Delete it otherwise. Spec: REPO-STANDARDS-SPEC [CI-DESLOP]. Read the [docs](https://deslop.live/docs/for-ai/). If you encounter false positives or other issues, log issues with Deslop [here](https://github.com/Nimblesite/Deslop/issues).

Deslop earns its keep through **prevention, not cleanup.** Use its MCP tools on every code change:

- **BEFORE you author** any function, method, class, helper, fixture, or test setup → call the **`find-similar`** MCP tool.
  - `signals.fused ≥ 0.85`, or an `identical` / `nearly_identical` bucket → **REUSE the existing code. Do NOT write a duplicate.**
  - `0.6 ≤ fused < 0.85` → open the canonical occurrence and bias hard toward reusing/extending it.
  - `fused < 0.6` or empty → proceed and write the new code.
- **AFTER you change code** → call **`rescan`**, then **`top-offenders`** (worst clusters by severity) and **`cluster-by-id`** (full members + signals for a cluster you intend to merge). Use **`report-for-file`** / **`report-for-range`** to inspect a specific file or selection. Call **`schema-doc`** once per session to learn the report shape.
- **NEVER game the gate.** Do not silence findings by widening `max_duplication_percent`, marking code `hidden`, or splitting it into trivially different shapes.

The duplication budget lives in committed `.deslop.toml` (`max_duplication_percent`). CI runs `deslop .` and the build **TANKS** (exit 3) if duplication exceeds it. The threshold ratchets **DOWN only** — lower it in the same PR when you reduce duplication; never raise it without written justification.

## Testing Rules

- **Never delete a failing test.** Fix the code or the expectation.
- **Never skip a test** without a ticket number AND expiry date in the skip reason.
- **`make test` is FAIL-FAST.** Stops at first failing test. Never `--no-fail-fast`. Saves CI minutes; stops agents idling on doomed runs. See REPO-STANDARDS-SPEC [TEST-RULES].
- **`make test` ALWAYS computes coverage AND enforces it.** Threshold lives in `coverage-thresholds.json` at the repo root — NOT env vars, NOT gh repo variables, NOT CI YAML. Below threshold = pipeline fails. Ratchet only. See [COVERAGE-THRESHOLDS-JSON].
- **Meaningful assertions only.** `assert True` / `assert.ok(true)` is illegal.
- **No try/catch in tests that swallows exceptions and asserts success.**
- **Deterministic.** No `sleep()`, no timing dependencies, no random state.
- **E2E tests: black-box only** — public APIs, UI, or CLI. Never reach into internals.
- **VS Code extension E2E:** interact only via `vscode.commands.executeCommand`.

### Logging Standards

- **Structured logging library only.** Never `print`/`console.log`/`println!`/`Debug.WriteLine`. Library per language: Rust `tracing`, TS `pino`, Python `structlog`, Dart `dart_logging`, C#/F# `Microsoft.Extensions.Logging`, Go `log/slog`.
- **Log at entry/exit of significant operations.** Levels: `error|warn|info|debug|trace`. Silent failures are forbidden.
- **Structured fields, not string interpolation.** `{ userId: 42, action: "checkout" }` — never `"user 42 did checkout"`.
- **VS Code extensions:** detailed logs to a file in the extension's state folder (`.vsixname/` in workspace root) AND to the VS Code Output Channel.
- **SaaS / server apps:** persist to database, but database/file writes MUST be async — never block the request path.
- **NEVER log PII** (names, emails, phone, IPs unless audit with consent).
- **NEVER log secrets.** Log `"key: present"` or a truncated hash, never the value.

### Too Many Cooks (Multi-Agent Coordination)

If the TMC server is available: register on start (name, intent, files), lock files before editing, broadcast your plan, check messages periodically, release locks when done. Never edit a locked file — wait or take another approach.

## Hard Rules — Language-Specific

> Keep ONLY the section(s) for the language(s) this repo actually uses. Delete the rest.

### Rust
- No `unwrap()`/`expect()` in production (tests OK for `expect`).
- No `panic!`/`todo!`/`unimplemented!`/`unreachable!` in production.
- No `unsafe {}` or `allow(clippy::...)` without documented justification.
- All public items have `///` doc comments.
- `thiserror` for library errors; `anyhow` only in application code.

### TypeScript
- No `any` (use `unknown` and narrow). No `!` non-null assertion. No `// @ts-ignore`/`@ts-nocheck`.
- No implicit `any` — annotate every parameter and return type.
- No `as Type` casts without a comment explaining safety.
- `tsconfig.json` MUST have `"strict": true`.
- No throwing — return `Result<T,E>` (library or discriminated union).

### Dart/Flutter
- No `late`, no `!`, no `dynamic`, no `as Type` casts (use `is` + smart casts), no `.then()` (use `async`/`await`).
- State management: SUDF only. No Provider/Riverpod/Bloc. Use Signals for complex reactive observability.
- Tests double as integration + widget tests with shared headers — see [this guide](https://www.christianfindlay.com/blog/flutter-integration-tests). Widget tests produce goldens and inject mocks for network calls.
- Unit tests only for isolating issues.

**Mandatory packages:** [dart_logging](https://pub.dev/packages/dart_logging) (logging), [austerity](https://pub.dev/packages/austerity) (lint, in analysis_options), [nadz](https://pub.dev/packages/nadz) (Result<T,E>), [reflux](https://pub.dev/packages/reflux) or [ioc_container](https://pub.dev/packages/ioc_container) (state).

### C# / F#
- No exceptions for control flow — return `Result<T,E>`. No `!` null-forgiving. No `as` casts (use pattern matching). No `dynamic`. Nullable reference types ON everywhere.
- C#: records for immutable data. F#: discriminated unions + pipes + computation expressions.
- Avoid classes. Static methods as pure functions.
- Common packages live in `Directory.Build.props`.

**Mandatory C# packages** (in `Directory.Build.props`): `Microsoft.CodeAnalysis.NetAnalyzers` (analyzers as errors), [Outcome](https://www.nuget.org/packages/Outcome) (Result<T,E>), `Exhaustion` (exhaustive pattern-matching analyzer that ships with Outcome).

### Python
- **Basilisk is the PRIMARY linter AND type checker.** Non-negotiable. Configure `[tool.basilisk]` in `pyproject.toml` and run it FIRST in `make lint` — see [Basilisk docs](https://basilisk-python.dev/docs/configuration/) and REPO-STANDARDS-SPEC [LINT-PYTHON-BASILISK].
- Secondary layer: `[tool.ruff]` (lint + auto-format) and `[tool.pyright]` (type-check safety net).
- No `Any` in annotations. Annotate every parameter and return. No bare `except:`. No global mutable state. Use `Result[T,E]` — never raise.

## Website (if one exists)

**Theme is MANDATORY for dev-tool / docs sites:** build with [`eleventy-plugin-techdoc`](https://github.com/Nimblesite/eleventy-plugin-techdoc) on Eleventy 3.x. Supply only your color CSS variables; the plugin owns layouts, SEO metadata, and structure. Any other theme/SSG is non-compliant. Keep the plugin upgraded.

**Optimise for SEO + AI search.** When writing web content, apply:
- [Succeeding in Google's AI search experiences](https://developers.google.com/search/blog/2025/05/succeeding-in-ai-search)
- [SEO Starter Guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide)

- **CSS LOC BUDGET: 1.5k** by default. For Websites with elaborate sections and function web apps, you can boost this

## Build Commands

Cross-platform GNU Make. On Windows: `choco install make` or use the one in Git for Windows.

**Build command:** `make ci`
**Test command:** `make test`
**Lint command:** `make lint`

```bash
make build   # compile everything
make test    # FAIL-FAST tests + coverage + threshold (ONLY test entry point)
make lint    # all linters/analyzers (no formatting)
make fmt     # format in place
make clean   # remove build artifacts
make ci      # lint + test + build (full CI simulation)
make setup   # post-create dev environment setup
```

These are the **canonical** target names — use only the subset that applies to this repo, and never a synonym (see REPO-STANDARDS-SPEC [MAKE-TARGETS]). Repo-specific targets live in a separate section below the standard ones. `fmt`, `lint`, and `test` never overlap. `make test` runs the test runner with its fail-fast flag, collects coverage, asserts measured ≥ threshold from `coverage-thresholds.json`, and exits non-zero on any failure. To debug a single test, invoke the runner directly — that is not a Makefile target.

## Repo Structure

{{Replace with the actual directory layout for this repo. Show only directories that exist.}}

{{Add repo-specific architecture notes below.}}
