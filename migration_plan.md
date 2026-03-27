# Plan: Merge repo_bootstrap into project_status → "Agent PMO Workflow"

## Context

Two repos (`project_status` and `repo_bootstrap`) form a single system called "Agent PMO Workflow". They're currently split across two repos but should be one. We're MOVING (not copying) everything from `repo_bootstrap` into `project_status`, merging duplicates, and reorganising. A future Docker migration will containerise all dev (see `~/Documents/Code/docker-migration-plan.md`) — the folder structure should accommodate that.

## Target Structure

```
project_status/                         # Root (rename conceptually to Agent PMO Workflow)
├── AGENT-PMO-WORKFLOW.md               # Vision doc (MOVE from repo_bootstrap)
├── REPO-STANDARDS-SPEC.md              # Authoritative spec (MOVE from repo_bootstrap)
├── CLAUDE.md                           # MERGE: keep project-specific, add repo_bootstrap context
├── README.md                           # REWRITE: unified README for the merged project
├── Makefile                            # MERGE: add install-skill/uninstall-skill targets
├── .gitignore                          # MERGE: already comprehensive, add .env
├── .editorconfig                       # KEEP existing
├── .env.example                        # MOVE from repo_bootstrap
│
├── repo-report.fsx                     # KEEP (F# report generator)
├── repo-report-tests.fsx              # KEEP (F# tests)
├── test-report.fsx                     # KEEP (test runner)
├── package.json                        # KEEP (Playwright)
├── playwright.config.js                # KEEP
│
├── .claude/
│   ├── settings.local.json             # KEEP
│   └── skills/                         # KEEP existing project skills
│       ├── build/
│       ├── ci-prep/
│       ├── fmt/
│       ├── lint/
│       ├── submit-pr/
│       └── test/
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                      # KEEP (project-specific)
│   │   └── release.yml                 # KEEP (project-specific)
│   └── pull_request_template.md        # KEEP
│
├── .devcontainer/                      # KEEP (project-specific Flutter devcontainer)
│
├── project_status_ui/                  # KEEP (Flutter app)
│
├── tests/                              # KEEP (Playwright tests)
│
├── enforce-repo-standards/             # MOVE from repo_bootstrap (global skill)
│   ├── SKILL.md
│   └── references/
│
├── templates/                          # MOVE from repo_bootstrap
│   ├── CLAUDE.md                       # Template for other repos
│   ├── AGENTS.md
│   ├── Makefile
│   ├── .editorconfig
│   ├── .cursorrules
│   ├── .windsurfrules
│   ├── opencode.json
│   ├── .clinerules/
│   ├── .github/                        # Template workflows
│   ├── devcontainer/                   # 7 language-specific configs
│   ├── gitignore/                      # Language-specific gitignores
│   ├── linting/                        # Language-specific linter configs
│   ├── coverage/                       # Coverage config templates
│   └── skills/                         # Template skills for other repos
│       ├── ci-prep/
│       ├── code-dedup/
│       ├── fmt/
│       ├── lint/
│       ├── submit-pr/
│       └── test/
│
└── docker files
```

## Steps

### 1. Move top-level docs from repo_bootstrap
- `mv` AGENT-PMO-WORKFLOW.md → project_status root
- `mv` REPO-STANDARDS-SPEC.md → project_status root
- `mv` .env.example → project_status root

### 2. Move enforce-repo-standards/
- `mv` repo_bootstrap/enforce-repo-standards/ → project_status/enforce-repo-standards/
- Update path references inside SKILL.md (repo_bootstrap → current repo paths)

### 3. Move templates/
- `mv` repo_bootstrap/templates/ → project_status/templates/
- Path references in enforce-repo-standards/SKILL.md need updating (templates/ stays relative, should still work)

### 4. Move Docker files to root/

### 5. Merge Makefile
- Add `install-skill` and `uninstall-skill` targets from repo_bootstrap Makefile to project_status Makefile
- Keep all existing Flutter build targets

### 6. Merge .gitignore
- project_status's is already comprehensive
- Add `.env` pattern (already has it actually — `.env` line exists)
- No changes needed

### 7. Merge CLAUDE.md
- Keep the project-specific CLAUDE.md as-is
- Add a section about the repo_bootstrap/templates component
- Update the Architecture section to reflect new folder structure
- Update project overview to mention "Agent PMO Workflow"

### 8. Rewrite README.md
- New unified README covering the full Agent PMO Workflow
- Reference AGENT-PMO-WORKFLOW.md for the full vision
- Cover both components: dashboard (repo-report) and standards enforcement (enforce-repo-standards/templates)
- Keep existing usage docs (running, config, launchd, tests)

### 9. Update internal path references
- enforce-repo-standards/SKILL.md: update `~/Documents/Code/repo_bootstrap` fallback path to `~/Documents/Code/project_status`
- AGENT-PMO-WORKFLOW.md: update repo links/references
- REPO-STANDARDS-SPEC.md: update template path references
- docker files

### 10. Clean up repo_bootstrap
- After all moves, only .git/ and empty dirs should remain in repo_bootstrap
- Leave it for the user to archive/delete

## Files requiring CONTENT merges (not just moves)

| File | Action |
|------|--------|
| `Makefile` | Add install-skill/uninstall-skill targets |
| `CLAUDE.md` | Add templates/enforce-repo-standards sections, update architecture |
| `README.md` | Full rewrite as unified project README |
| `enforce-repo-standards/SKILL.md` | Update path fallback from repo_bootstrap → project_status |
| `AGENT-PMO-WORKFLOW.md` | Update repo references after move |
| docker files

## Files that are pure MOVES (no content changes)

- REPO-STANDARDS-SPEC.md
- .env.example
- enforce-repo-standards/references/*
- templates/* (entire tree)
- Docker files

## Verification

1. `ls -R` to confirm all files landed correctly
2. `make help` to verify merged Makefile works
3. Check enforce-repo-standards/SKILL.md path resolution still works
4. Confirm repo_bootstrap/ only has .git/ left
5. Run `make test` or `dotnet fsi test-report.fsx` to verify nothing broke
