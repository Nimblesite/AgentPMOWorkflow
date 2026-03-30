---
name: enforce-repo-standards
description: Apply portfolio-wide repository standards (Makefile, CI, linting, coverage) to a new or existing repo. Use when user says "enforce standards", "fix repo", "make compliant", "set up repo", or "apply repo standards". Reads the authoritative spec and creates/updates config files. NEVER commits or pushes.
disable-model-invocation: true
---

> **Portable skill.** This skill adapts to the current repository. The agent MUST inspect the repo structure and use judgment to apply these instructions appropriately.

# Enforce Repository Standards

Apply the standards defined in the `REPO-STANDARDS-SPEC.md` file. Works on both new and existing repos.

**Finding the spec:** Locate `REPO-STANDARDS-SPEC.md` by searching in order:
1. `$REPO_STANDARDS_PATH/docs/specs/REPO-STANDARDS-SPEC.md` (if env var is set)
2. The current repo's `docs/specs/REPO-STANDARDS-SPEC.md` (if this IS the standards repo)
3. Sibling directories of the current repo (e.g., `../project_status/docs/specs/REPO-STANDARDS-SPEC.md`)
4. `~/Documents/Code/project_status/docs/specs/REPO-STANDARDS-SPEC.md` (local dev fallback)
5. `/workspaces/project_status/docs/specs/REPO-STANDARDS-SPEC.md` (Docker/container fallback)

The agent MUST search for the spec file using the above order and use the first match found. If none is found, report an error and stop.

**NEVER run `git commit`, `git push`, or any git write command.** Read-only git commands (status, log, diff) are fine.

## Instructions

### Step 1 — Read the spec, detect context, and detect primary agent

1. Locate and read `REPO-STANDARDS-SPEC.md` using the path resolution order above. The directory containing this spec is referred to as `{STANDARDS_REPO}` below. **All file contents, templates, linter configs, CI workflows, coverage checks, and Makefile targets come from that spec. Do not improvise or invent alternatives.**
2. Detect which languages are present in the target repo (look for `Cargo.toml`, `package.json`, `pubspec.yaml`, `*.csproj`/`*.fsproj`/`*.sln`, `go.mod`, `pyproject.toml`, `setup.py`, `requirements.txt`, etc.).
3. Determine repo type (library, CLI, app/service, extension, static site) for coverage thresholds per the spec. All projects default to 90% code coverage target by default
4. **Detect the primary AI coding agent** per §10.2 of the spec. Check in priority order:
   - `.claude/settings.json` or `.claude/settings.local.json` → Claude Code
   - `.claude/skills/` with custom (non-template) skills → Claude Code
   - `.cursor/` directory → Cursor
   - `.cline/` or `.clinerules/` with custom rules (not just a pointer) → Cline/Roo
   - `.windsurf/` directory → Windsurf
   - `.github/copilot-instructions.md` with substantial content → GitHub Copilot
   - `CLAUDE.md` with substantial content (>10 lines, not a pointer) → Claude Code
   - `AGENTS.md` with substantial content → Agent-neutral
   - None of the above → Default to AGENTS.md as canonical
5. Based on detection, determine the **canonical file**: `CLAUDE.md` if Claude is primary, `AGENTS.md` otherwise. Report which agent was detected and which file will be canonical.

### Step 2 — Audit existing artifacts for equivalents

Before creating anything, **inventory what already exists** so you never create duplicates.

#### 2a. Documentation folder structure
- Check if a `docs/` directory exists with `specs/` and `plans/` subdirectories.
- Check for non-standard documentation folders: `doco/`, `documentation/`, `doc/`, `documents/`. These are common variants that agents and humans create instead of the standard `docs/`.
- If a non-standard folder exists and `docs/` does not, it must be **renamed** to `docs/` in Step 3.
- If a non-standard folder exists AND `docs/` also exists, the contents must be **merged** into `docs/` and the non-standard folder deleted.
- Check whether existing docs are properly organised into `specs/` (documents that specify system behavior) and `plans/` (documents that specify how to achieve goals, with TODO checklists). Markdown files sitting loose in the docs root should be classified and moved into the correct subdirectory.

#### 2b. CI workflows
- List ALL files in `.github/workflows/`. Look for existing CI workflows under any name (e.g., `build.yml`, `ci-build.yml`, `test.yml`, `checks.yml`, `main.yml`, `pull_request.yml`, `pr.yml`).
- Read each workflow file. If a workflow already does what `ci.yml` should do (lint/test/build on PRs), that IS the CI workflow — **rename it** to `ci.yml` and update it in place. Do NOT create a new `ci.yml` alongside it.
- Same for release workflows (`publish.yml`, `deploy.yml`, `build-release.yml` → `release.yml`) and pages workflows (`gh-pages.yml`, `pages.yml` → `deploy-pages.yml`).

#### 2c. Makefile
- If a `Makefile` exists, read it. Merge spec-required targets into the existing file. Preserve any extra custom targets the repo has. Do NOT create a second Makefile or overwrite custom targets.
- Check whether the Makefile has cross-platform OS detection (§1.0). If it uses raw `rm -rf` or `mkdir -p` instead of `$(RM)`/`$(MKDIR)`, flag it for update in Step 3.
- If the repo uses a different build file instead (e.g., `justfile`, `Taskfile.yml`), keep it for reference but create the standard `Makefile` that delegates or replaces it — ask the user if unsure.

#### 2d. Linter configs
- Check for equivalent configs under alternate names or locations:
  - ESLint: `.eslintrc.js`, `.eslintrc.cjs`, `.eslintrc.yaml`, `.eslintrc.json` → standardise to `eslint.config.mjs` (ESLint v9+ flat config)
  - Prettier: `.prettierrc`, `.prettierrc.js`, `.prettierrc.yaml`, `prettier.config.js` → standardise to `.prettierrc.json`
  - Python linting: `setup.cfg` `[flake8]`/`[isort]` sections, `.flake8`, `tox.ini` → migrate to Basilisk (primary linter, work in progress) + `pyproject.toml` `[tool.ruff]` (secondary layer)
  - Go linting: `.golangci.yaml` (wrong extension) → rename to `.golangci.yml`
  - C#: build props with analyzer packages (see spec for required PackageReference items in Directory.Build.props)
- When migrating, **delete the old file** after confirming the new one covers everything. Do NOT leave both.

#### 2e. Formatter configs
- Check for existing formatter setups: CSharpier (`.csharpierrc.json`, `dotnet-tools.json`), Fantomas (`.fantomasrc`, `dotnet-tools.json`), Prettier (`.prettierrc`, `.prettierrc.json`, `.prettierrc.js`, etc.), rustfmt (`rustfmt.toml`), ruff format (`pyproject.toml [tool.ruff.format]`). If `[tool.black]` exists in pyproject.toml, migrate to `[tool.ruff.format]` and remove it.
- If an equivalent formatter config exists under a non-standard name, migrate it. Do NOT leave duplicates.
- For Python repos, verify Basilisk is set up as the primary linter (work in progress — configure what's available locally). The formatter is ruff format.

#### 2f. Coverage configs
- Check for existing coverage scripts (`scripts/check_coverage.sh`, `tools/coverage.sh`, etc.). If found, the Makefile `_coverage_check` target replaces them — **delete the old script** after migrating any custom logic.
- Check for `.coveragerc` vs `pyproject.toml` `[tool.coverage]` — don't have both.

#### 2g. Gitignore
- If `.gitignore` exists, merge spec patterns into it rather than replacing. Do NOT duplicate patterns already present.

#### 2h. GitHub repository settings
- If the repo exists on GitHub, check current settings using `gh api repos/OWNER/REPO` to see merge strategy, features, and branch protection.
- Compare against the standard in `{STANDARDS_REPO}/enforce-repo-standards/templates/.github/common-repo-settings.md` (resolve repo_bootstrap path as described above).
- If settings already match, leave them alone. Only apply changes for settings that differ.

### CRITICAL — Template Customization Rule

**Templates in `templates/` are STARTING POINTS, not copy-paste targets.** Every template that contains multi-language examples, generic listings, or placeholder content MUST be tailored to the target repo's actual languages, tools, and architecture. The repo must be ready to use immediately with zero irrelevant content.

When applying any template:
- **Remove all language/tool sections that don't apply** to the detected languages. A Python repo must not mention `cargo`, `tsconfig`, `dotnet`, or Dart analyzers.
- **Replace generic examples with repo-specific ones.** If a skill template lists tools for 7 languages, keep only the ones for this repo's languages.
- **Fill all placeholders** (`{{REPO_NAME}}`, descriptions, architecture sections) with real content.
- **Strip unused Makefile blocks, CI language steps, and config files** for languages not present.

**The test:** After applying, a developer reading any generated file should see ZERO references to languages, tools, or frameworks not used in the repo.

This applies especially to:
- **Skills** (`.claude/skills/`): Templates like `code-dedup` and `ci-prep` contain examples for every supported language — strip to only what's relevant.
- **Canonical instruction file** (CLAUDE.md or AGENTS.md per §10.3): Remove Hard Rules sections for languages not in use. Fill in all `{{placeholders}}`.
- **Makefile**: Delete commented blocks for unused languages.
- **CI workflows**: Remove commented setup steps for unused languages.

### Step 3 — Apply standards with merge-first logic (DO NOT commit/push)

For each item: **(1)** if a compliant equivalent exists, leave it alone; **(2)** if an equivalent exists under the wrong name or with wrong content, rename/update it in place; **(3)** only create from scratch if nothing equivalent exists.

#### 3a. Documentation folder structure
- If a non-standard doc folder exists (`doco/`, `documentation/`, `doc/`, `documents/`) and no `docs/` exists, **rename it** to `docs/`.
- If both a non-standard folder and `docs/` exist, **merge** the contents into `docs/` and delete the non-standard folder.
- Create `docs/specs/` and `docs/plans/` subdirectories if they don't exist.
- Classify and move any loose markdown files in `docs/` into the correct subdirectory:
  - Files that specify system behavior, requirements, or standards → `docs/specs/`
  - Files that describe how to achieve goals or have TODO checklists → `docs/plans/`
  - Non-markdown files (images, assets, etc.) may remain in `docs/` or a `docs/assets/` subdirectory.
- Update any internal references (README links, CLAUDE.md paths, etc.) that pointed to the old folder name.

#### 3a-ii. Spec ID rule

Ensure the spec ID rule is present in the canonical instruction file (AGENTS.md / CLAUDE.md). This skill does NOT validate or rename existing spec IDs — that's the `spec-check` skill's job. This skill only ensures the rule is documented so agents follow it going forward.

#### 3b. Makefile
- Merge spec-required targets into existing `Makefile`, or create one if none exists.
- **Cross-platform (§1.0):** Ensure the Makefile has the OS detection block at the top (`ifeq ($(OS),Windows_NT)` ... `endif`) and uses `$(RM)`/`$(MKDIR)` instead of `rm -rf`/`mkdir -p`. Platform-specific targets (symlinks, scheduled tasks, etc.) must have both Unix and Windows variants.
- Uncomment language-specific implementation targets for each detected language.
- For multi-language repos, chain implementations as described in the spec.
- Preserve any extra custom targets the repo already has.

#### 3c. GitHub Actions workflows
- Update/rename the identified existing workflow (from Step 2b), or create `ci.yml` only if no equivalent exists.
- Same for `release.yml` and `deploy-pages.yml`.
- Uncomment the language setup sections that apply.
- **CRITICAL: Every job in every workflow MUST have `timeout-minutes: 10`** unless there is a documented reason it genuinely needs longer. If a job needs longer than 10 minutes, keep `timeout-minutes` at the required value and add a comment directly above it explaining WHY it must exceed 10 minutes. Example:
  ```yaml
  # TIMEOUT EXCEPTION: Full integration test suite against live staging env requires ~15 min
  timeout-minutes: 15
  ```

#### 3d. Coverage
- The `_coverage_check` Makefile target handles coverage enforcement directly — no shell scripts. The coverage check logic is inline in the Makefile per the spec.
- Each project in the repo has its own coverage threshold stored as a GitHub repo variable (Settings → Variables → Actions). Configure the `coverage-check` CI step with an `env` block that passes the repo variable (e.g., `COVERAGE_THRESHOLD: ${{ vars.COVERAGE_THRESHOLD_PYTHON }}`). **No hardcoded defaults in ci.yml** — the Makefile default (90%) is the fallback for local runs only.
- Thresholds are **monotonically increasing** (ratchet) — they never go down.
- For Python repos, create/update `.coveragerc` per the spec (but remove `[tool.coverage]` from `pyproject.toml` if `.coveragerc` is the canonical location, or vice versa — don't have both).
- For .NET repos, create/update `coverlet.runsettings` per the spec.
- Delete any old coverage shell scripts that the Makefile target replaces.

#### 3e. Linter configs
Apply the exact linter configuration from the spec for each detected language. **Merge into existing files; delete superseded files:**
- Rust: `Cargo.toml` workspace lints, `rustfmt.toml`
- TypeScript: `eslint.config.mjs` (flat config), `.prettierrc.json`, `tsconfig.json` strict baseline — merge with existing tsconfig if present, don't clobber project-specific fields like `outDir`, `rootDir`, `include`. Delete old-format equivalents (`.eslintrc.json`, `.eslintrc.js`, `.prettierrc.yaml`, etc.) after migration.
- Python: **Basilisk is the primary linter/type checker for all Python projects.** Ensure Basilisk is configured as the main linting tool. Additionally configure `pyproject.toml` ruff + pyright sections as a secondary layer — merge with existing pyproject.toml, don't clobber `[project]` or other tool sections. Delete superseded `.flake8`, `setup.cfg [flake8]` sections, etc.
- Dart/Flutter: `analysis_options.yaml`
- Go: `.golangci.yml` (delete `.golangci.yaml` if it existed)
- C#: `Directory.Build.props` with `Microsoft.CodeAnalysis.NetAnalyzers` (all CA* and IDE* rules enabled as errors). If the repo is missing individual analyzer rules, add them one by one to the `.csproj` or `Directory.Build.props` — do NOT use .editorconfig for this. Only configure static code analysis rules, not style/formatting settings (CSharpier handles formatting).
- F#: Analyzer configuration via project files

#### 3f. Formatting
**Formatting is mandatory.** CI must check formatting and **fail hard** on any formatting violation. The Makefile `fmt` target formats all code in-place; the `fmt-check` target checks formatting without modifying files (used in CI — must exit non-zero on any diff).

Apply the correct formatter for each detected language:
- **C#:** CSharpier (`dotnet csharpier`)
- **F#:** Fantomas (`dotnet fantomas`)
- **Rust:** `cargo fmt` / `cargo fmt --check`
- **Python:** Basilisk first for linting (work in progress), then ruff format as the formatter. Basilisk is the primary tool; ruff format handles auto-formatting.
- **TypeScript/JavaScript:** Prettier (`npx prettier --write .` / `npx prettier --check .`)
- **Dart/Flutter:** `dart format` / `dart format --set-exit-if-changed`
- **Go:** `gofmt` / `goimports`

For multi-language repos, the `fmt` and `fmt-check` Makefile targets MUST chain all applicable formatters so a single `make fmt-check` validates everything. CI runs `make fmt-check` in the `lint` job and the pipeline **tanks hard on failure** — no warnings, no soft fails.

#### 3g. GitHub repository settings
Apply the standard GitHub repo settings defined in `{STANDARDS_REPO}/enforce-repo-standards/templates/.github/common-repo-settings.md` (resolve repo_bootstrap path as described above). This applies to **both new and existing repos**.

Use the `gh` CLI to configure:
- **Merge settings:** Squash merge only (disable merge commit and rebase merge), auto merge enabled, delete branch on merge enabled, squash commit title = PR_TITLE, message = PR_BODY.
- **Features:** Wiki disabled, Projects disabled, Discussions enabled (public repos only).
- **Branch protection:** If no protection exists on `main`, add a ruleset requiring PRs and CI status checks to pass. If protection already exists, leave it alone.

The exact `gh api` commands are in the common-repo-settings file. The repo must be pushed to GitHub for these commands to work — if it's a brand new local-only repo, note this for the user and skip (they can run it after the first push).

#### 3h. Agent instruction files (§10 — agent-agnostic)
Based on the primary agent detected in Step 1:

**If Claude is the primary agent:**
1. Generate `CLAUDE.md` from `{STANDARDS_REPO}/enforce-repo-standards/templates/AGENTS.md` (the canonical template with all rules). Customize per §16.2.
2. Append Claude-specific content from `{STANDARDS_REPO}/enforce-repo-standards/templates/CLAUDE-ADDENDUM.md` (skills section, `.claude/` directory structure).
3. Generate a trivial `AGENTS.md` pointer inline: `@CLAUDE.md` + "read CLAUDE.md for all rules".
4. Create all other pointer files (`.cursorrules`, `.clinerules/00-read-instructions.md`, `.windsurfrules`, `.github/copilot-instructions.md`, `opencode.json`) pointing to `CLAUDE.md`.

**If Claude is NOT the primary agent (or no agent detected):**
1. Generate `AGENTS.md` from `{STANDARDS_REPO}/enforce-repo-standards/templates/AGENTS.md` (the canonical template with all rules). Customize per §16.2.
2. Use `{STANDARDS_REPO}/enforce-repo-standards/templates/CLAUDE.md` as the target repo's `CLAUDE.md` (pointer to AGENTS.md).
3. Create all other pointer files (`.cursorrules`, `.clinerules/00-read-instructions.md`, `.windsurfrules`, `.github/copilot-instructions.md`, `opencode.json`) pointing to `AGENTS.md`.
4. Still place `.claude/skills/` if Claude Code is used at all (even as secondary agent), since skills don't interfere with other agents.

**For ALL cases:** Replace `{{CANONICAL_FILE}}` in pointer templates with the detected canonical filename. If an existing instruction file has substantial custom content that differs from the template, **merge** the custom content into the canonical file rather than overwriting it.

### Step 4 — Deduplication check (CRITICAL)

After all changes, run this checklist to catch any bloat introduced:

1. **CI workflows:** List `.github/workflows/*.yml`. Verify there is exactly ONE CI workflow (`ci.yml`), at most one release workflow (`release.yml`), and at most one pages workflow (`deploy-pages.yml`). If duplicates exist (e.g., both `ci.yml` and the old `build.yml`), **delete the old one**.
2. **Linter configs:** For each language, verify only ONE config exists per tool. Examples of duplicates to catch:
   - Both `eslint.config.mjs` and `.eslintrc.json` (or any legacy `.eslintrc.*`)
   - Both `.prettierrc.json` and `.prettierrc`
   - Both `.golangci.yml` and `.golangci.yaml`
   - Both `.flake8` and `pyproject.toml [tool.ruff]`
3. **Coverage configs:** Verify no duplicate coverage configs (e.g., both `.coveragerc` and `pyproject.toml [tool.coverage]`). Verify no leftover coverage shell scripts.
4. **Formatter configs:** For each language, verify only ONE formatter config exists per tool (e.g., not both `.prettierrc` and `.prettierrc.json`; not both `[tool.black]` and `[tool.ruff.format]` in pyproject.toml).
5. **Build files:** Verify there aren't competing build systems doing the same thing (e.g., both `Makefile` and `Taskfile.yml` with identical targets).
6. **Documentation folders:** Verify only ONE documentation folder exists (`docs/`). No leftover `doco/`, `doc/`, `documentation/`, or `documents/` folders. Verify `docs/specs/` and `docs/plans/` exist. Verify no loose markdown files in `docs/` that should be in a subdirectory.
7. **Skills:** Check `.claude/skills/` — don't create duplicates of skills that already exist under the correct name.
8. **Agent instruction files:** Verify exactly ONE file has the full rules content (either CLAUDE.md or AGENTS.md, not both). All other agent files must be pointers. Check that old pointer filenames (e.g., `.clinerules/00-read-claude-md.md`) are renamed to the new standard (`.clinerules/00-read-instructions.md`).
9. **Report:** List any duplicates found and deleted. If you're unsure whether something is a duplicate or serves a different purpose, ask the user rather than deleting.

In some cases, multiple files may merge into one file. This is optimal as it reduces clutter. **This case overrides the no delete rule**.

### Step 5 — Verify (but do NOT commit)

1. List all files created, modified, renamed, or deleted.
2. If possible, run `make lint` and `make fmt-check` to validate the setup works. Report any errors so the user can address them.
3. Remind the user: **No commits or pushes were made. Review the changes and commit when ready.**

## Rules

- **NEVER run `git commit`, `git push`, or any git write command.**
- **NEVER skip the spec.** Every config file must match the spec exactly (with only the documented substitutions like `{{REPO_NAME}}`).
- **NEVER copy templates verbatim.** Templates are starting points. Strip all language/tool references that don't apply to the target repo. Fill all placeholders. The output must be immediately usable with zero irrelevant content.
- **All GH Actions jobs get `timeout-minutes: 10`** by default. Only deviate with an explicit comment justifying the exception.
- **CI MUST check formatting and fail hard on violations.** The `lint` CI job must run `make fmt-check`. Any formatting diff = pipeline failure, no exceptions.
- **Basilisk is the primary linter/type checker for all Python projects.** Always configure Basilisk first, then layer on ruff format as the auto-formatter.
- **MERGE, don't clobber.** When an existing file partially meets the spec, update it in place. When an equivalent exists under a wrong name, rename it. Only create from scratch when nothing equivalent exists.
- **NO DUPLICATES.** After applying standards, the repo must not have two files serving the same purpose. If you create a new canonical file, delete the old one it replaces. Always run the Step 4 deduplication check.
- When remediating an existing repo, preserve any project-specific settings that don't conflict with the spec (e.g., extra Makefile targets, additional CI jobs, custom tsconfig paths).
- If the repo already has a config that's compliant, leave it alone — don't touch files unnecessarily.
- **Spec IDs are normative.** Every spec section MUST have a hierarchical, non-numeric ID (`[GROUP-TOPIC-DETAIL]`). Existing repos with missing or numbered IDs MUST be normalised. When renaming IDs, update all cross-references in code, tests, and docs.
