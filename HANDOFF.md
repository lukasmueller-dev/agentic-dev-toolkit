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

Milestone 1 is done and ticked in `SPEC.md`: `job_publish` builds the lane PR (`lane_body`, `lane_jobs` in `bin/vibe`). `bats tests/vibe-queue.bats` passes.

## Next action

Milestone 2 of `SPEC.md` (lane TL;DR, added after milestone 1). Done when `bats tests/vibe-queue.bats` passes with a new test: a 3-item lane body has the TL;DR of the last done item, one `<details>` per item, and ≤12 lines above the first `<details>`.

Then milestone 3 (failure path):

- Write the side-branch name to `$job/side`. `lane_body` already reads that file; without it, it falls back to `<branch>-<item>`.
- `job_publish JOB STATUS` takes the job's status as arg 2. Run the failure path in `job_run` before that call.
- The test stub has a mode `item` (reads `item=` from the job file, commits `<item>.txt`).

## Blockers

None.

## Gotchas (unpromoted)

- PR #133 (runner gate) and the queued `job-review` job also change `job_run` / `job_publish` in `bin/vibe`. If one of them is on `main`, merge `origin/main` first. On 2026-10-29 `origin/main` has neither.
- 3 `tests/install.bats` tests (45, 51, 52) fail inside the job sandbox: `.claude/` placeholder files in the worktree root.
