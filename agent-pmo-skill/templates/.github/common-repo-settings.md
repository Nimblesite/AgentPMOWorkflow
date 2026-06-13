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

If protection already exists, do nothing.
Else add branch protection with the ci.yaml script. It should only fire on PRs to main and a PR is required

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
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -f has_wiki=false \
  -f has_projects=false \
  -f has_discussions=true

# Dependabot: enable alerts + automated security update PRs (per-repo).
# Grouping is provided by the committed .github/dependabot.yml; grouped SECURITY
# updates + "auto-enable for new repos" are account/org toggles set in the UI.
gh api -X PUT "repos/$REPO/vulnerability-alerts"        # Dependabot alerts
gh api -X PUT "repos/$REPO/automated-security-fixes"    # Dependabot security updates
```
