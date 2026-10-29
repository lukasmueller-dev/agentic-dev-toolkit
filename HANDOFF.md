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

Milestones 1–6 are done and ticked in `SPEC.md`. `skills/review-jobs/SKILL.md` has a `### Lanes` section and the retry steps; `docs/vibe-queue.md` `## Lanes` has the retry rule. `bats tests/` passes except 3 sandbox-only `install.bats` tests (45, 51, 52; 55/55 in a clone).

## Next action

Milestone 7 of `SPEC.md` (end action). Done when `test ! -e SPEC.md` and `test ! -e HANDOFF.md`.

- Move each decision of `SPEC.md` to `pr.md` (`$VIBE_JOB_DIR`), 12 lines above `<details>`, the rest folded.
- `git rm SPEC.md HANDOFF.md`, commit. `docs/vibe-queue.md` already holds the rules.
- Merge `origin/main` first if #133 or the `job-review` job landed; both change `job_run` / `job_publish`.

## Blockers

None.

## Gotchas (unpromoted)

- PR #133 (runner gate) and the queued `job-review` job also change `job_run` / `job_publish`. If one is on `main`, merge `origin/main` first.
- 3 `tests/install.bats` tests (45, 51, 52) fail inside the job sandbox: `.claude/` placeholder files. In a `git clone` under `$TMPDIR` all 55 pass. Check from a clone: commit first, then `git fetch <worktree> HEAD` in the clone.
- `shfmt -f .` and `shellcheck` hit permission errors on the placeholder files: run them over `git ls-files`.
- `lane_leave` runs under `|| true`, so errexit is off inside it: each step guards itself with `|| return 0`.
