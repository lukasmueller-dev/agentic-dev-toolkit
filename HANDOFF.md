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

Milestones 1–5 are done and ticked in `SPEC.md`. `origin/main` (#144, no day/night window) is merged. `/fill-queue` writes `lane=` and `item=`; `docs/vibe-queue.md` has a `## Lanes` section. `bats tests/` passes except 3 sandbox-only `install.bats` tests.

## Next action

Milestone 6 of `SPEC.md` (`/review-jobs`). Done when `./bin/skill-lint --strict skills` and `bats tests/` pass, and `grep -c 'lane' skills/review-jobs/SKILL.md` prints ≥3.

- `skills/review-jobs/SKILL.md`: a lane row gets one decision (ready, requeue, hold, close). Offer it only when each item is done or out of the lane; until then the row shows its progress (`3/5`).
- Requeue of an item out of the lane (`side` in its job dir): queue it on the lane branch while the lane PR is open, else on a new branch from the default branch. Its prompt names `git diff <start>..<side-branch>` as an earlier try. The `requeue` text in Phase 3 now assumes `HANDOFF.md` on the job's own branch; a side branch has the WIP commit instead.
- Add one line to `docs/vibe-queue.md` `## Lanes` for the retry rule.
- Stage new files under `skills/` before `bats tests/`.

## Blockers

None.

## Gotchas (unpromoted)

- PR #133 (runner gate) and the queued `job-review` job also change `job_run` / `job_publish`. If one is on `main`, merge `origin/main` first.
- 3 `tests/install.bats` tests (45, 51, 52) fail inside the job sandbox: `.claude/` placeholder files. In a `git clone` under `$TMPDIR` all 55 pass. Check from a clone: commit first, then `git fetch <worktree> HEAD` in the clone.
- `shfmt -f .` and `shellcheck` hit permission errors on the placeholder files: run them over `git ls-files`.
- `lane_leave` runs under `|| true`, so errexit is off inside it: each step guards itself with `|| return 0`.
