---
name: ci-prep
description: Prepares the current branch for CI by analyzing the repo's CI workflow and running the exact same steps locally, fixing issues at each step. Use before pushing a branch or when the user wants to verify the branch will pass CI.
---

# CI Prep

Prepare the current state for CI. Ensures the branch will pass CI before pushing.

## Steps

### Step 1 — Analyze the CI workflow

1. Find the CI workflow file. Look in `.github/workflows/` for `ci.yml`, `build.yml`, `test.yml`, `checks.yml`, `main.yml`, `pull_request.yml`, or any workflow triggered on `pull_request` or `push`.
2. Read the workflow file completely. Parse every job and every step.
3. Extract the ordered list of commands the CI actually runs (e.g., `make lint`, `make fmt-check`, `make test`, `make coverage-check`, `make build`, or whatever the workflow specifies — it may use `npm`, `cargo`, `dotnet`, raw shell commands, or anything else).
4. Note any environment variables, matrix strategies, or conditional steps that affect execution.

**Do NOT assume the steps are `make lint`, `make test`, `make coverage-check`, `make build`.** The actual CI may run different commands, in a different order, with different targets. Extract what the CI *actually does*.

### Step 2 — Run each CI step locally, in order

For each command extracted from the CI workflow:

1. Run the command exactly as CI would run it (adjusting only for local environment differences like not needing `actions/checkout`).
2. If the step fails, **stop and fix the issues** before continuing to the next step.
3. After fixing, re-run the same step to confirm it passes.
4. Move to the next step only after the current one succeeds.

### Step 3 — Report

- List every step that was run and its result (pass/fail/fixed).
- If any step could not be fixed, report what failed and why.
- Confirm whether the branch is ready to push.

## Rules

- **Always read the CI workflow first.** Never assume what commands CI runs.
- Do not push if any step fails
- Fix issues found in each step before moving to the next
- Never skip steps or suppress errors
- If the CI workflow has multiple jobs, run all of them (respecting dependency order)
- Skip steps that are CI-infrastructure-only (checkout, setup-node/python/rust actions, cache steps, artifact uploads) — focus on the actual build/test/lint commands

## Success criteria

- Every command that CI runs has been executed locally and passed
- All fixes are applied to the working tree
