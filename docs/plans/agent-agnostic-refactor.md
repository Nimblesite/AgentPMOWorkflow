# Plan: Make Repository Standards Agent-Agnostic

> Make the enforce-repo-standards templates and skill work for any AI coding agent, not just Claude.

## Problem

Currently, `CLAUDE.md` is the single source of truth in every target repo. All other agent files (AGENTS.md, .cursorrules, .clinerules, .windsurfrules, copilot-instructions.md, opencode.json) are pointer files that say "read CLAUDE.md". This:

1. **Assumes Claude is always the primary agent** — repos primarily using Cursor, Cline, Windsurf, or Copilot still get their rules in a Claude-branded file
2. **Creates friction** — developers using other agents see "Claude Instructions" as the heading of their project rules
3. **Couples content to tooling** — the actual rules (hard rules, logging standards, build commands) are agent-neutral but live in a Claude-specific file

## Design

### Core Principle

The **rules content** (hard rules, logging, testing, build commands, architecture) is agent-neutral. The **file it lives in** depends on which agent the target repo primarily uses.

### New Architecture

1. **Template file:** `templates/AGENTS.md` becomes the canonical template containing ALL rules. It uses neutral language ("Agent Instructions" not "Claude Instructions"). No Claude-specific references (skills links, `.claude/` paths) in the generic content.

2. **Claude-specific addendum:** A small `templates/CLAUDE-ADDENDUM.md` template contains Claude-only content (skills configuration, `.claude/` directory structure, Claude-specific links). This gets appended to CLAUDE.md when Claude is the primary agent.

3. **Agent detection:** The skill inspects the target repo to determine the primary agent before deciding which file gets the full content.

4. **File placement rules:**

| Primary Agent | Full content goes in | All other agent files become |
|---|---|---|
| Claude Code | `CLAUDE.md` | Pointer files → `CLAUDE.md` |
| Cursor | `AGENTS.md` | Pointer files → `AGENTS.md` |
| Cline / Roo | `AGENTS.md` | Pointer files → `AGENTS.md` |
| Windsurf | `AGENTS.md` | Pointer files → `AGENTS.md` |
| GitHub Copilot | `AGENTS.md` | Pointer files → `AGENTS.md` |
| No agent / Unknown | `AGENTS.md` | Pointer files → `AGENTS.md` |

When Claude IS the primary agent, CLAUDE.md gets the full AGENTS.md content PLUS the Claude addendum (skills, `.claude/` directory). AGENTS.md becomes a pointer to CLAUDE.md (backwards compatible with current behavior).

When Claude is NOT the primary agent, AGENTS.md gets the full content. CLAUDE.md becomes a pointer to AGENTS.md (reversed from current behavior). Claude-specific content (skills) is still placed in `.claude/skills/` since that's a Claude Code convention that doesn't affect other agents.

### Agent Detection Heuristics

The skill checks these signals (in priority order) to determine the primary agent:

| Signal | Indicates |
|---|---|
| `.claude/settings.json` or `.claude/settings.local.json` exists | Claude Code |
| `.claude/skills/` has custom skills (not just template skills) | Claude Code |
| `.cursor/` directory exists | Cursor |
| `.cline/` or `.clinerules/` with custom rules (not just pointer) | Cline / Roo |
| `.windsurf/` directory exists | Windsurf |
| `.github/copilot-instructions.md` with substantial content (not just pointer) | GitHub Copilot |
| `CLAUDE.md` exists with substantial content (not just pointer) | Claude Code |
| `AGENTS.md` exists with substantial content | Agent-neutral (keep as-is) |
| None of the above | Default to AGENTS.md |

"Substantial content" = more than 10 lines and NOT just a pointer/redirect.

### What Changes in Each File

#### `templates/AGENTS.md` (NEW — full content)
- Rename heading: "Agent Instructions" (not "Claude Instructions")
- Move ALL content from current `templates/CLAUDE.md` here
- Remove Claude-specific references (skills links, `.claude/` paths)
- Keep: hard rules, logging standards, testing rules, build commands, architecture template

#### `templates/CLAUDE.md` (CHANGED — pointer OR full)
- Becomes a pointer template: "Read AGENTS.md for all rules"
- Used when Claude is NOT the primary agent
- When Claude IS primary, the skill copies AGENTS.md content into CLAUDE.md and appends Claude addendum

#### `templates/CLAUDE-ADDENDUM.md` (NEW)
- Claude-specific content only:
  - Skills section (links to Claude skill docs)
  - `.claude/skills/` directory in architecture diagram
  - Any Claude Code-specific workflow notes

#### All pointer templates (`.cursorrules`, `.clinerules/`, `.windsurfrules`, `copilot-instructions.md`, `opencode.json`)
- Updated to reference `{{CANONICAL_FILE}}` instead of hardcoded `CLAUDE.md`
- The skill fills in the correct filename based on agent detection

### What Does NOT Change

- **Root CLAUDE.md of this repo** (`project_status/CLAUDE.md`) — stays Claude-specific, it's for THIS workspace
- **Skills templates** (`templates/skills/`) — these are Claude Code skills by nature, they stay as-is
- **The actual rules content** — hard rules, logging, testing, formatting, build commands — all stays the same, just moves to AGENTS.md

## TODO

- [x] Write this plan
- [x] Update `docs/specs/REPO-STANDARDS-SPEC.md` §10 with new agent-agnostic architecture
- [x] Update `enforce-repo-standards/SKILL.md` with agent detection step
- [x] Refactor `templates/CLAUDE.md` content → `templates/AGENTS.md`
- [x] Create `templates/CLAUDE-ADDENDUM.md` with Claude-specific content
- [x] Update `templates/CLAUDE.md` to be a pointer to AGENTS.md
- [x] Update all pointer templates to use `{{CANONICAL_FILE}}`
- [x] Update §15 checklist in spec
- [x] Update §16 substitution variables (add `{{CANONICAL_FILE}}`)
- [x] Update root CLAUDE.md architecture diagram
