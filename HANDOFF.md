# Handoff — agentic-dev-toolkit / repo-review-fixes

- **Repo:** agentic-dev-toolkit
- **Branch:** `repo-review-fixes`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/repo-review-fixes
- **Last updated:** 2026-11-06 · job

## State

Milestone 1 done (findings 1, 2): `cleanup.sh` has the `ignored` state and the `gh` check for `[gone]` branches; full `bats tests/` passes in a clone (349 tests).

## Next action

Milestone 2 of `SPEC.md`: runner hooks wrapper (finding 3). Done when a bats test with a relative `pre-push` hook that writes a marker finds no marker after `job_publish` and `triage_merge`. The PR body lists each unsandboxed git call the runner makes on an agent tree.

## Blockers

None.

## Gotchas (unpromoted)

- In the sandbox worktree, 3 `install.bats` tests fail on `.claude/` placeholders (known, `CLAUDE.md`); they pass in a clone under `$TMPDIR`.
