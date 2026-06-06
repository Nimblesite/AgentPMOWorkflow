<div align="center">

# Agent PMO

### Stop Watching One Agent. Start Running Twenty.

<p>
  <a href="https://github.com/Nimblesite/AgentPMOWorkflow/actions"><img src="https://img.shields.io/github/actions/workflow/status/Nimblesite/AgentPMOWorkflow/ci.yml?branch=main&label=CI&style=flat-square" alt="CI status"></a>
  <a href="https://github.com/Nimblesite/AgentPMOWorkflow/releases"><img src="https://img.shields.io/github/v/release/Nimblesite/AgentPMOWorkflow?style=flat-square" alt="Latest release"></a>
  <a href="https://github.com/Nimblesite/AgentPMOWorkflow/blob/main/LICENSE"><img src="https://img.shields.io/github/license/Nimblesite/AgentPMOWorkflow?style=flat-square" alt="License"></a>
</p>

```
┌──────────────────────────────────────────────────┐
│               PMO Dashboard · 4 active           │
├──────────────────────────────────────────────────┤
│  ✓ app-backend    PR #47 open   CI ● green       │
│  ⚠ data-pipeline  3 failing    CI ● running      │
│  ✓ mobile-client  review        CI ● green       │
│  ↻ api-gateway    linting       CI ● pending     │
└──────────────────────────────────────────────────┘
        ↓ dispatch       ↓ dispatch      ↓ dispatch
   [Agent: feature]  [Agent: CI fix]  [Agent: coverage]
```

</div>

---

## The Problem

You've got an AI coding agent. It writes code, opens a PR, pushes to CI. CI fails. The agent goes back, fixes it, pushes again. You sit there watching — mentally tethered to one project, waiting for the green check before you can give the next instruction.

The agent is productive. **You're serialized.**

One project. One agent. One task at a time. Dead time between every step.

## The Solution

**Agent PMO is a Project Management Office where the staff are AI agents.**

The job isn't making one agent faster — it's making *you* capable of running dozens of projects simultaneously, with minimal cognitive load.

While one agent fights through CI, you've dispatched two others. You're not waiting. You're deciding what to review next.

---

## Two Components

### PMO Dashboard &nbsp;(`dashboard/`)

An F# script scans every repo under `~/Documents/Code/`, collects CI status, open PRs, uncommitted changes, and push status, then generates a self-contained HTML report refreshed every 3 minutes via launchd. You see everything at a glance. No context-switching into individual repos.

### Repo Standards Enforcement &nbsp;(`agent-pmo-skill/`)

A skill that applies portfolio-wide templates to any repo: same Makefile targets, same CI pipeline, same lint and format commands. Drop an agent into any standardized project and it already knows how to run, test, and ship — no setup, no babysitting. That's what makes twenty projects manageable instead of twenty separate headaches.

---

## Quality Gates

Agents don't hand you rough drafts. Lint, type check, format, unit tests, integration tests, and coverage thresholds are all enforced by CI with no soft-fail mode. Coverage thresholds are monotonically increasing — they never regress. By the time code reaches you, every automated check has passed. You're the final gate: reviewing intent and architecture, not whether it compiles.

---

## Get Started

```bash
make setup       # install dependencies
make build       # generate the HTML dashboard
make test        # run full test suite
make ci          # lint + test + build
```

See [`docs/specs/REPO-STANDARDS-SPEC.md`](docs/specs/REPO-STANDARDS-SPEC.md) for the full standards spec and [`agent-pmo-skill/SKILL.md`](agent-pmo-skill/SKILL.md) for the enforcement skill.

---

<div align="center">

**You're not watching agents work. You're directing an engineering organisation.**

</div>
