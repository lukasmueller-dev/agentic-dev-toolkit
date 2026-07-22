# Handoff — agentic-dev-toolkit / ci-opt-in-label

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ci-opt-in-label`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/ci-opt-in-label
- **Last updated:** 2026-07-22 · server (srv1841294)

## State

Not started — design settled. CI on GitHub must stop running automatically on
every PR: Actions minutes are billed (the macOS test leg at 10× private-repo
pricing), and the account currently has a billing failure that makes every
run fail at job start anyway. Chosen approach: **label-gating**. The four
jobs in `.github/workflows/ci.yml` (lint, test matrix, validate) run on
`pull_request` only when the PR carries the `run-ci` label; adding the label
triggers the run. `workflow_dispatch` stays as a manual backstop, and the
`push: branches: [main]` trigger stays automatic — post-merge verification
is the last net, and merges are rare compared to PR pushes.

Rejected: manual-dispatch-only (PRs would silently show no checks; forgetting
is how a stray file recently reached the default branch), and gating only the
macOS leg (does not deliver "workflows optional per PR").

## Next action

Edit `.github/workflows/ci.yml`:

1. Give the `pull_request` trigger explicit
   `types: [opened, synchronize, reopened, labeled]` — `labeled` is not a
   default activity type, and without it adding the label starts nothing.
2. Add a job-level guard to all four jobs:
   `if: github.event_name != 'pull_request' || contains(github.event.pull_request.labels.*.name, 'run-ci')`
   so push-to-main and manual dispatch keep running unconditionally.

Then create the label
(`gh label create run-ci --color 0E8A16 --description "Run CI on this PR"`)
and document the opt-in in the repo instruction file's CI/pre-commit section.

## Blockers

GitHub Actions is disabled account-wide by a billing/spending-limit failure —
label-triggered runs cannot be verified end-to-end until that is fixed in
GitHub Settings → Billing & plans.

## Gotchas (unpromoted)

Skipped jobs report as "skipped", which the merge box treats as passing —
required checks are not configurable on a private Free-plan repo, so an
unlabeled PR shows no signal at all; the local pre-push hook and the test
suite remain the real gate. The existing `concurrency` block already cancels
duplicate runs when a label event and a push race.
