# Handoff — agentic-dev-toolkit / fix-status-json-macos

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fix-status-json-macos`
- **PR:** #73 (`gh pr view 73`) — carries the `run-ci` label already
- **Worktree:** /home/mueller/git/worktrees/agentic-dev-toolkit/fix-status-json-macos
- **Last updated:** 2026-08-13 17:15 CEST · local

## State

Fix is pushed (`c97235d`, plus a handoff-only commit `d31c79f` on top) and
**CI is currently running** on GitHub for the latest commit — not yet
confirmed. `gh run list --branch fix-status-json-macos` shows the run for
`d31c79f` `in_progress`/`pending` as of this update.

**Root cause (confirmed, fixed):** the bug was in
`tests/vibe-status-json.bats`, not in `bin/vibe`. Git canonicalizes a
worktree's path when it records it, and `status_json`'s own `"path"` field
already matches that correctly. Most tests built the worktree path they
expect to find in the JSON by concatenating `$BATS_TEST_TMPDIR` directly —
a no-op on Linux, but wrong on macOS where `$TMPDIR` sits behind
`/var -> /private/var`, so the literal path never equalled what
git/status_json report and the exact `"path"` match silently found nothing.

**Fix:** added a `phys` test helper (`cd + pwd -P`) and routed every
worktree path a test compares against `status_json`'s `"path"` field
through it, resolved before any step that might remove the directory.
Verified locally on Linux: all 22 real tests plus the full suite pass (446
pre-existing bats tests; 3 pre-existing unrelated `skill-lint.bats`
failures from this sandbox's shellcheck setup — unrelated to this change).
The fix itself can only be confirmed on the macOS CI leg.

## Next action

1. Poll CI to completion and check the macOS `bats` job specifically:
   `gh pr checks 73` or `gh run list --branch fix-status-json-macos`.
2. If macOS is green: confirms the bash-3.2 `set -e` masking theory below.
   Add a note to this repo's `CLAUDE.md` shell-portability gotchas section
   about bare `[[ ]]` assertion chains in bats tests not being reliably
   fail-fast under macOS's bash 3.2 (see "Gotchas" below for the write-up
   to adapt). Then squash/clean up history if desired (reviewer's call) and
   merge the PR.
3. If macOS is still red: re-fetch the failure log
   (`gh run view <id> --log-failed`) — the path-resolution fix may not be
   the whole story, or a different assertion needs reordering to be
   fail-fast. Don't assume the theory is confirmed until the log says so.
4. Delete this `HANDOFF.md` from the branch before merging (`git rm
   HANDOFF.md`, `vibe sync`), per the standing rule.

## Blockers

None — waiting on CI only. Re-run step 1 above; do not guess the result.

## Gotchas (unpromoted — candidate for CLAUDE.md, pending CI confirmation)

macOS's bash 3.2 did not reliably fail-fast on a bare `[[ ]]` assertion
chain inside a bats `@test` body the way bash 5.x does under `set -e`: a
test with four sequential bare `[[ "$block" == *pat* ]]` lines had the
first three silently fail (empty `$block`) while only the fourth was
reported by bats as the failing line, meaning the first three ran to
completion despite failing rather than aborting immediately. Confirmed on
Linux that an empty `$block` is reported at the *first* assertion under
bash 5.x/bats 1.11, so this is specific to bash 3.2 + the macOS runner's
bats build. Net effect: a bats test on macOS can under-report which
assertion actually failed, and can report a false "ok" if the *last*
assertion in a chain happens to be a negative check that an empty value
trivially satisfies. Independently confirmed via `grep -qF` (bypassing
bash glob matching and `task_block`'s awk) that the underlying data was
genuinely absent — so this is about `set -e` propagation, not string
matching. Do not promote to CLAUDE.md until the macOS CI run in step 1
confirms the fix alone was sufficient (i.e., no assertion also needed
reordering to be fail-fast).
