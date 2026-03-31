---
name: agent-pmo
description: Apply portfolio-wide repository standards (Makefile, CI, linting, coverage) to a new or existing repo. Use when user says "enforce standards", "fix repo", "make compliant", "set up repo", or "apply repo standards". Reads the authoritative spec and creates/updates config files. NEVER commits or pushes.
disable-model-invocation: true
---

> **Portable skill.** This skill adapts to the current repository. The agent MUST inspect the repo structure and use judgment to apply these instructions appropriately.

# Enforce Repository Standards

Apply the standards defined in the `REPO-STANDARDS-SPEC.md` file. Works on both new and existing repos.

**Finding the spec:** The spec and all templates live at a fixed path that was stamped into this skill at install time:

- Spec: `{{STANDARDS_REPO}}/docs/specs/REPO-STANDARDS-SPEC.md`
- Templates: `{{STANDARDS_REPO}}/agent-pmo-skill/templates/`

Read the spec directly. Do NOT search the filesystem, scan sibling directories, or guess paths. If the path above does not exist, report an error and stop.

**NEVER run `git commit`, `git push`, or any git write command.** Read-only git commands (status, log, diff) are fine.

## Instructions

### Step 1 — Read the spec, detect context, and detect primary agent

1. Read `{{STANDARDS_REPO}}/docs/specs/REPO-STANDARDS-SPEC.md`. **All file contents, templates, linter configs, CI workflows, coverage checks, and Makefile targets come from that spec. Do not improvise or invent alternatives.**
2. Detect which languages are present in the target repo (look for `Cargo.toml`, `package.json`, `pubspec.yaml`, `*.csproj`/`*.fsproj`/`*.sln`, `go.mod`, `pyproject.toml`, `setup.py`, `requirements.txt`, etc.).
3. Determine repo type (library, CLI, app/service, extension, static site) for coverage thresholds per the spec. All projects default to 90% code coverage target by default
4. **You are the primary agent.** You know what agent you are — use that directly. Do NOT scan the filesystem to guess. Set up the target repo for yourself:
   - **Claude Code** → canonical file is `CLAUDE.md`, skills go in `.claude/skills/`, use `@AGENTS.md` import syntax
   - **OpenAI Codex** → canonical file is `AGENTS.md`, skills go in `.agents/skills/`
   - **GitHub Copilot** → canonical file is `AGENTS.md`, skills go in `.github/skills/` or `.agents/skills/`, also update `.github/copilot-instructions.md`
   - **Cline/Roo** → canonical file is `AGENTS.md`, skills go in `.cline/skills/`, also update `.clinerules/00-read-instructions.md`
   - **OpenCode** → canonical file is `AGENTS.md`, skills go in `.opencode/skills/` or `.agents/skills/`
5. Report which agent you are and which file will be canonical.
6. **Read the target agent's official documentation** before touching any instruction or skill files. The spec §10.0 has the complete URL table. Each agent has different file locations, import syntax, and conventions. You MUST use the correct syntax — do not guess.

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
- Compare against the standard in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/.github/common-repo-settings.md`.
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

### File Markers (applies to ALL steps below)

Every file you create or substantively modify MUST include an `agent-pmo:<hash>` marker near the top. Before writing any files, get the current short hash:

```bash
git -C "{{STANDARDS_REPO}}" rev-parse --short HEAD
```

Use this hash in every marker. See the spec §16 for exact placement rules by file type. For example:
- YAML/Makefile/TOML/dotfiles: `# agent-pmo:abc1234`
- Markdown: `<!-- agent-pmo:abc1234 -->`
- JSON: `"_agent_pmo": "abc1234"` as a top-level field
- JS/TS: `// agent-pmo:abc1234`
- XML: `<!-- agent-pmo:abc1234 -->`

Place markers within the first 10 lines. For files with headers (shebang, YAML frontmatter, XML declarations), place immediately after the header. When updating an existing agent-pmo file, update the hash to the current value.

**CRITICAL: Before stamping ANY file, verify its source template or skill exists at the exact path in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/` by reading it. If the source file does not exist, DO NOT create the file and DO NOT stamp it. A marker is a claim of provenance — if the source doesn't exist in the standards repo, the file must not exist in the target repo. This applies especially to skills: only create skills that exist in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/skills/`. List the directory first, then only create what you find.**

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
Apply the standard GitHub repo settings defined in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/.github/common-repo-settings.md`. This applies to **both new and existing repos**.

Use the `gh` CLI to configure:
- **Merge settings:** Squash merge only (disable merge commit and rebase merge), auto merge enabled, delete branch on merge enabled, squash commit title = PR_TITLE, message = PR_BODY.
- **Features:** Wiki disabled, Projects disabled, Discussions enabled (public repos only).
- **Branch protection:** If no protection exists on `main`, add a ruleset requiring PRs and CI status checks to pass. If protection already exists, leave it alone.

The exact `gh api` commands are in the common-repo-settings file. The repo must be pushed to GitHub for these commands to work — if it's a brand new local-only repo, note this for the user and skip (they can run it after the first push).

#### 3h. Agent instruction files (§10 — agent-agnostic)

**CRITICAL: The canonical instruction file (AGENTS.md or CLAUDE.md) MUST be fully customised for the target repo.** The template is a STARTING POINT. You MUST:
- Fill ALL `{{placeholders}}` with real values (repo name, languages, description, architecture)
- **Strip every language section that doesn't apply.** A Python repo MUST NOT mention Rust, TypeScript, Dart, C#, Go rules.
- **Strip every tool/package reference that doesn't apply.** Don't mention `cargo`, `tsconfig`, `dotnet` in a Python repo.
- **Fill in the project overview** with a real description of what the repo does.
- **Fill in the architecture section** with the actual directory structure.
- **Add repo-specific build commands** if they differ from the defaults.
- **Include only the logging library row for the repo's language(s).**
- **Include only the relevant agent reference docs** from the URL tables — a Claude-only repo doesn't need Codex/Copilot links.

**The test:** After customisation, a developer reading the file should see ZERO references to languages, tools, frameworks, or packages not used in the repo.

Generate your own canonical instruction file from the template at `{{STANDARDS_REPO}}/agent-pmo-skill/templates/AGENTS.md`. Customise it fully as described above, then set it up for yourself:

1. **Write your canonical file.** Put the customised content into whatever file you natively read (e.g., Claude → `CLAUDE.md`, Codex → `AGENTS.md`, Copilot → `.github/copilot-instructions.md`).
2. **Create pointer files** so other agents can also find the instructions. Every other agent instruction file should be a trivial pointer to your canonical file.
3. **Place skills** from `{{STANDARDS_REPO}}/agent-pmo-skill/templates/skills/` into your native skill directory. Read each source SKILL.md in full, then apply §17.2 customization rules:
   - **Language-customizable skills** (`code-dedup`, `ci-prep`, `upgrade-packages`): strip irrelevant language sections, fill placeholders.
   - **Content-preserving skills** (`website-audit`, `spec-check`, `submit-pr`, and any skill without multi-language examples): **the spirit of the skill must remain intact.** Copy the full step-by-step procedure verbatim. You may add repo-specific context (e.g., which websites to audit) but NEVER drop, merge, summarize, rewrite, or gut steps. Every step, sub-check, URL, specific instruction, checklist item, and report format must be preserved. Diff the source against your output — the only differences should be repo-specific additions.

If an existing instruction file has substantial custom content, **merge** it into the canonical file rather than overwriting.

#### 3i. VS Code workspace colorization (only if VS Code is detected)

If the target repo has a `.vscode/` directory or `.vscode/settings.json`, colorize the VS Code title bar so the user can visually distinguish this workspace from others.

1. **Find the project's brand colors.** Search the repo for a design system or CSS file that defines the project's color palette. Check, in order:
   - A design system folder (`designsystem/`, `design-system/`, `design/`)
   - CSS files in a website directory (`website/`, `site/`, `docs/`) — look for CSS custom properties (`--color-*`, `--brand-*`, `--primary`) or prominent color declarations
   - `tailwind.config.*` theme colors
   - Any `theme.*` or `colors.*` file
   - The project's website or README if it references a color scheme
2. **Extract the primary brand color** (the dominant accent/brand color, NOT white/black/grey).
3. **Write `.vscode/settings.json`** (merge into existing if the file already exists). Add the `workbench.colorCustomizations` block:
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
   - `titleBar.activeBackground` — the primary brand color
   - `titleBar.activeForeground` — white or dark text, whichever has better contrast
   - `titleBar.inactiveBackground` — a slightly darker/desaturated shade of the primary color
   - `titleBar.inactiveForeground` — same as active foreground but with ~80% opacity (append `cc` to the hex)
4. If no brand colors can be found anywhere in the repo, **skip this step** and note it in the report. Do NOT invent colors.

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
7. **Skills:** Check the agent-native skill directory (`.claude/skills/`, `.agents/skills/`, `.github/skills/`, `.cline/skills/`, `.opencode/skills/` per §11.1) — don't create duplicates of skills that already exist. If skills exist in multiple directories, consolidate to the primary agent's directory.
8. **Agent instruction files:** Verify exactly ONE file has the full rules content (either CLAUDE.md or AGENTS.md, not both). All other agent files must be pointers. Check that old pointer filenames (e.g., `.clinerules/00-read-claude-md.md`) are renamed to the new standard (`.clinerules/00-read-instructions.md`).
9. **Orphaned agent-pmo files (§16):** Search the target repo for all files containing an `agent-pmo:` marker. For each marked file, verify that its corresponding source template or skill still exists in `{{STANDARDS_REPO}}/agent-pmo-skill/templates/`. If the source no longer exists, **delete the orphaned file**. This cleans up files from skills or templates that were removed from the standards repo (e.g., the old `fmt`, `lint`, and `test` skills that were consolidated into `ci-prep`).
10. **Stale markers:** For files with `agent-pmo:` markers, compare the stamped hash against the current standards repo HEAD. If a file is more than 50 commits behind, flag it for re-application.
11. **Report:** List any duplicates found and deleted, any orphaned files removed, and any stale markers found. If you're unsure whether something is a duplicate or serves a different purpose, ask the user rather than deleting.

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
- **Read the agent docs before touching agent files.** The spec §10.0 has the complete URL table. Each agent has different import syntax, file locations, and conventions. Use the correct syntax for the detected agent — never guess.
- **Skills are agent-agnostic but placement is agent-specific.** Skill templates use a universal SKILL.md format. Place them in the target agent's native directory per §11.1. If the repo uses multiple agents, prefer `.agents/skills/` for maximum cross-compatibility.
- **Spec IDs are normative.** Every spec section MUST have a hierarchical, non-numeric ID (`[GROUP-TOPIC-DETAIL]`). Existing repos with missing or numbered IDs MUST be normalised. When renaming IDs, update all cross-references in code, tests, and docs.
- **Every file you create or substantively modify gets an `agent-pmo:<hash>` marker (§16).** This enables orphaned file cleanup and provenance auditing. Never skip the marker.
- **NEVER stamp a file unless its source exists in the standards repo.** Before creating any file from a template or skill, read the source at `{{STANDARDS_REPO}}/agent-pmo-skill/templates/` to confirm it exists. If the source path does not exist, do not create the file. List `{{STANDARDS_REPO}}/agent-pmo-skill/templates/skills/` before creating skills — only create what is actually there.
