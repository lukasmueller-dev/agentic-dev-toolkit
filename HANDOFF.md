# Handoff — agentic-dev-toolkit / repo-review-fixes

- **Repo:** agentic-dev-toolkit
- **Branch:** `repo-review-fixes`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/repo-review-fixes
- **Last updated:** 2026-11-06 · job

## State

Milestones 1 (findings 1, 2) and 2 (finding 3) done. Full `bats tests/` passes in a clone (353 tests).
Milestone 2: `agent_git` in `bin/vibe` wraps every runner git call on an agent tree; 3 new tests (`job_publish`, `lane_leave`, `triage_merge`).

## Next action

Milestone 3 of `SPEC.md`: fetch rules and installer `retired` list (finding 4). Done when an `install.bats` test shows `git fetch *` gone from a user settings file that held it.

Carry to the final `pr.md` (finding 3):

- Wrapped calls, all in `bin/vibe`: `open_worktree` status + `merge --ff-only`; `job_start` status, `rev-parse`; `job_gate` fetch + show; `lane_leave` status, add, commit, `branch -f`, `reset --hard`, `push --force`; `job_publish` `rev-list` + `push -u`; `review_due` `rev-list`; `review_big` diff; review `rev-parse`; `triage_merge` `worktree add`, merge, push, diff, `merge --abort`, `worktree remove`.
- Not wrapped: `ensure_worktree` in `skills/_lib/lib.sh` (`worktree add` runs `post-checkout` when a job resumes a branch whose worktree is gone; shared with `vibe start` and skills). `gh`'s own git calls (before auth only `git remote`, `git config`; `pr create` after auth unchecked). `vibe sync` (user command). Main-checkout reads and fetch.
- `git status` and `git add` run `post-index-change`, so read-only calls are wrapped too.
- Risk: no repo hook runs on the runner's push. A git-lfs repo cannot use it; a test in `pre-push` moves to `.vibe-jobs/gate` (`docs/vibe-queue.md`).

## Blockers

None.

## Gotchas (unpromoted)

- In the sandbox worktree, 3 `install.bats` tests fail on `.claude/` placeholders (known, `CLAUDE.md`); they pass in a clone under `$TMPDIR`.
- `shfmt -d .` fails on the sandbox's `.claude/` placeholders; name the tracked directories instead.
