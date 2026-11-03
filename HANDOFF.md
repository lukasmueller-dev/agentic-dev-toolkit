# Handoff — agentic-dev-toolkit / repo-review-fixes

- **Repo:** agentic-dev-toolkit
- **Branch:** `repo-review-fixes`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/repo-review-fixes
- **Last updated:** 2026-11-03 · check-in

## State

`SPEC.md` is written; no code changed yet.

## Next action

Milestone 1 of `SPEC.md`: `cleanup.sh` ignored-file allowlist and `[gone]` check (findings 1, 2). Done when new tests in `tests/worktree-cleanup.bats` show: a worktree with `runs/x.ckpt` is `ignored`, a `[gone]` branch without a merged PR is `unpushed`, a squash-merged branch is `merged`.

## Blockers

None.

## Gotchas (unpromoted)

- In the sandbox worktree, 3 `install.bats` tests fail on `.claude/` placeholders (known, `CLAUDE.md`); they pass in a clone under `$TMPDIR`.
