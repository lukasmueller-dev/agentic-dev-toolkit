# Handoff — agentic-dev-toolkit / vibe-lanes

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `vibe-lanes`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/vibe-lanes
- **Last updated:** 2026-10-29 · turing

## State

Milestones 1 and 2 are done and ticked in `SPEC.md`. `lane_body` (`bin/vibe`) prints the PR in the `pr.md` shape: line 1 is the title, then the TL;DR of the latest done item. `job_prepare` writes `lane-pr.md`. `bats tests/vibe-queue.bats` passes.

## Next action

Milestone 3 of `SPEC.md` (failure path). Done when `bats tests/vibe-queue.bats` passes with a new test: a failed lane job leaves the lane branch at its start commit and its work on `<branch>-<item>`, and the next lane job runs.

- Write the start commit in `job_prepare` (job dir file, for example `start`).
- Write the side-branch name to `$job/side`. `lane_body` already reads that file; without it, it falls back to `<branch>-<item>`.
- `job_publish JOB STATUS` takes the job's status as arg 2. Run the failure path in `job_run` before that call.
- The test stub has a mode `item` (reads `item=` from the job file, commits `<item>.txt`) and `blocked`, `crash` modes. A failed lane job with a commit needs a new stub mode.

## Blockers

None.

## Gotchas (unpromoted)

- PR #133 (runner gate) and the queued `job-review` job also change `job_run` / `job_publish` in `bin/vibe`. If one of them is on `main`, merge `origin/main` first. On 2026-10-29 `origin/main` has neither.
- 3 `tests/install.bats` tests (45, 51, 52) fail inside the job sandbox: `.claude/` placeholder files in the worktree root.
