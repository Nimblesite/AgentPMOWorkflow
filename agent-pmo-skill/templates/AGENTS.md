# {{REPO_NAME}} — Agent Instructions

> ⚠️ **TOKEN DISCIPLINE.** Check file size first. `Grep` over `Read`. Use `offset`/`limit`.
> Smallest diff that solves the problem. Delete dead code, unused imports, stale comments.
> Call out irrelevant context before proceeding. Bloat degrades reasoning. ⚠️

> Read this file in full. Rules below are NON-NEGOTIABLE — violations are rejected in review.

<!--
TEMPLATE NOTE FOR THE AGENT APPLYING THIS FILE (delete after rendering):
This file is a multi-language STARTING POINT. Before writing it to a target repo:
- Strip every language section, package, mandatory-package list, and table row that
  does not apply to {{languages}}. A Python repo MUST NOT mention Rust, Dart, C#, Go, etc.
- Fill every {{placeholder}} with real content. NO {{...}} tokens in the rendered file.
- Remove the example logging-library rows for languages not used.
- Remove this HTML comment.
- The test: a developer reading the rendered file should see ZERO references to
  languages, tools, or frameworks not used in this repo.
-->

## Project Overview

{{One paragraph describing what this repo is and does.}}

**Primary language(s):** {{languages}}
**Build command:** `make ci`
**Test command:** `make test`
**Lint command:** `make lint`

## Too Many Cooks (Multi-Agent Coordination)

If the TMC server is available: register on start (name, intent, files), lock files before editing, broadcast your plan, check messages periodically, release locks when done. Never edit a locked file — wait or take another approach.

## Hard Rules — Universal (no exceptions)

- **NO git commands.** No `add`, `commit`, `push`, `checkout`, `merge`, `rebase`, etc. CI handles git.
- **ZERO DUPLICATION.** Search before writing. Move code, don't copy it.
- **NO EXCEPTIONS for control flow.** Return `Result<T,E>`. Exceptions are panic-level only.
- **NO REGEX on structured data.** Use real parsers for JSON/YAML/TOML/code.
- **NO PLACEHOLDERS.** Use `todo!()` / `raise NotImplementedError` / `failwith "TODO"` — never silently no-op.
- **Functions < 20 lines. Files < 500 lines.** Refactor when over.
- **Never delete or skip tests. Never remove assertions.** 100% coverage is the goal.
- **`make test` is FAIL-FAST.** Stops at first failing test. Never `--no-fail-fast`. Saves CI minutes; stops agents idling on doomed runs. See REPO-STANDARDS-SPEC [TEST-RULES].
- **`make test` ALWAYS computes coverage AND enforces it.** Threshold lives in `coverage-thresholds.json` at the repo root — NOT env vars, NOT gh repo variables, NOT CI YAML. Below threshold = pipeline fails. Ratchet only. See [COVERAGE-THRESHOLDS-JSON].
- **Prefer E2E/integration tests.** Unit tests only for isolating problems.
- **Heavy structured logging everywhere.** See Logging below.
- **No linter suppressions.** Fix the code.
- **Pure functions over statements.**
- **Spec IDs are hierarchical, non-numeric: `[GROUP-TOPIC]` / `[GROUP-TOPIC-DETAIL]`** (e.g., `[AUTH-TOKEN-VERIFY]`, `[CI-TIMEOUT]`). Same-group sections sit adjacent in the TOC. NO sequential numbers (`[SPEC-001]`). Code/tests/docs that implement a spec section MUST reference its ID in a comment so `grep [AUTH-` finds spec → code → tests in one shot.

## Logging Standards

- **Structured logging library only.** Never `print`/`console.log`/`println!`/`Debug.WriteLine`. Library per language: Rust `tracing`, TS `pino`, Python `structlog`, Dart `dart_logging`, C#/F# `Microsoft.Extensions.Logging`, Go `log/slog`.
- **Log at entry/exit of significant operations.** Levels: `error|warn|info|debug|trace`. Silent failures are forbidden.
- **Structured fields, not string interpolation.** `{ userId: 42, action: "checkout" }` — never `"user 42 did checkout"`.
- **VS Code extensions:** detailed logs to a file in the extension's state folder (`.vsixname/` in workspace root) AND to the VS Code Output Channel.
- **SaaS / server apps:** persist to database, but database/file writes MUST be async — never block the request path.
- **NEVER log PII** (names, emails, phone, IPs unless audit with consent).
- **NEVER log secrets.** Log `"key: present"` or a truncated hash, never the value.

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

## Testing Rules

- **Never delete a failing test.** Fix the code or the expectation.
- **Never skip a test** without a ticket number AND expiry date in the skip reason.
- **Specific assertions only.** `assert True` / `assert.ok(true)` is illegal.
- **No try/catch in tests that swallows exceptions and asserts success.**
- **Deterministic.** No `sleep()`, no timing dependencies, no random state.
- **E2E tests: black-box only** — public APIs, UI, or CLI. Never reach into internals.
- **VS Code extension E2E:** interact only via `vscode.commands.executeCommand`.

## Website (if one exists)

**Optimise for SEO + AI search.** When writing web content, apply:
- [Succeeding in Google's AI search experiences](https://developers.google.com/search/blog/2025/05/succeeding-in-ai-search)
- [SEO Starter Guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide)

## Build Commands

Cross-platform GNU Make. On Windows: `choco install make` or use the one in Git for Windows.

```bash
make build   # compile everything
make test    # FAIL-FAST tests + coverage + threshold (ONLY test entry point)
make lint    # all linters/analyzers (no formatting)
make fmt     # format in place
make clean   # remove build artifacts
make ci      # lint + test + build (full CI simulation)
make setup   # post-create dev environment setup
```

**There are exactly 7 targets. No others.** `make test` runs the test runner with its fail-fast flag, collects coverage, asserts measured ≥ threshold from `coverage-thresholds.json`, and exits non-zero on any failure. To debug a single test, invoke the runner directly — that is not a Makefile target.

**`make fmt`** formats code in-place. **`make lint`** runs linters/analyzers (read-only, no formatting). **`make test`** runs tests with coverage. Three separate targets — no overlap.

## Repo Structure

{{Replace with the actual directory layout for this repo. Show only directories that exist.}}

{{Add repo-specific architecture notes below.}}
