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

Milestones 1–3 are done and ticked in `SPEC.md`. `lane_leave` (`bin/vibe`) runs in `job_run` before `job_publish`. It WIP-commits, keeps the work on `<branch>-<item>`, resets the lane worktree to `$job/start`, and writes `$job/side`. `bats tests/vibe-queue.bats` passes (28).

## Next action

Milestone 4 of `SPEC.md` (lane rows). Done when `bats tests/vibe-queue.bats` passes with a new test: a 3-job lane prints one row in `vibe queue status`.

- `cmd_queue_status` and `queue_report_md` (`bin/vibe`) print one line per job today. Group by repo and branch when the branch has 2+ jobs with `lane=`.
- Row: `<branch> · <done>/<total> · <running or next item> · <PR>` and the `lane=` line. Below it: one row per job that needs the user (`blocked`, `failed`, `timeout`, `skipped`, with its `$job/side`).
- `lane_jobs JOB` lists the lane jobs of a branch; `lane_body` counts done and total the same way.
- A one-job branch prints as today.

## Blockers

None.

## Gotchas (unpromoted)

- `origin/main` has 2 new commits (#144, `refactor(queue)`: no day/night window). The merge is clean, but its `tests/vibe-queue.bats` has no `window` helper. After the merge, replace `window closed 1` in the lane tests with `slots 1`, or drop it.
- PR #133 (runner gate) and the queued `job-review` job also change `job_run` / `job_publish`. If one is on `main`, merge `origin/main` first.
- 3 `tests/install.bats` tests (45, 51, 52) fail inside the job sandbox: `.claude/` placeholder files. In a `git clone` under `$TMPDIR` all 55 pass.
- `lane_leave` runs under `|| true`, so errexit is off inside it: each step guards itself with `|| return 0`.
