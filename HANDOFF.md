# Handoff — agentic-dev-toolkit / fix-bats-macos

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fix-bats-macos`
- **Worktree:** /Users/lukasmueller/git/worktrees/agentic-dev-toolkit/fix-bats-macos
- **Last updated:** 2026-09-04 18:51 CEST · local (lukas-mbp)

## State

- Not started. 10 tests in `tests/vibe-status-json.bats` fail on macOS, locally and on CI's macOS leg on main since PR #70. Ubuntu green.
- Cause 1: `task_block` matches a task object by exact path. Tests build `wt` from `$BATS_TEST_TMPDIR` (`/var/folders/...`); `vibe status --json` prints physical paths (`/private/var/...`). No match → empty block → every assertion on it fails.
- Cause 2: bash 3.2 applies neither errexit nor the ERR trap to a failing `[[ ]]`. Bats on macOS runs under `/bin/bash` 3.2, so a `[[` assertion is a no-op unless it is the test's last statement. The 10 failures are exactly the tests whose last line is a positive `==` match on the empty block. ~320 `[[` assertions across `tests/` are affected; `[ ]` assertions are fine.
- Repro: `/bin/bash -c 'set -e; f(){ [[ 1 == 2 ]]; echo continued; }; f'` prints `continued`.
- Precedent: `tests/sota-weekly.bats` resolves paths with `pwd -P` for this reason.

## Next action

1. `git merge origin/main` first: this branch was cut from e4a4c52 (#70); #71 and #72 are on origin/main and touch the same test file.
2. In `tests/vibe-status-json.bats`, resolve `wt` physically before `task_block` (or inside it). Run `bats tests/vibe-status-json.bats` → 0 failures.
3. Pick and apply the suite-wide fix: run CI's macOS bats under Homebrew bash in `.github/workflows/ci.yml`, or convert `[[` assertions to `[ ]` / `grep -q`. Add a guard test: a failing `[[` mid-test must fail the test.
4. Add a one-line trap (symptom + fix) to the Testing section of the repo `CLAUDE.md`.
5. Label the PR `run-ci`; the macOS leg is the proof.

## Blockers

none

## Gotchas (unpromoted)

- Run bats outside any sandbox: the suite's `mktemp` writes to the system temp dir.
- CI on main is red on the macOS leg only, for #70, #71, #72.
