---
name: enforce-repo-standards
description: Apply portfolio-wide repository standards (Makefile, CI, linting, coverage, editorconfig) to a new or existing repo. Use when user says "enforce standards", "fix repo", "make compliant", "set up repo", or "apply repo standards". Reads the authoritative spec and creates/updates config files. NEVER commits or pushes.
disable-model-invocation: true
---

# Enforce Repository Standards

Apply the standards defined in the `REPO-STANDARDS-SPEC.md` file from the project_status directory. Works on both new and existing repos.

**Finding the spec:** Locate `REPO-STANDARDS-SPEC.md` by checking in order:
1. `$REPO_BOOTSTRAP_PATH/docs/specs/REPO-STANDARDS-SPEC.md` (if env var is set)
2. `/workspaces/project_status/docs/specs/REPO-STANDARDS-SPEC.md` (Docker/container)
3. `~/Documents/Code/project_status/docs/specs/REPO-STANDARDS-SPEC.md` (local dev fallback)

**NEVER run `git commit`, `git push`, or any git write command.** Read-only git commands (status, log, diff) are fine.

## Instructions

### Step 1 — Read the spec and detect context

1. Locate and read `REPO-STANDARDS-SPEC.md` from the project_status directory (see path resolution above). **All file contents, templates, linter configs, CI workflows, coverage checks, and Makefile targets come from that spec. Do not improvise or invent alternatives.**
2. Detect which languages are present in the target repo (look for `Cargo.toml`, `package.json`, `pubspec.yaml`, `*.csproj`/`*.fsproj`/`*.sln`, `go.mod`, `pyproject.toml`, `setup.py`, `requirements.txt`, etc.).
3. Determine repo type (library, CLI, app/service, extension, static site) for coverage thresholds per the spec. All projects default to 90% code coverage target by default

### Step 2 — Audit existing artifacts for equivalents

Before creating anything, **inventory what already exists** so you never create duplicates.

#### 2a. CI workflows
- List ALL files in `.github/workflows/`. Look for existing CI workflows under any name (e.g., `build.yml`, `ci-build.yml`, `test.yml`, `checks.yml`, `main.yml`, `pull_request.yml`, `pr.yml`).
- Read each workflow file. If a workflow already does what `ci.yml` should do (lint/test/build on PRs), that IS the CI workflow — **rename it** to `ci.yml` and update it in place. Do NOT create a new `ci.yml` alongside it.
- Same for release workflows (`publish.yml`, `deploy.yml`, `build-release.yml` → `release.yml`) and pages workflows (`gh-pages.yml`, `pages.yml` → `deploy-pages.yml`).

#### 2b. Makefile
- If a `Makefile` exists, read it. Merge spec-required targets into the existing file. Preserve any extra custom targets the repo has. Do NOT create a second Makefile or overwrite custom targets.
- If the repo uses a different build file instead (e.g., `justfile`, `Taskfile.yml`), keep it for reference but create the standard `Makefile` that delegates or replaces it — ask the user if unsure.

#### 2c. Linter configs
- Check for equivalent configs under alternate names or locations:
  - ESLint: `.eslintrc.js`, `.eslintrc.cjs`, `.eslintrc.yaml`, `.eslintrc.json` → standardise to `eslint.config.mjs` (ESLint v9+ flat config)
  - Prettier: `.prettierrc`, `.prettierrc.js`, `.prettierrc.yaml`, `prettier.config.js` → standardise to `.prettierrc.json`
  - Python linting: `setup.cfg` `[flake8]`/`[isort]` sections, `.flake8`, `tox.ini` → migrate to Basilisk (primary linter, work in progress) + `pyproject.toml` `[tool.ruff]` (secondary layer)
  - Go linting: `.golangci.yaml` (wrong extension) → rename to `.golangci.yml`
  - C#: .editorconfig and build props
- When migrating, **delete the old file** after confirming the new one covers everything. Do NOT leave both.

#### 2d. Formatter configs
- Check for existing formatter setups: CSharpier (`.csharpierrc.json`, `dotnet-tools.json`), Fantomas (`.fantomasrc`, `dotnet-tools.json`), Prettier (`.prettierrc`, `.prettierrc.json`, `.prettierrc.js`, etc.), rustfmt (`rustfmt.toml`), ruff format (`pyproject.toml [tool.ruff.format]`). If `[tool.black]` exists in pyproject.toml, migrate to `[tool.ruff.format]` and remove it.
- If an equivalent formatter config exists under a non-standard name, migrate it. Do NOT leave duplicates.
- For Python repos, verify Basilisk is set up as the primary linter (work in progress — configure what's available locally). The formatter is ruff format.

#### 2e. Coverage configs
- Check for existing coverage scripts (`scripts/check_coverage.sh`, `tools/coverage.sh`, etc.). If found, the Makefile `_coverage_check` target replaces them — **delete the old script** after migrating any custom logic.
- Check for `.coveragerc` vs `pyproject.toml` `[tool.coverage]` — don't have both.

#### 2f. Editor config / gitignore
- If `.editorconfig` exists, merge spec sections into it rather than replacing. Preserve any project-specific overrides that don't conflict.
- If `.gitignore` exists, merge spec patterns into it rather than replacing. Do NOT duplicate patterns already present.

#### 2g. GitHub repository settings
- If the repo exists on GitHub, check current settings using `gh api repos/OWNER/REPO` to see merge strategy, features, and branch protection.
- Compare against the standard in `<project_status>/enforce-repo-standards/templates/.github/common-repo-settings.md` (resolve repo_bootstrap path as described above).
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
- **CLAUDE.md**: Remove Hard Rules sections for languages not in use. Fill in all `{{placeholders}}`.
- **Makefile**: Delete commented blocks for unused languages.
- **CI workflows**: Remove commented setup steps for unused languages.

### Step 3 — Apply standards with merge-first logic (DO NOT commit/push)

For each item: **(1)** if a compliant equivalent exists, leave it alone; **(2)** if an equivalent exists under the wrong name or with wrong content, rename/update it in place; **(3)** only create from scratch if nothing equivalent exists.

#### 3a. Makefile
- Merge spec-required targets into existing `Makefile`, or create one if none exists.
- Uncomment language-specific implementation targets for each detected language.
- For multi-language repos, chain implementations as described in the spec.
- Preserve any extra custom targets the repo already has.

#### 3b. GitHub Actions workflows
- Update/rename the identified existing workflow (from Step 2a), or create `ci.yml` only if no equivalent exists.
- Same for `release.yml` and `deploy-pages.yml`.
- Uncomment the language setup sections that apply.
- **CRITICAL: Every job in every workflow MUST have `timeout-minutes: 10`** unless there is a documented reason it genuinely needs longer. If a job needs longer than 10 minutes, keep `timeout-minutes` at the required value and add a comment directly above it explaining WHY it must exceed 10 minutes. Example:
  ```yaml
  # TIMEOUT EXCEPTION: Full integration test suite against live staging env requires ~15 min
  timeout-minutes: 15
  ```

#### 3c. Coverage
- The `_coverage_check` Makefile target handles coverage enforcement directly — no shell scripts. The coverage check logic is inline in the Makefile per the spec.
- Each project in the repo has its own coverage threshold stored as a GitHub repo variable (Settings → Variables → Actions). Configure the `coverage-check` CI step with an `env` block that passes the repo variable (e.g., `COVERAGE_THRESHOLD: ${{ vars.COVERAGE_THRESHOLD_PYTHON }}`). **No hardcoded defaults in ci.yml** — the Makefile default (90%) is the fallback for local runs only.
- Thresholds are **monotonically increasing** (ratchet) — they never go down.
- For Python repos, create/update `.coveragerc` per the spec (but remove `[tool.coverage]` from `pyproject.toml` if `.coveragerc` is the canonical location, or vice versa — don't have both).
- For .NET repos, create/update `coverlet.runsettings` per the spec.
- Delete any old coverage shell scripts that the Makefile target replaces.

#### 3d. Linter configs
Apply the exact linter configuration from the spec for each detected language. **Merge into existing files; delete superseded files:**
- Rust: `Cargo.toml` workspace lints, `rustfmt.toml`
- TypeScript: `eslint.config.mjs` (flat config), `.prettierrc.json`, `tsconfig.json` strict baseline — merge with existing tsconfig if present, don't clobber project-specific fields like `outDir`, `rootDir`, `include`. Delete old-format equivalents (`.eslintrc.json`, `.eslintrc.js`, `.prettierrc.yaml`, etc.) after migration.
- Python: **Basilisk is the primary linter/type checker for all Python projects.** Ensure Basilisk is configured as the main linting tool. Additionally configure `pyproject.toml` ruff + pyright sections as a secondary layer — merge with existing pyproject.toml, don't clobber `[project]` or other tool sections. Delete superseded `.flake8`, `setup.cfg [flake8]` sections, etc.
- Dart/Flutter: `analysis_options.yaml`
- Go: `.golangci.yml` (delete `.golangci.yaml` if it existed)
- C#: `.editorconfig` C# section
- F#: `.editorconfig` F# section

#### 3e. Formatting
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

#### 3f. Editor config
- Merge spec sections into existing `.editorconfig`, or create one if none exists.

#### 3g. GitHub repository settings
Apply the standard GitHub repo settings defined in `<project_status>/enforce-repo-standards/templates/.github/common-repo-settings.md` (resolve repo_bootstrap path as described above). This applies to **both new and existing repos**.

Use the `gh` CLI to configure:
- **Merge settings:** Squash merge only (disable merge commit and rebase merge), auto merge enabled, delete branch on merge enabled, squash commit title = PR_TITLE, message = PR_BODY.
- **Features:** Wiki disabled, Projects disabled, Discussions enabled (public repos only).
- **Branch protection:** If no protection exists on `main`, add a ruleset requiring PRs and CI status checks to pass. If protection already exists, leave it alone.

The exact `gh api` commands are in the common-repo-settings file. The repo must be pushed to GitHub for these commands to work — if it's a brand new local-only repo, note this for the user and skip (they can run it after the first push).

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
6. **Skills:** Check `.claude/skills/` — don't create duplicates of skills that already exist under the correct name.
7. **Report:** List any duplicates found and deleted. If you're unsure whether something is a duplicate or serves a different purpose, ask the user rather than deleting.

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
