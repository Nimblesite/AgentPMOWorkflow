# Common Repository Settings

Standard GitHub repo settings to apply across every repository in the
portfolio. Apply these to bring any repo into line with the portfolio-wide
conventions described below.

## Merge Settings

| Setting | Value | Notes |
|---|---|---|
| Allow squash merge | **true** | Only merge strategy allowed |
| Allow merge commit | **false** | Disabled to keep linear history |
| Allow rebase merge | **false** | Disabled to keep linear history |
| Allow auto merge | **true** | PRs merge automatically when checks pass |
| Delete branch on merge | **true** | Clean up merged branches |
| Allow update branch | **true** | Lets auto-merge refresh a stale PR branch so the strict up-to-date gate clears without a manual click |

## Squash Merge Commit Format

| Setting | Value |
|---|---|
| Squash merge commit title | **PR_TITLE** |
| Squash merge commit message | **PR_BODY** |

This means the final squash commit uses the PR title as the commit message
subject and the PR description as the commit body.

## Features

| Setting | Value | Notes |
|---|---|---|
| Issues | **true** | Enabled (GitHub default) |
| Wiki | **false** | Disabled - docs live in repo |
| Projects | **false** | Disabled on most customised repos (CommandTree and DataProvider still have it on) |
| Discussions | **true** | Enabled for community engagement (public repos only) |

## Branch Protection / Rulesets

Every repo MUST protect `main` with a ruleset (the `gh` command below creates or
repairs it). The ruleset MUST require ALL of:

- A PR to `main` — no direct pushes.
- The CI status check passes before merge (context = the `ci.yml` job name).
- **Branches up to date with `main` before merge —
  `strict_required_status_checks_policy: true`. NON-NEGOTIABLE.**

CI runs only on PRs and nothing re-runs on the merge itself, so the strict
up-to-date flag is the *only* thing that keeps the green check honest: it forces
the PR branch to contain the current tip of `main`, so the run that went green is
the run for the merged result. **Without `strict`, a PR whose CI passed against a
stale base merges and can silently break `main` — the green check is a lie.**

**A stale PR auto-recovers — no manual click.** `strict` must never strand a PR
behind `main`. With auto-merge enabled on the PR (`gh pr merge --auto --squash`)
**and** `allow_update_branch: true` on the repo (see Merge Settings above), GitHub
auto-updates the PR branch from `main` whenever `main` advances under it; that
update re-runs CI against the fresh base, and the PR squash-merges the instant
that run is green. So `strict` turns "behind `main`" into "auto-update from `main`
and try again" with zero human steps — only a real merge conflict needs a person.

**Existence is NOT conformance — never "do nothing because protection exists."**
A ruleset with `strict_required_status_checks_policy: false` is the exact failure
this prevents. When protection already exists, verify the strict flag and repair
it in place if it is off. The `gh` command below is idempotent and does this.

## Other

| Setting | Value |
|---|---|
| Default branch | **main** |
| Web commit signoff required | **false** |

## Dependabot (Supply-Chain Defense)

Outdated dependencies are the portfolio's biggest supply-chain attack surface.
Every repo MUST have Dependabot on — but grouped, so it patches dependencies
**without blanketing the repo in PRs**.

| Setting | Value | Notes |
|---|---|---|
| Dependabot alerts | **on** | Surfaces known vulnerabilities |
| Dependabot security updates | **on** | Auto-opens PRs that resolve alerts |
| Grouped security updates | **on** | One PR per ecosystem, not one per advisory |
| Automatically enable for new repositories | **on** | Set at the account/org level so future repos inherit this |

Grouped *version* updates come from the committed `.github/dependabot.yml`
(template: [`dependabot.yml`](dependabot.yml)). Its `groups:` rules also apply
to security updates, so security fixes land grouped too. Keep only the
`package-ecosystem` blocks the repo actually uses; keep `github-actions` for any
repo with workflows.

The three toggles and "auto-enable for new repos" live on the account/org
**Settings → Code security** page (the "Enable all" / "Automatically enable for
new repositories" controls) — set them there once.

## Code Scanning & Secret Scanning (GitHub Advanced Security)

Free for **public** repos; requires GHAS (Code Security / Secret Protection) on
private repos. Every PR must undergo security scanning.

| Feature | Where | Notes |
|---|---|---|
| CodeQL code scanning | `.github/workflows/codeql.yml` | Finds vulnerable *code*. Matrix tailored per repo (languages ∩ CodeQL-supported-at-runtime) + `actions`. Self-skips on private repos via a visibility gate. **HARD release gate:** `release.yml` calls it with `gate: true` and the publish jobs `needs:` it, so a High/Critical finding blocks publishing ([GITHUB-CODE-SCANNING]). |
| Dependency review | `security` job in `ci.yml` | Fails PRs that add vulnerable *dependencies* (`fail-on-severity: high`). |
| Secret scanning | repo setting (below) | Detects committed keys/tokens. |
| Push protection | repo setting (below) | Blocks a push that contains a secret before it leaves the machine. |
| Private vulnerability reporting | repo setting (below) | "Report a vulnerability" button on the Security tab. Pairs with `SECURITY.md`. |
| Security policy | `SECURITY.md` (root or `.github/`) | How to report + supported versions. Template: [`../SECURITY.md`](../SECURITY.md). |

**Anti-duplication (saves Actions minutes = money): exactly one owner per concern.**
linting = style · CodeQL = vulnerable code · ONE dependency scanner (dependency-review
*or* a native vuln-gate, never both) · platform secret scanning = secrets. Never add
security-rule linter plugins that re-cover CodeQL, and never run GitHub default-setup
CodeQL alongside a committed `codeql.yml`. CodeQL triggers: PR to main + weekly +
a `workflow_call` (gate input) — NO standalone `push: tags` scan (it can only file
alerts after the artifact ships). `build-mode: none` where allowed so it doesn't
re-compile what `ci.yml` already builds.

**CodeQL gates releases.** `release.yml` calls `codeql.yml` with `gate: true` and the
publish jobs `needs:` it; on a High/Critical finding (`security-severity >= 7.0`) the
job fails and the release is blocked — a release can never ship code CodeQL flagged.
For the PR gate to have teeth too, make the CodeQL check a **required status check** on
the `main` ruleset and set the code-scanning **check-failure severity** (Settings → Code
security → Code scanning → "Protection rules") to at least High.

CodeQL docs: see [`SECURITY.md`](../SECURITY.md) for the GitHub policy/PVR doc links.

## `gh` CLI Commands to Apply These Settings

```bash
# Replace OWNER/REPO with the target repository
REPO="OWNER/REPO"

gh api -X PATCH "repos/$REPO" \
  -f allow_squash_merge=true \
  -f allow_merge_commit=false \
  -f allow_rebase_merge=false \
  -f allow_auto_merge=true \
  -f delete_branch_on_merge=true \
  -f allow_update_branch=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -f has_wiki=false \
  -f has_projects=false \
  -f has_discussions=true

# Branch protection ruleset on the default branch.
# The strict up-to-date flag is MANDATORY: CI runs only on PRs and nothing
# re-runs on merge, so strict is the only guarantee the merged result passed CI.
# Idempotent: create if absent, else REPAIR the strict flag (never "do nothing").
# Replace "CI" with the exact check name your ci.yml job reports.
RULESET_ID=$(gh api "repos/$REPO/rulesets" \
  --jq '.[] | select(.name=="Protect main") | .id')
if [ -z "$RULESET_ID" ]; then
  gh api -X POST "repos/$REPO/rulesets" --input - <<'JSON'
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"] } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [ { "context": "CI" } ] } }
  ]
}
JSON
else
  # Protection exists — enforce strict in place; existence is not conformance.
  gh api "repos/$REPO/rulesets/$RULESET_ID" \
    | jq '{name, target, enforcement, bypass_actors, conditions, rules}
          | .rules |= map(if .type == "required_status_checks"
                          then .parameters.strict_required_status_checks_policy = true
                          else . end)' \
    | gh api -X PUT "repos/$REPO/rulesets/$RULESET_ID" --input -
fi

# Dependabot: enable alerts + automated security update PRs (per-repo).
# Grouping is provided by the committed .github/dependabot.yml; grouped SECURITY
# updates + "auto-enable for new repos" are account/org toggles set in the UI.
gh api -X PUT "repos/$REPO/vulnerability-alerts"        # Dependabot alerts
gh api -X PUT "repos/$REPO/automated-security-fixes"    # Dependabot security updates

# Secret scanning + push protection (GHAS; free for public repos).
gh api -X PATCH "repos/$REPO" --input - <<'JSON'
{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}
JSON

# Private vulnerability reporting (pairs with SECURITY.md; free for public repos).
gh api -X PUT "repos/$REPO/private-vulnerability-reporting"
```
