# Handoff — agentic-dev-toolkit / repo-review-fixes

- **Repo:** agentic-dev-toolkit
- **Branch:** `repo-review-fixes`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/repo-review-fixes
- **Last updated:** 2026-11-06 · job

## State

Milestones 1 (findings 1, 2), 2 (finding 3), 3 (finding 4) and 4 (finding 5) done. Full `bats tests/` passes in a clone (359 tests, 0 failures after commit `acd34ec`).
Milestone 4: `job_limit_pct` (`bin/vibe`) skips a job whose `ended` string is before the job's `started` string; one test in `tests/vibe-queue.bats`.

## Next action

Milestone 5 of `SPEC.md`: queue state (findings 6, 7) — `job_due` skips a recurring job with a queued or running copy; `job_end` keeps a status a follow-up already wrote; the runner starts a follow-up only after its parent has an `ended` file. Done when one bats test per rule passes.

Carry to the final `pr.md`:

- Finding 3: `agent_git` (`skills/_lib/lib.sh`) wraps every unsandboxed git call on an agent tree: `bin/vibe` runner calls (`open_worktree`, `job_start`, `job_gate`, `lane_leave`, `job_publish`, review, `triage_merge`), `sync_wt` (`vibe sync`, run by the shutdown skill), and `ensure_worktree` for the two cases that check out an existing branch.
- Finding 3, not wrapped: `gh`'s own git calls (before auth only `git remote`, `git config`; `pr create` after auth unchecked). Main-checkout reads and fetch. New-branch `worktree add` (content is the base).
- Finding 3: `git status` and `git add` run `post-index-change`, so read-only calls are wrapped too.
- Finding 3 risk: no repo hook runs on the runner's push or on `vibe sync`. A git-lfs repo cannot use the runner; a test in `pre-push` moves to `.vibe-jobs/gate` (`docs/vibe-queue.md`).
- Finding 3, review round 1: `cleanup.sh remove` classified every worktree per path (N×N `gh` calls); `scan_lines` now takes the path.
- Finding 3, review round 2: `cleanup.sh remove` resolves a relative path before the `cd`; the shutdown survey checks a `gone` branch with `cleanup.sh scan` and skips it only when rated `merged` or `ignored`.
- Finding 5: measured `vibe queue report` (18 queue jobs, 300 archived): 20.3 s before, 2.5 s after; 2.3 s with none archived (the rest is the 18 jobs that overlap each other).
- Finding 5: the window is the job's own start, not "last 5 h from now" (spec wording). A now-relative window drops the `≈N% 5h est.` of last night's jobs from the morning briefing.
- Finding 5 risk: strings compare, so one hour of a DST fall-back night can skip an overlapping job; the result is an estimate (`≈`).
- Finding 4: allow rules `git fetch:*` and `git ls-remote:*` stay; fetch now runs sandboxed. Deny rules for `--upload-pack` rejected (mid-command wildcards unverified).
- Finding 4 risk: a sandboxed fetch of a private repo can fail with `Authentication failed`; the trap list in `claude/CLAUDE.md` says to run it unsandboxed.
- Finding 4 risk: the `retired` list deletes the entry on every install, so a user who wants `git fetch *` excluded again must not rely on the settings file.

## Blockers

None.

## Gotchas (unpromoted)

- In the sandbox worktree, 3 `install.bats` tests fail on `.claude/` placeholders (known, `CLAUDE.md`); they pass in a clone under `$TMPDIR`.
- `shfmt -d .` fails on the sandbox's `.claude/` placeholders; name the tracked directories instead.
