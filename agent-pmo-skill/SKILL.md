---
name: agent-pmo
description: Apply portfolio-wide repository standards (Makefile, CI, linting, coverage) to a new or existing repo. Use when user says "enforce standards", "fix repo", "make compliant", "set up repo", or "apply repo standards". Reads the authoritative spec and creates/updates config files. NEVER commits or pushes.
disable-model-invocation: true
---

> **Portable skill.** This skill adapts to the current repository. The agent MUST inspect the repo structure and use judgment to apply these instructions appropriately.

# Enforce Repository Standards

This skill is a **process wrapper around the spec**. The spec is authoritative for every rule, table, config file, command, and threshold. This file tells you the order of operations, what to inspect in the target repo, and what decisions to make. **Do not duplicate spec content here — point to the relevant spec ID and read it.**

- **Spec:** `{{STANDARDS_REPO}}/docs/specs/REPO-STANDARDS-SPEC.md`
- **Templates:** `{{STANDARDS_REPO}}/agent-pmo-skill/templates/`

If the paths above do not exist, report an error and stop. Do not search the filesystem or guess paths.

**NEVER run `git commit`, `git push`, or any git write command.** Read-only git commands (status, log, diff) are fine.

## How to use this skill

1. Read the spec. When a step references a spec ID (e.g. `[MAKE-TARGETS]`), open that section and follow it. The spec contains the rules; this file is the workflow.
2. Before touching files, read the universal rules below — they apply to every step.
3. Execute Steps 1–5 in order.

## Universal rules (apply to EVERY step)

- **Token discipline.** Try to be economical with token usage while carrying out this skill.
- **Merge, don't clobber.** If a compliant equivalent exists → leave it. If an equivalent exists under a wrong name → rename/update in place. Only create from scratch if nothing equivalent exists.
- **No duplicates.** The target repo must not end up with two files serving the same purpose. Rename or delete the old one.
- **Templates are starting points, not copy-paste targets.** See spec [MODES-CUSTOMIZE]. Strip every language/tool section that does not apply. Fill every `{{placeholder}}`. Zero irrelevant content in the output.
- **Stamp every file you create or substantively modify** with `agent-pmo:<hash>` per spec [MARKER] / [MARKER-FORMAT]. Get the hash with `git -C "{{STANDARDS_REPO}}" rev-parse --short HEAD`.
- **Never stamp a file whose source does not exist in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/`.** Verify by reading the source first. Applies especially to skills — list `templates/skills/` and only create what is actually there.
- **Never run git write commands.** Read-only git is fine.

## Instructions

### Step 1 — Read the spec and detect context

1. Read `{{STANDARDS_REPO}}/docs/specs/REPO-STANDARDS-SPEC.md`. All file contents, configs, CI workflows, and commands come from the spec. Do not improvise.
2. Detect languages from build files (`Cargo.toml`, `package.json`, `pubspec.yaml`, `*.csproj`/`*.fsproj`/`*.sln`, `go.mod`, `pyproject.toml`, `setup.py`, `requirements.txt`).
3. Determine repo type (library, CLI, app/service, extension, static site) for the coverage threshold per spec [COVERAGE-THRESHOLDS]. Default 90%.
4. **Identify the canonical instruction file** per spec [AGENT-CANONICAL] and [AGENT-PLACEMENT]:
   - `AGENTS.md` with substantial content (>10 lines, not a pointer) → canonical.
   - Else `CLAUDE.md` with substantial content → canonical.
   - Else create one from `templates/AGENTS.md`: Claude Code → `CLAUDE.md`; all others → `AGENTS.md`.
5. Read the target agent's official docs (spec [AGENT-DOCS]) before touching instruction/skill files. Syntax and placement differ per agent.

### Step 2 — Audit existing artifacts

Before creating anything, **inventory what already exists** so Step 3 can merge instead of duplicate.

For each area below, record: what exists, what's missing, what's under a wrong name, what duplicates a standard artifact.

- **2a. Docs folder.** Look for `docs/` (standard) or variants `doco/`, `documentation/`, `doc/`, `documents/`. Check for `docs/specs/` and `docs/plans/` subdirs. Flag loose markdown files in `docs/` for classification.
- **2b. CI workflows.** List `.github/workflows/*.yml`. Identify any existing workflow that does what `ci.yml`/`release.yml`/`deploy-pages.yml` should do, under any filename. Per spec [CI-WORKFLOWS] / [CI-JOBS] these will be renamed in Step 3, not re-created.
- **2c. Makefile.** If present, read in full. Classify every public target per spec [MAKE-TARGETS]:
  - (i) One of the 7 standard targets → note whether present/missing/wrongly-implemented.
  - (ii) Duplicates/shadows a standard target (e.g. `test-all`, `lint-fix`, `build-release`) → candidate for merge+delete.
  - (iii) Agent-pmo-stamped but source no longer in standards repo → orphan per [MARKER-CLEANUP].
  - (iv) Genuine repo-specific target → belongs in `Repo-Specific Targets` section, preserved.
  Flag cross-platform violations ([MAKE-CROSS-PLATFORM]): raw `rm -rf`/`mkdir -p` instead of `$(RM)`/`$(MKDIR)`. If a `justfile`/`Taskfile.yml` is used instead, ask the user before replacing.
- **2d. Linter configs.** Look for legacy/alternate-name configs per spec [LINT]. ESLint v0-v8 files → `eslint.config.mjs`. Old Prettier variants → `.prettierrc.json`. Python `.flake8`/`setup.cfg`/`tox.ini` → Basilisk+ruff+pyright ([LINT-PYTHON-BASILISK]). `.golangci.yaml` → `.golangci.yml`. Migrating means **delete the old file** once the new one covers it.
- **2e. Formatter configs.** Check CSharpier, Fantomas, Prettier, rustfmt, ruff format per spec [FMT] / [FMT-TOOLS]. `[tool.black]` in pyproject → migrate to `[tool.ruff.format]`.
- **2f. Coverage.** Check for `coverage-thresholds.json` at repo root (spec [COVERAGE-THRESHOLDS-JSON]). Flag any legacy threshold storage for migration:
  - `vars.COVERAGE_THRESHOLD*` in workflows
  - `COVERAGE_THRESHOLD ?= …` in Makefile
  - Hardcoded numbers in CI YAML (`--lines 90`, `--fail-under 85`)
  - `gh variable list 2>/dev/null | grep -i COVERAGE`
  - Shell scripts (`scripts/check_coverage.sh`, etc.) — replaced by the `_coverage_check` Make recipe
  - `.coveragerc` vs `pyproject.toml [tool.coverage]` — don't have both
- **2g. Gitignore.** Read existing `.gitignore` in full. Per spec [GITIGNORE], add only clearly-safe patterns (OS junk, build artifacts, secrets, tooling noise). **Err on the side of adding fewer patterns** — ignoring something the repo intentionally tracks can silently hide work. Do not duplicate or replace.
- **2h. LICENSE.** Check for `LICENSE`/`LICENSE.md`/`LICENSE.txt`/`LICENCE`/`COPYING`/`UNLICENSE`. If missing, record for the Step 5 big warning. **Do NOT create one** — license choice has legal consequences and must be the user's decision.
- **2i. GitHub repo settings.** Run `gh api repos/OWNER/REPO`. If `gh` is unavailable/unauthenticated/returns nulls, STOP and emit the warning below verbatim, then wait for explicit YES/NO:

  ```
  ╔══════════════════════════════════════════════════════════════════╗
  ║  ⚠️  WARNING: GitHub repo settings COULD NOT BE READ  ⚠️        ║
  ╠══════════════════════════════════════════════════════════════════╣
  ║  `gh api` failed or returned no data. This matters because:      ║
  ║                                                                   ║
  ║  1. CI WORKFLOW: squash-only vs merge-commit affects how         ║
  ║     ci.yml must be configured (branch triggers, merge checks).   ║
  ║                                                                   ║
  ║  2. REPO NORMALIZATION: merge strategy, branch protection,       ║
  ║     PR settings, and issue/wiki toggles CANNOT be applied        ║
  ║     without `gh` access. The repo will be left in whatever       ║
  ║     state GitHub currently has it in.                            ║
  ║                                                                   ║
  ║  To fix: run `gh auth login` then re-run this skill.             ║
  ╚══════════════════════════════════════════════════════════════════╝

  Do you want to continue WITHOUT applying GitHub repo settings?
  Answering YES means CI workflow assumptions may be wrong and repo
  settings will NOT be normalized.

  → Type YES to continue anyway, or NO to abort and fix gh access first.
  ```

  - NO → stop. Tell the user to run `gh auth login` and re-invoke.
  - YES → note "GitHub settings skipped — gh unavailable" in the Step 5 report and continue.
  - If `gh` works → compare against `{{STANDARDS_REPO}}/agent-pmo-skill/templates/.github/common-repo-settings.md` and only apply the diffs.

### Step 3 — Apply standards (merge-first, DO NOT commit/push)

For every item: (1) compliant equivalent exists → leave alone; (2) equivalent exists under wrong name/content → rename/update in place; (3) nothing equivalent → create from template.

- **3a. Docs folder.** Rename `doco/`/`documentation/`/`doc/`/`documents/` → `docs/`. Merge if both exist, then delete the non-standard one. Create `docs/specs/` and `docs/plans/`. Classify loose markdown files: specs = behavior/requirements; plans = how-to with TODO checklists. Update internal references that pointed to the old folder name.
- **3a-ii. Spec ID rule.** Ensure the rule is present in the canonical instruction file. Validation/renaming of existing spec IDs is the `spec-check` skill's job, not this one.
- **3b. Makefile.** Per spec [MAKE-TARGETS] and [MAKE-TEMPLATE]. The Makefile has two sections:
  - `Standard Targets` — the 7 fixed targets (`build`, `test`, `lint`, `fmt`, `clean`, `ci`, `setup`). No substitutions, no extras allowed here.
  - `Repo-Specific Targets` — a separate section below, varies per repo, **preserved**.

  Act on the Step 2c classification:
  - (i) missing/wrong standard target → add/fix in `Standard Targets`.
  - (ii) duplicate of a standard target → merge useful logic into the standard target, delete the duplicate, update callers.
  - (iii) orphan → [MARKER-CLEANUP]: merge useful logic into the correct standard target, delete the orphan.
  - (iv) genuine repo-specific target in the wrong place → move it down into `Repo-Specific Targets`. Do not delete. Do not "tidy up".

  Other rules from the spec: cross-platform ([MAKE-CROSS-PLATFORM]); `_lint` and `_fmt` do not overlap; `_test` uses the fail-fast flag AND calls `_coverage_check` last ([TEST-RULES]); uncomment only the language blocks that apply.
- **3c. GitHub Actions workflows.** Rename the existing workflow from Step 2b rather than creating a parallel one. Follow spec [CI-WORKFLOWS], [CI-JOBS], [CI-TEMPLATE], [CI-RELEASE], [CI-PAGES]. Default to a single `ci` job with sequential steps `make lint → make test → make build`; only split into parallel jobs if individual tasks are 5+ minutes each. **Every job MUST have `timeout-minutes: 10`** — deviate only with a comment above explaining why:
  ```yaml
  # TIMEOUT EXCEPTION: Full integration test suite against live staging env requires ~15 min
  timeout-minutes: 15
  ```
- **3d. Coverage.** Read spec [TEST] in full before doing anything here. `make test` = fail-fast + coverage + threshold, one indivisible operation. Thresholds ONLY in `coverage-thresholds.json` per [COVERAGE-THRESHOLDS-JSON].

  This skill must:
  - Create `coverage-thresholds.json` at the repo root from `templates/coverage-calc/coverage-thresholds.json`. Set `default_threshold` per [COVERAGE-THRESHOLDS]. For multi-project repos, list each project with its **currently measured** threshold (ratchet from measured — never above).
  - Migrate every legacy threshold storage found in Step 2f into the JSON. Delete the old storage (env blocks, Makefile defaults, shell scripts, public `coverage*` targets). For GitHub repo variables, instruct the user to delete them from Settings → Variables → Actions (this skill can't delete them).
  - Wire `_coverage_check` into `_test`. Keep it private — it is never a public target. Reference the language-specific commented blocks in `templates/Makefile`.
  - Verify `ci.yml` has NO `coverage-check`/`coverage` step and NO `COVERAGE_THRESHOLD` env vars. The workflow just calls `make lint`, `make test`, `make build`.
  - .NET: `coverlet.runsettings` per [COVERAGE-COVERLET]. Python: `pyproject.toml [tool.coverage]` only (no `.coveragerc`). TypeScript/Jest: [COVERAGE-JEST].
  - Thresholds are monotonically increasing. Reject PRs that lower a threshold unless explicitly justified.
- **3e. Linter configs.** Apply spec [LINT] and the per-language sections ([LINT-RUST], [LINT-TS-ESLINT], [LINT-TS-PRETTIER], [LINT-TS-STRICT], [LINT-PYTHON-BASILISK], [LINT-DART], [LINT-GO], [LINT-CSHARP], [LINT-FSHARP]). Merge into existing `pyproject.toml`/`Cargo.toml`/`tsconfig.json` — don't clobber non-lint sections. Delete superseded files (`.eslintrc.*`, `.flake8`, `setup.cfg [flake8]`, `.golangci.yaml`, etc.) after migration.
- **3f. Formatting.** Apply spec [FMT] / [FMT-TOOLS] / [FMT-PYTHON] / [FMT-MULTI]. `make fmt`, `make lint`, `make test` are three separate, non-overlapping targets.
- **3g. GitHub repo settings.** Apply spec [GITHUB-SETTINGS] / [GITHUB-MERGE] / [GITHUB-FEATURES] / [GITHUB-PROTECTION] / [GITHUB-CLI] via the commands in `templates/.github/common-repo-settings.md`. Applies to both new and existing repos. If the repo is local-only (no remote yet), skip and note for after-first-push. If `gh` was skipped in Step 2i, skip here too and record in the Step 5 report.
- **3h. Agent instruction files.** Per spec [AGENT] / [AGENT-TEMPLATE] / [AGENT-POINTERS].

  **The canonical file MUST be fully customised.** Fill every placeholder, strip every language/tool/framework section that does not apply, fill the project overview and architecture section with real content. The test: ZERO references to languages or tools the repo does not use.

  1. Write the canonical file (Claude → `CLAUDE.md`; others → `AGENTS.md`; Copilot → `.github/copilot-instructions.md`).
  2. Every other agent instruction file becomes a trivial pointer to the canonical file. See spec [AGENT-POINTERS]. **Strip existing content** from non-canonical files — no headings, no preamble, no leftover rules — leave only the marker line and `@<canonical_file>` redirect. Use `templates/CLAUDE.md` as the pointer template.
  3. Place skills from `templates/skills/` into the target agent's native directory per spec [SKILL-PLACEMENT]. Apply spec [MODES-CUSTOMIZE]:
     - Language-customizable skills (`code-dedup`, `ci-prep`, `upgrade-packages`): strip irrelevant language sections, fill placeholders.
     - Content-preserving skills (`website-audit`, `spec-check`, `submit-pr`, any skill without multi-language examples): copy the step-by-step procedure verbatim. Add repo-specific context if useful, but never drop/merge/summarize/rewrite/gut steps. Diff source vs output — the only differences should be repo-specific additions.

  If an existing canonical file has substantial custom content, **merge** into it instead of overwriting. Result must read as a coherent document for this repo, not a generic template with the name swapped in.
- **3i. VS Code title bar colorization** (only if `.vscode/` or `.vscode/settings.json` exists).
  1. Find the project's primary brand color. Check in order: `designsystem/`/`design-system/`/`design/`, CSS custom properties (`--color-*`, `--brand-*`, `--primary`) in `website/`/`site/`/`docs/`, `tailwind.config.*` theme, `theme.*`/`colors.*` files, README color scheme.
  2. Extract the dominant accent (not white/black/grey).
  3. Merge into `.vscode/settings.json`:
     ```json
     {
       "workbench.colorCustomizations": {
         "titleBar.activeBackground": "<primary-brand-color>",
         "titleBar.activeForeground": "<contrasting-text-color>",
         "titleBar.inactiveBackground": "<darker-shade-of-primary>",
         "titleBar.inactiveForeground": "<contrasting-text-color-with-opacity>"
       }
     }
     ```
     Inactive background = slightly darker/desaturated primary. Inactive foreground = active foreground with ~80% opacity (append `cc` to hex).
  4. If no brand colors can be found anywhere, **skip** and note in the report. Do NOT invent colors.
- **3j. VS Code recommended extensions.** Merge `templates/vscode/universal.extensions.json` into `.vscode/extensions.json`. If the repo has a web API (REST/GraphQL/HTTP server), also merge `webapi.extensions.json`. De-duplicate the `recommendations` array. Create `.vscode/` if absent.

### Step 4 — Deduplication check

After all changes, verify:

1. **CI workflows** — exactly one `ci.yml`, at most one `release.yml`, at most one `deploy-pages.yml`. Delete any legacy siblings.
2. **Linter configs** — one config per tool per language. No both-of pairs (e.g. `eslint.config.mjs` AND `.eslintrc.json`; `.prettierrc` AND `.prettierrc.json`; `.golangci.yml` AND `.golangci.yaml`; `.flake8` AND `pyproject.toml [tool.ruff]`).
3. **Coverage configs** — no both-of (`.coveragerc` AND `[tool.coverage]`). No leftover coverage shell scripts.
4. **Formatter configs** — one per tool. No both-of (`[tool.black]` AND `[tool.ruff.format]`).
5. **Build files** — no competing systems with identical targets (e.g. `Makefile` AND `Taskfile.yml`).
6. **Docs folders** — exactly one, called `docs/`. `docs/specs/` and `docs/plans/` exist. No loose markdown that belongs in a subdir.
7. **Skills** — no duplicates across agent-native skill directories. Consolidate to the primary agent's dir per spec [SKILL-PLACEMENT].
8. **Agent instruction files** — exactly ONE canonical file with full rules. All others are pointers (marker + `@<canonical>` only). Rename legacy pointer filenames (`.clinerules/00-read-claude-md.md` → `.clinerules/00-read-instructions.md`).
9. **Orphaned `agent-pmo:` files** — per spec [MARKER-CLEANUP]: for every marked file, verify the source still exists in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/`. If not, delete the orphan.
10. **Stale markers** — flag files more than 50 commits behind current standards HEAD per spec [MARKER-AUDIT].
11. **Report** all duplicates deleted, orphans removed, stale markers found. When unsure whether something is a duplicate or a genuine repo-specific artifact, **ask the user** — never delete "to be tidy".

Merging multiple files into one is a valid outcome and overrides the no-delete default.

### Step 5 — Verify (DO NOT commit)

1. List every file created, modified, renamed, or deleted (including Make targets merged/removed).
2. If possible, run `make lint` and `make test` to validate. Report errors so the user can fix them.
3. **LICENSE check.** If no license file was found in Step 2h, emit the banner at the **top** of the final report — impossible to miss, do not soften, do not omit:

   ```
   ================================================================================
   !!!  WARNING — NO LICENSE FILE FOUND  !!!
   ================================================================================
   This repository has NO LICENSE file. Under default copyright law this means
   "all rights reserved" — nobody (including contributors) has permission to use,
   copy, modify, or distribute this code.

   You MUST add a LICENSE file. Common choices:
     - MIT          — permissive, simple
     - Apache-2.0   — permissive, patent grant
     - GPL-3.0      — copyleft
     - BSD-3-Clause — permissive
     - Proprietary  — all rights reserved (explicit)

   This skill will NOT create a LICENSE file for you — the choice has legal
   consequences and must be made deliberately.
   ================================================================================
   ```
4. Remind the user: **No commits or pushes were made. Review the changes and commit when ready.**
