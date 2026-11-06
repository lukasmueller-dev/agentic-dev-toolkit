# Handoff — agentic-dev-toolkit / repo-review-fixes

- **Repo:** agentic-dev-toolkit
- **Branch:** `repo-review-fixes`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/repo-review-fixes
- **Last updated:** 2026-11-06 · job

## State

Milestones 1 (findings 1, 2) and 2 (finding 3) done. Full `bats tests/` passes in a clone (see the last run in the commit log).
Milestone 2: `agent_git` wraps every unsandboxed git call on an agent tree; 5 hook tests (`job_publish`, `lane_leave`, `triage_merge`, resumed branch, `vibe sync`).

## Next action

Milestone 3 of `SPEC.md`: fetch rules and installer `retired` list (finding 4). Done when an `install.bats` test shows `git fetch *` gone from a user settings file that held it.

Carry to the final `pr.md` (finding 3):

- `agent_git` (`skills/_lib/lib.sh`) wraps every unsandboxed git call on an agent tree: `bin/vibe` runner calls (`open_worktree`, `job_start`, `job_gate`, `lane_leave`, `job_publish`, review, `triage_merge`), `sync_wt` (`vibe sync`, run by the shutdown skill), and `ensure_worktree` for the two cases that check out an existing branch.
- Not wrapped: `gh`'s own git calls (before auth only `git remote`, `git config`; `pr create` after auth unchecked). Main-checkout reads and fetch. New-branch `worktree add` (content is the base).
- `git status` and `git add` run `post-index-change`, so read-only calls are wrapped too.
- Risk: no repo hook runs on the runner's push or on `vibe sync`. A git-lfs repo cannot use the runner; a test in `pre-push` moves to `.vibe-jobs/gate` (`docs/vibe-queue.md`).
- Review round 1: `cleanup.sh remove` classified every worktree per path (N×N `gh` calls); `scan_lines` now takes the path.
- Review round 2: `cleanup.sh remove` resolves a relative path before the `cd`; the shutdown survey checks a `gone` branch with `cleanup.sh scan` and skips it only when rated `merged` or `ignored`.

## Blockers

None.

## Gotchas (unpromoted)

- In the sandbox worktree, 3 `install.bats` tests fail on `.claude/` placeholders (known, `CLAUDE.md`); they pass in a clone under `$TMPDIR`.
- `shfmt -d .` fails on the sandbox's `.claude/` placeholders; name the tracked directories instead.
