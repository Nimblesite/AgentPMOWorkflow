# Agent PMO — Stop Watching One Agent. Start Running Twenty.

## The Problem: You're Idle While Agents Work

You've got an AI coding agent. It's good. It writes code, writes tests, pushes a branch, opens a PR. Then CI runs. Maybe it fails. The agent goes back, fixes lint errors, pushes again. CI runs again. You sit there. Watching. Waiting.

The agent is busy. You are not.

You can't context-switch to another project because you're mentally tethered to this one — waiting to see if CI passes, waiting to review the PR, waiting to give the next instruction. So you check your phone. You read Hacker News. You come back ten minutes later, see a green check, approve the PR, and then — finally — give the agent its next task.

Multiply that across a day and you're spending more time waiting than deciding. The agent is productive. You're serialized. One project. One agent. One task at a time. And the dead time between tasks is enormous.

**This is the default experience of AI-assisted development in 2026.** The tooling makes one agent effective but does nothing to make *you* effective across multiple agents and multiple projects.

Agent PMO fixes that.

---

## The Core Idea

Agent PMO is a Project Management Office where the staff are AI agents. The job isn't making one agent faster — it's making *you* capable of running dozens of projects simultaneously, with minimal cognitive load.

```
┌─────────────────────────────────────────────────────────┐
│                    project_status                        │
│  ✓ app-backend      — PR #47 open, CI green             │
│  ⚠ data-pipeline    — 3 failing tests, agent working    │
│  ✓ mobile-client    — feature branch, awaiting review   │
│  ↻ api-gateway      — agent running lint + typecheck    │
└─────────────────────────────────────────────────────────┘
        ↓ dispatch           ↓ dispatch           ↓ dispatch
   [Agent: feature]    [Agent: CI fix]    [Agent: test coverage]
```

While one agent ships a feature, another fixes a failing CI check. Another writes tests. You're not waiting. You're deciding what to review next.

---

## Two Components. One System.

### Repo Standards Enforcement (`enforce-repo-standards/` + `templates/`)

Agents can't navigate chaos. If every project has a different structure, different scripts, different CI config — every project requires hand-holding. That hand-holding is what keeps you tethered to one project at a time.

**repo_bootstrap enforces consistency.** Every repo looks the same to an agent: same build targets, same CI pipeline, same linting and formatting rules, same PR workflow. Drop an agent into any project and it already knows how to run, test, and ship — no setup, no explanation, no babysitting.

This isn't cosmetic. It's what makes twenty projects manageable instead of twenty separate headaches.

#### What it standardizes

- **Build and test interface** — identical commands across every repo regardless of language
- **CI/CD pipelines** — same job names, same ordering (lint → test → build), same failure modes
- **Code quality configs** — linting, formatting, and type checking per language
- **Coverage enforcement** — thresholds that ratchet upward and never regress
- **Agent instructions** — a single source of truth that every AI coding tool reads from
- **Dev environment** — containerized setup so onboarding is one command

The full specification lives in the [repo standards spec](REPO-STANDARDS-SPEC.md). The [enforcement skill](enforce-repo-standards/SKILL.md) applies it automatically.

### The PMO Dashboard (`repo-report.fsx`)

**The dashboard is your control panel.** It surfaces the state of every project at once: CI status, uncommitted changes, open PRs, community contributions waiting for review.

You're not polling agents. You're not context-switching into each repo to figure out what's happening. The dashboard tells you. You decide where to direct attention.

---

## How It Works

### Step 1 — Standardize your repos

Run the enforcement skill against each repo. It detects the languages present, audits what already exists, and fills in anything missing — build targets, CI pipelines, linting configs, coverage thresholds, agent instructions. Existing configs are merged, not overwritten. Nothing is committed automatically; you review first.

New repos get minted from scratch. Existing repos get remediated incrementally. Either way, the result is the same: a repo that conforms to the [standard spec](REPO-STANDARDS-SPEC.md).

### Step 2 — Agents work autonomously

Once a repo is standardized, any agent can pick up a task — write a feature, fix a bug, improve test coverage — without needing hand-holding. The agent knows how to build, test, lint, and format because every repo exposes the same interface. Quality gates are baked in: the agent fights through lint errors, test failures, and coverage thresholds on its own.

**This is what eliminates your idle time.** While Agent A is fighting through CI on the backend service, you've already dispatched Agent B to add test coverage on the mobile client and Agent C to fix a bug on the API gateway. You're not blocked on any of them.

### Step 3 — Monitor the dashboard

The dashboard shows all projects at a glance. Which repos have open PRs? Which have failing CI? Which have agents actively working? You scan, decide where to direct attention, and move on. No context-switching into individual repos unless you choose to.

### Step 4 — Review at the altitude you choose

By the time anything reaches you, it has already passed every automated check. Your review is about intent, architecture, and edge cases — not whether the code compiles or the tests pass.

---

## Quality Gates

Agents don't hand you rough drafts. They fight through quality gates the entire way.

**Lint. Type check. Format check. Unit tests. Integration tests. Coverage thresholds. CI. PR review.**

The pipeline is enforced in order. Format violations tank the pipeline. Coverage below threshold tanks the pipeline. There is no soft-fail mode.

By the time code reaches you, it has already passed every automated check. You're not the first line of defense — you're the **final gate**. Human review is reserved for what humans are actually good at: intent, architecture, edge cases.

The agents handle correctness. You handle judgment.

Coverage thresholds are per-project and **monotonically increasing** — they never go down. When coverage improves past the current threshold, the threshold bumps up to match. Quality only ever moves in one direction.

---

## The Uniform Interface

The power of this system is that every standardized repo exposes the **exact same interface**. An agent dropping into any project can build, test, lint, format, and run CI with the same commands. CI job names are fixed. Branch naming follows a standard convention. PR templates are identical.

Zero guessing. Zero context-switching overhead. That's what makes it possible to run twenty projects instead of one.

---

## Worktrees: Parallelism Inside a Monolith

Got a large repo? A monolith? A multi-service codebase that can't be split up?

**[Git worktrees](https://git-scm.com/docs/git-worktree) solve this.** Each agent gets its own worktree — an isolated branch checked out at a different path. Same repo, no conflicts, no stepping on each other. A monolith becomes the equivalent of multiple parallel workstreams.

---

## TMC — The Conductor

**Too Many Cooks (TMC)** is project-level agent orchestration. TMC coordinates agents within a project and across projects — dispatching work, managing dependencies, avoiding conflicts.

TMC doesn't just parallelize. It sequences. If a feature branch needs passing tests before a PR opens, TMC enforces that. If two projects share a library, TMC knows. It turns a pool of capable agents into a coherent engineering organization.

Agents register on start, lock files before editing, broadcast their plans, and release locks when done. No agent edits a file another agent is working on.

---

## Your Level of Involvement

You decide how deep you go.

**Review every commit?** The worktree branches are there, diffs are clean, tests passed.

**Review only PRs?** Also valid. Every PR is already production-ready by automated standards. Your review is about the *what*, not the *whether it works*.

**Set direction and check the dashboard?** That's an option too. You're still shipping — just operating at a different altitude.

---

## Guardrails

These are non-negotiable across the system:

- **Standards are updated and regularly propagated across all projects.** Every template is tailored to the target repo's actual languages and tools but stays in sync with the repo standards.
- **One source of truth for agent instructions.** All AI coding tools read from the same file. No divergent rulesets across different agents.
- **Coverage never regresses.** Thresholds ratchet upward only.
- **CI pipelines fail fast and fail loud.** Lint before test. Test before build. Zero warnings allowed.

---

## This Is How You Manage Twenty+ Projects, Not One

This isn't about building one app faster. It's about running dozens of projects simultaneously — microservices, mobile clients, backend APIs, internal tools — all moving forward at the same time, all held to the same standards, all visible in one place.

Most people in the AI era are still serialized. Watching one agent. Waiting. Agent PMO breaks that pattern.

**You're not watching agents work. You're directing an engineering organization.**

That's Agent PMO.
