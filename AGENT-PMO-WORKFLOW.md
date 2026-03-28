# Agent PMO — Stop Watching One Agent. Start Running Twenty.

In the AI era, the human operator mostly takes a back seat while AI agents automate the busywork. What I've witnessed is that most of the user's day is dedicated to watching the agent write code and tests, push the code, draft PRs and wait for CI to complete — only to repeat this once the CI fails.

The agent is productive. You're serialized.

One project. One agent. One task at a time — with dead time between every step. **This is the default experience of AI-assisted development.** Agent PMO is the solution.

---

## The Core Idea

Agent PMO is a Project Management Office where the staff are AI agents. The job isn't making one agent faster — it's making *you* capable of managing multiple parallel projects with minimal cognitive load.

```
┌─────────────────────────────────────────────────────────┐
│                     PMO Dashboard                        │
│  ✓ app-backend      — PR #47 open, CI green             │
│  ⚠ data-pipeline    — 3 failing tests, agent working    │
│  ✓ mobile-client    — feature branch, awaiting review   │
│  ↻ api-gateway      — agent running lint + typecheck    │
└─────────────────────────────────────────────────────────┘
        ↓ dispatch           ↓ dispatch           ↓ dispatch
   [Agent: feature]    [Agent: CI fix]    [Agent: test coverage]
```

While one agent fights through CI, you've dispatched two others. You're not waiting. You're deciding what to review next.

---

## Two Components. One System.

### PMO Dashboard (`dashboard/`)

Your control panel. An F# script scans every repo under `~/Documents/Code/`, gathers status — CI results, uncommitted changes, open PRs, community contributions — and generates a self-contained HTML report, refreshed every 3 minutes via launchd.

You're not context-switching into each repo to figure out what's happening. The dashboard tells you. You decide where to direct attention. That's minimal cognitive load.

### Repo Standards Enforcement (`enforce-repo-standards/`)

Agents can't navigate chaos. If every project has a different structure, different scripts, different CI config — every project requires hand-holding. That hand-holding is what keeps you serialized.

**Consistency solves this.** Every standardized repo exposes the same interface: same build targets, same CI pipeline, same lint and format commands, same PR workflow. Drop an agent into any project and it already knows how to run, test, and ship — no setup, no babysitting.

That's what makes twenty projects manageable instead of twenty separate headaches. The full spec is in [docs/specs/REPO-STANDARDS-SPEC.md](docs/specs/REPO-STANDARDS-SPEC.md). The [enforcement skill](enforce-repo-standards/SKILL.md) applies it automatically.

---

## Quality Gates

Agents don't hand you rough drafts. They fight through quality gates the entire way.

**Lint. Type check. Format. Unit tests. Integration tests. Coverage thresholds. CI.**

There is no soft-fail mode. Format violations tank the pipeline. Coverage below threshold tanks the pipeline. By the time code reaches you, it has passed every automated check. You're not the first line of defense — you're the **final gate**. Human review is for intent, architecture, and edge cases.

Coverage thresholds are **monotonically increasing** — they never regress.

---

## Spec-Driven Development: The Traceability Matrix

Agents writing code is easy. Agents delivering *verified requirements* is the hard part — and it's what separates a functioning engineering organization from a pile of commits.

Every requirement gets a unique ID. That ID is the thread connecting everything:

```
[SPEC-001] User Authentication
    ↓ implemented by
  auth/login.py          // Implements [SPEC-001]
    ↓ verified by
  tests/test_auth.py     // Tests [SPEC-001]
    ↓ designed in
  docs/designs/auth.md   // Design for [SPEC-001]
    ↓ tracked in
  plans/sprint-4.md      // Plan item [SPEC-001]
    ↓ shipped via
  PR #42                 // Addresses [SPEC-001]
```

This is **bidirectional**. From any artifact — a test, a file, a PR, a design doc — you can trace back to the requirement it serves. From any spec, you can trace forward to every artifact that implements it.

The `enforce-repo-standards` skill audits this automatically: every spec has an ID, every test links to a spec, every implementation links to a spec. Orphaned code is flagged. Unimplemented specs are flagged. Nothing ships without a traceable chain from requirement to delivery.

When twenty agents are building in parallel, this is what keeps them aligned. Spec IDs are the backbone.

---

## Worktrees: Parallelism Inside a Monolith

Got a monolith or multi-service codebase that can't be split up? **[Git worktrees](https://git-scm.com/docs/git-worktree) solve this.** Each agent gets its own worktree — an isolated branch at a different path. Same repo, no conflicts, no stepping on each other. A monolith becomes multiple parallel workstreams.

---

## TMC — The Conductor

**Too Many Cooks (TMC)** is project-level agent orchestration. TMC dispatches work, manages dependencies, and avoids conflicts across agents and projects.

TMC sequences, not just parallelizes. If a feature branch needs passing tests before a PR opens, TMC enforces that. If two projects share a library, TMC knows. Agents register on start, lock files before editing, and release locks when done.

---

## Your Level of Involvement

**Review every commit?** Worktree branches are there, diffs are clean, tests passed.

**Review only PRs?** Valid. Every PR is already production-ready by automated standards. Your review is about the *what*, not the *whether it works*.

**Set direction and check the dashboard?** That's an option too. You're still shipping — just operating at a different altitude.

---

## This Is How You Manage Twenty Projects, Not One

Most people in the AI era are still serialized. Watching one agent. Waiting. Agent PMO breaks that pattern.

**You're not watching agents work. You're directing an engineering organization.**

That's Agent PMO.
