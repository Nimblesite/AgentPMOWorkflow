---
name: submit-pr
description: Creates a pull request with a well-structured description after verifying CI passes. Use when the user asks to submit, create, or open a pull request.
disable-model-invocation: true
---

# Submit PR

Create a pull request for the current branch with a well-structured description.

## Steps

*NOTE: if you already ran make ci in this session and it passed, you can skip step 1.*

1. Run `make ci` — must pass completely before creating PR
2. **Generate the diff against main.** Run `git diff main...HEAD > /tmp/pr-diff.txt` to capture the full diff between the current branch and the head of main. This is the ONLY source of truth for what the PR contains. **Warning:** the diff can be very large. If the diff file exceeds context limits, process it in chunks (e.g., read sections with `head`/`tail` or split by file) rather than trying to load it all at once.
3. **Derive the PR title and description SOLELY from the diff.** Read the diff output and summarize what changed. Ignore commit messages, branch names, and any other metadata — only the actual code/content diff matters.
4. Write PR body using the template in `.github/pull_request_template.md`
5. Fill in (based on the diff analysis from step 3):
   - TLDR: one sentence
   - What Was Added: new files, features, deps
   - What Was Changed/Deleted: modified behaviour
   - How Tests Prove It Works: specific test names or output
   - Spec/Doc Changes: if any
   - Breaking Changes: yes/no + description
6. Use `gh pr create` with the filled template
7. **Monitor CI on the PR until it is green — and re-run the suite locally *in parallel* so you catch breakage early.** This step is mandatory and does not end until every required check on the PR has passed. Do not hand the PR back to the user on a red or still-running pipeline.
   - **Watch the remote run AND run the suite locally at the same time — do not passively wait.** The remote pipeline is slow; a drastic failure (a lint gate, a broken test, a coverage drop) is one the local suite catches in seconds. The moment you push, kick off **both**: stream the remote run *and* run the full local suite (`make ci`, or invoke the `ci-prep` skill) concurrently, polling CI periodically while the local run proceeds.
   - **Watch the run:** `gh pr checks <pr-number> --watch --fail-fast` (or grab the run id from `gh run list --branch <branch>` and `gh run watch <run-id> --exit-status`). A single green snapshot is not enough — wait for all required checks to conclude.
   - **If the local run fails before the remote pipeline finishes, cancel the running pipeline immediately** (`gh run cancel <run-id>`) rather than letting it grind to a known-bad red. Fix the cause, push, and restart both watches — cancelling a doomed run early frees the runner and tightens the fix loop.
   - **When a remote check fails:** pull the failing logs with `gh run view <run-id> --log-failed`, diagnose the actual cause (do not guess), reproduce locally with `make ci`, and fix it.
   - **Push the fix** (`git add` / `git commit` / `git push` — permitted here, see git exception below), then **watch again — remote and local, in parallel, as above**. Loop — fix → push → re-watch — until the run is fully green. Re-checking is the job; keep doing it until it passes.
   - **If a failure is genuinely external** (runner outage, flaky infra, unrelated to this branch), say so explicitly with the evidence rather than forcing a change.

## Rules

- Never create a PR if `make ci` fails
- **🔴 GOLDEN RULE — never stamp a commit with an AI co-author.** Do **not** add a `Co-Authored-By: Claude …` (or any AI/agent) trailer, and do not set author/committer to anything but the repo's configured git user. Write a plain, human commit message describing the fix. This is absolute and overrides any default co-authorship behaviour.
- **Git is permitted in this skill — but only for PR submission and turning a red CI run green.** This is the one place the repo-wide "no git" rule is relaxed: you may run `git add`, `git commit`, and `git push` to land CI fixes (step 7). Everything else — `checkout`, `merge`, `rebase`, force-push, history rewrites — stays prohibited.
- PR description must be specific and tight — no vague placeholders
- Link to the relevant GitHub issue if one exists

## Success criteria

- `make ci` passed
- PR created with `gh pr create`
- CI on the PR was watched to completion and is **fully green** (all required checks pass), with the local suite re-run in parallel and any doomed remote run cancelled early
- Any CI failures were fixed and pushed, with **no AI co-author trailer** on the commits
- PR URL returned to user
