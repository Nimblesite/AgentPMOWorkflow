---
name: code-dedup
description: Searches for duplicate code, duplicate tests, and dead code, then safely merges or removes them. Use when the user says "deduplicate", "find duplicates", "remove dead code", "DRY up", or "code dedup". Requires test coverage — refuses to touch untested code.
---

# Code Dedup

Carefully search for duplicate code, duplicate tests, and dead code across the repo. Merge duplicates and delete dead code — but only when test coverage proves the change is safe.

## Prerequisites — hard gate

Before touching ANY code, verify these conditions. If any fail, stop and report why.

1. Run `make test` — all tests must pass. If tests fail, stop. Do not dedup a broken codebase.
2. Run `make test` — tests are fail-fast AND enforce the coverage threshold from `coverage-thresholds.json`. If anything fails, stop and fix it before deduping.
3. Verify the project uses **static typing**. Check for:
   - Rust, Go, C#, F#, Dart, Java, Kotlin: typed by default — proceed
   - TypeScript: `tsconfig.json` must have `"strict": true` — proceed
   - Python: must have **Basilisk** configured as the primary type checker in `pyproject.toml [tool.basilisk]` (per REPO-STANDARDS-SPEC [LINT-PYTHON-BASILISK]). pyright is acceptable as a secondary check but Basilisk is the primary requirement.
   - **Untyped JavaScript or untyped Python: STOP. Refuse to dedup.** Print: "This codebase has no static type checking. Deduplication without types is reckless — too high a risk of silent breakage. Add type checking first."
4. **Confirm the deslop MCP server is available** (see "Required tooling" below). Eyeball-grepping for duplicates is forbidden when deslop is available — it produces a structured cluster report with stable IDs, scores, and byte ranges, and that report is the source of truth for Steps 3 and 4. If deslop is unavailable AND the project's primary language is one deslop supports (`csharp`, `rust`, `python`), STOP and tell the user to install/start deslop before continuing. If the primary language is unsupported by deslop, see the fallback rule under "Required tooling".

## Required tooling — the deslop MCP server

This skill is built around the **deslop** MCP server. It is MANDATORY for Steps 3 (duplicate code) and 4 (duplicate tests). Do not substitute grep, manual inspection, or another tool when deslop is available.

**Supported languages:** `csharp`, `rust`, `python`. Deslop's `language` filter accepts only those three. For projects in other languages (Dart, TypeScript, Go, Java, F#, etc.) deslop's clustering is not currently available; you MUST report this limitation up front rather than pretending you ran a real duplicate scan. Fall back to careful symbol-level grep and analyzer output, and clearly label the scan as "best-effort, no deslop".

**Canonical workflow** — call these tools in order, in this exact sequence:

1. `mcp__deslop__session-config` — confirm the server is up, get the workspace root and the configured `min-nodes`. If this errors, treat deslop as unavailable.
2. `mcp__deslop__rescan` (with `n=20`, `max_occurrences=60`) — force a fresh index of the latest LSP state and return the top duplicate clusters. Use this first to defeat watcher lag.
3. `mcp__deslop__top-offenders` — pull the worst clusters with full data. Tune `n` and `max_occurrences` to fit the context window. This is the primary input to Step 3.
4. `mcp__deslop__report-query` — drill down with AND-filters: `language`, `bucket` (`identical` / `nearly_identical` / `loosely_similar` / `same_behavior`), `path_contains` (e.g. `tests` for Step 4), `min_score`, `min_size`. Paginate via `offset`/`limit`.
5. `mcp__deslop__cluster-by-id` — fetch the full record for any cluster ID surfaced by the above (cluster IDs also appear in LSP diagnostics).
6. `mcp__deslop__report-for-file` / `mcp__deslop__report-for-range` — when narrowing in on a specific file or byte range during merge planning.
7. `mcp__deslop__find-similar` — **call this BEFORE writing any replacement code** during Step 5. Pass either a `path` + `start_byte`/`end_byte` of the about-to-be-introduced block, or a `snippet`. If it returns a cluster, reuse the canonical instead of adding a new clone.
8. After each merge or deletion in Step 5, call `mcp__deslop__rescan` again to confirm the cluster you just attacked is gone (and that you didn't create a new one). The generation counter on `session-config` should advance.

**Bucket interpretation:** `identical` > `nearly_identical` > `loosely_similar` > `same_behavior`. Attack `identical` first — those are pure copy-paste and the safest to merge. `same_behavior` clusters need human judgement; do not merge them without re-reading both occurrences in full.

**Rule:** every cluster you act on in Steps 3, 4, and 5 MUST be referenced in the final report by its deslop cluster ID, score, and the bucket it came from. No anonymous "I found some duplicates" reports.

## Steps

Copy this checklist and track progress:

```
Dedup Progress:
- [ ] Step 1: Prerequisites passed (tests green, coverage met, typed, deslop confirmed available or fallback declared)
- [ ] Step 2: Dead code scan complete
- [ ] Step 3: Duplicate code scan complete via deslop (top-offenders + report-query)
- [ ] Step 4: Duplicate test scan complete via deslop (path_contains="test")
- [ ] Step 5: Changes applied — each merge preceded by find-similar, followed by rescan
- [ ] Step 6: Verification passed (tests green, coverage stable, deslop rescan confirms targeted clusters gone)
```

### Step 1 — Inventory test coverage

Before deciding what to touch, understand what is tested.

1. Run `make test` to confirm green baseline. `make test` is fail-fast AND enforces the coverage threshold from `coverage-thresholds.json` (REPO-STANDARDS-SPEC [TEST-RULES], [COVERAGE-THRESHOLDS-JSON]). It exits non-zero on any test failure OR coverage shortfall.
2. Note the current coverage percentage — this is the floor. It must not drop.
3. Identify which files/modules have coverage and which do not. Only files WITH coverage are candidates for dedup.

### Step 2 — Scan for dead code

Search for code that is never called, never imported, never referenced.

1. Look for unused exports, unused functions, unused classes, unused variables
2. Use language-appropriate tools where available:
   - Rust: the compiler already warns on dead code — check `make lint` output
   - TypeScript: check for `noUnusedLocals`/`noUnusedParameters` in tsconfig, look for unexported functions with zero references
   - Python: look for functions/classes with zero imports across the codebase
   - C#/F#: analyzer warnings for unused members
   - Go: the compiler already catches unused imports/variables
   - Dart: analyzer warnings for unused elements
3. For each candidate: **grep the entire codebase** for references (including tests, scripts, configs). Only mark as dead if truly zero references.
4. List all dead code found with file paths and line numbers. Do NOT delete yet.

### Step 3 — Scan for duplicate code (deslop-driven)

This step is **driven by the deslop MCP server**, not by grep or by reading files looking for similar shapes. Eyeballing is forbidden when deslop is available.

1. `mcp__deslop__rescan { n: 20, max_occurrences: 60 }` — fresh index + worst clusters.
2. `mcp__deslop__top-offenders { n: 10, max_occurrences: 60 }` — full data for the worst 10. Note each cluster's `id`, `score`, `bucket`, `canonical_node_count`, and occurrence paths.
3. `mcp__deslop__report-query { bucket: "identical", offset: 0, limit: 50 }` — list every `identical` cluster (these are the safest to merge). Repeat with `nearly_identical`, then `loosely_similar`. Skip `same_behavior` here — it needs human judgement; handle in Step 5 only on explicit user request.
4. For each cluster you intend to act on:
   - `mcp__deslop__cluster-by-id { id: "<id>" }` to fetch the full record.
   - Read each occurrence with Read + the byte ranges from the cluster record (NOT a re-scan with grep).
   - Confirm the occurrences really do the same thing — deslop measures structural similarity, not semantic equivalence. If they differ on a subtle condition or default, leave them alone and note "false positive, occurrences differ on X".
5. Record the candidate list as `{ cluster_id, bucket, score, occurrences[], decision (merge / leave / unsure), rationale }`. Do NOT merge yet.

**Fallback (deslop language unsupported):** if deslop's `language` filter doesn't cover this repo's primary language, state that up front in the report and run a best-effort scan: use the language's analyzer (e.g. `dart analyze`, `tsc --noEmit`), then symbol-level grep for repeated function/method bodies. Flag every finding as `(no-deslop fallback)` so the user knows the scan was weaker than usual.

### Step 4 — Scan for duplicate tests (deslop-driven)

Same as Step 3 but filtered to test code.

1. `mcp__deslop__report-query { path_contains: "test", bucket: "identical", offset: 0, limit: 50 }` — start with identical clusters whose occurrences live in test paths. Repeat with `path_contains: "spec"`, `"Tests"`, `"_test"` if the repo uses those conventions.
2. For each test cluster: pull it with `cluster-by-id`, read the occurrences, decide which test is the more thorough one (the integration / whole-app test wins per CLAUDE.md if the project has that rule).
3. Also flag test fixtures and helpers that show up in `path_contains: "test"` clusters but are utility code — those are dedup candidates for Step 5b, not Step 5c.
4. Record the candidate list. Do NOT delete yet.

**Fallback applies here too** — if deslop doesn't speak the project's language, declare the fallback and use the best-effort path.

### Step 5 — Apply changes (one at a time)

For each change, follow this cycle: **change → test → verify coverage → continue or revert**.

#### 5a. Remove dead code
- Delete dead code identified in Step 2
- After each deletion: run `make test` (fail-fast + coverage + threshold all in one)
- If `make test` exits non-zero (test failure OR coverage drop): **revert immediately** and investigate
- Dead code removal should never break tests or drop coverage

#### 5b. Merge duplicate code (one cluster at a time, deslop-gated)
- Pick ONE cluster from the Step 3 candidate list (start with the worst `identical` cluster).
- **Before writing the replacement,** call `mcp__deslop__find-similar` with either the snippet you're about to introduce or the `path` + `start_byte`/`end_byte` of the canonical occurrence. If it returns a cluster you didn't expect, reuse that cluster's canonical instead of adding a new shared function.
- Extract the shared logic into a single function/module. Update all call sites to use the shared version.
- Run `make test`.
- If tests fail: **revert immediately**. The occurrences had subtle semantic differences deslop's structural similarity didn't catch.
- If coverage drops: the shared code must have equivalent test coverage. Add tests if needed before proceeding.
- Call `mcp__deslop__rescan { paths: ["<files-you-touched>"] }`. Confirm the cluster ID is gone (or its occurrence count dropped to ≤ 1) and that you didn't create a new cluster. If a new cluster appeared, revert.

#### 5c. Remove duplicate tests (deslop-gated)
- Pick ONE test cluster from the Step 4 candidate list.
- Delete the redundant test (keep the more thorough one).
- Run `make test`. If coverage drops below threshold, `make test` exits non-zero — **revert immediately**. The "duplicate" test was covering something the other wasn't.
- Call `mcp__deslop__rescan` and confirm the cluster is gone.

### Step 6 — Final verification

1. Run `make lint` — all linters and the format check must pass.
2. Run `make test` — tests must pass AND coverage must remain ≥ the baseline from Step 1.
3. Final `mcp__deslop__rescan { n: 20, max_occurrences: 60 }` — confirm every cluster ID you acted on has been resolved, and that the top-offender list is shorter than at the start of Step 3.
4. Report: list every deslop cluster ID acted on, the bucket, the score, the occurrences merged/deleted, and the new top-offenders list. Include final coverage vs baseline.

(Only the 7 standard targets exist — `make lint` and `make test` cover formatting and coverage checks respectively.)

## Rules

- **Deslop is mandatory when supported.** For `csharp`, `rust`, and `python` projects the deslop MCP server IS the duplicate scanner. Do not substitute grep, manual reading, or another tool. Every cluster acted on must be cited by its deslop cluster ID, bucket, and score in the final report. If deslop is unreachable, STOP and ask the user to start it.
- **Deslop unsupported language = best-effort scan, declared up front.** If the project's primary language isn't `csharp`/`rust`/`python`, say so in the first message of the report and label every finding as `(no-deslop fallback)`. Never pretend a structural scan ran.
- **No test coverage = do not touch.** If a file has no tests covering it, leave it alone entirely. You cannot safely dedup what you cannot verify.
- **Coverage must not drop.** If removing or merging code causes coverage to decrease, revert and investigate. The coverage floor from Step 1 is sacred.
- **Untyped code = refuse to dedup.** Untyped JS or untyped Python is too dangerous. Types are the safety net that catches breakage at compile time. Without them, silent runtime errors are near-certain.
- **One change at a time.** Make one dedup change, run tests, verify coverage. Never batch multiple dedup changes before testing.
- **When in doubt, leave it.** If two code blocks look similar but you're not 100% sure they're functionally identical, leave both. False dedup is worse than duplication.
- **Preserve public API surface.** Do not change function signatures, class names, or module exports that external code depends on. Internal refactoring only.
- **Three similar lines is fine.** Do not create abstractions for trivial duplication. The cure must not be worse than the disease. Only dedup when the shared logic is substantial (>10 lines) or when there are 3+ copies.
