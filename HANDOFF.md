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

Milestones 1–4 are done and ticked in `SPEC.md`. `group_of JOB` (`bin/vibe`) sets `GROUP` and the lane row for `vibe queue status` and `report_rows`. `bats tests/vibe-queue.bats` passes (30).

## Next action

Milestone 5 of `SPEC.md` (`/fill-queue` + docs). Done when `./bin/skill-lint --strict skills` and `bats tests/` pass, and `grep -c 'lane=' docs/vibe-queue.md skills/fill-queue/SKILL.md` prints ≥1 for each file.

- `skills/fill-queue/SKILL.md`: Phase 4 proposes lanes (one tag or one roadmap heading, light non-GPU items). Phase 5 table gets a `lane` column. Phase 6 writes `lane=` and `item=` and one job per item on the lane branch.
- The queued-branch rule (line 20, `QUEUED` from `skills/fill-queue/sweep.sh`) admits the jobs of one new lane. No item joins a queued or open lane branch.
- `docs/vibe-queue.md` gets the lane rules and both keys. The status and briefing lines already name the lane row.
- `skills/fill-queue/references/job-prompt.md` already holds the lane TL;DR rule (milestone 2).
- Stage new files under `skills/` before `bats tests/`.

## Blockers

None.

## Gotchas (unpromoted)

- `origin/main` has 2 new commits (#144, `refactor(queue)`: no day/night window). The merge is clean, but its `tests/vibe-queue.bats` has no `window` helper. After the merge, replace `window closed 1` in the lane tests with `slots 1`, or drop it.
- PR #133 (runner gate) and the queued `job-review` job also change `job_run` / `job_publish`. If one is on `main`, merge `origin/main` first.
- 3 `tests/install.bats` tests (45, 51, 52) fail inside the job sandbox: `.claude/` placeholder files. In a `git clone` under `$TMPDIR` all 55 pass.
- `lane_leave` runs under `|| true`, so errexit is off inside it: each step guards itself with `|| return 0`.
