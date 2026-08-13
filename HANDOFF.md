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
- **Last updated:** 2026-08-13 17:05 CEST · local

## State

Root cause found and fixed, pushed as commit `c97235d` on top of two now-
superseded diagnostic commits (`78482eb`, `3162177` — their bodies record the
two rounds of macOS CI evidence that led here; not reverted, just
history — no need to read them to continue).

**Root cause:** the bug was in `tests/vibe-status-json.bats`, not in
`bin/vibe`. Git canonicalizes a worktree's path when it records it (`git
worktree list --porcelain` reports the physical path), and `status_json`'s
own `"path"` field already matches that correctly — `bin/vibe` was doing
exactly what its own comments say it should. Most tests build the worktree
path they expect to find in the JSON by concatenating `$BATS_TEST_TMPDIR`
directly. On Linux that's a no-op (`/tmp` isn't a symlink). On macOS,
`$TMPDIR` sits behind `/var -> /private/var`, so the literal path never
equals what git/status_json report, and `task_block`'s exact `"path"` match
silently finds nothing.

Why it read as scattered, unrelated field failures (kind, dirty, state, ...)
rather than one clean "path never matches": bash 3.2's `set -e` does not
reliably abort a bats test body at the first failing bare `[[ ]]` the way
bash 5.x does, so a chain of assertions runs to completion regardless, and
bats names whichever line was executing when the *last* command's exit
status went non-zero — not necessarily the first genuinely-failing one. A
couple of tests even reported a false "ok" because their last assertion
happened to be a negative check (`!= *pattern*`) that an empty `$block`
trivially satisfies. This is a real, separate finding worth a note in
`CLAUDE.md`'s shell section once confirmed (see Next action) — bare `[[ ]]`
assertion chains in a bats test are not reliably fail-fast on macOS's bash
3.2.

**Fix:** added a `phys` test helper (`cd + pwd -P`, mirroring `bin/vibe`'s
own "no readlink -f on macOS" resolution) and routed every worktree path a
test compares against `status_json`'s `"path"` field through it, resolved
*before* any step that might remove the directory. One test already did
this by hand for its main/unmanaged-kind comparison — it always passed,
which was the tell.

**Verified:** all 22 real tests plus the full local suite pass on Linux (446
pre-existing bats tests; 3 pre-existing unrelated failures in
`skill-lint.bats` from this sandbox's own shellcheck setup, nothing to do
with this change). The fix itself can only be confirmed on the macOS leg.

## Next action

1. Check PR #73's latest CI run (commit `c97235d`) for the macOS `bats` job
   result — confirm all `status --json` tests are green.
   `gh pr checks 73` or `gh run list --branch fix-status-json-macos`.
2. If green: squash/clean up the commit history if desired (three commits —
   two diagnostics plus the fix — are fine to keep as-is for the audit
   trail, or squash before merge, reviewer's call), then merge the PR.
3. Add a note to this repo's `CLAUDE.md` shell-portability section about the
   bash 3.2 `set -e`/bare-`[[ ]]`-chain masking behavior discovered here —
   it is a general trap for any bats test in this suite, not just this file,
   and the existing gotchas list is exactly where it belongs. Only add it
   once the CI run in step 1 confirms the theory (i.e., the fix alone was
   sufficient — if some assertion still needs reordering to be fail-fast,
   fold that into the same note).
4. Delete this `HANDOFF.md` from the branch before merging (`git rm
   HANDOFF.md`, `vibe sync`), per the standing rule.

## Blockers

None currently — root cause is understood and a fix is pushed. Only
remaining step is reading back the macOS CI result to confirm.

## Gotchas (unpromoted — candidate for CLAUDE.md, see Next action #3)

macOS's bash 3.2 does not reliably fail-fast on a bare `[[ ]]` assertion
chain inside a bats `@test` body the way later bash does under `set -e`.
Observed here: a test with four sequential bare `[[ "$block" == *pat* ]]`
lines had the *first three* silently fail (an empty `$block`, since none of
the patterns could possibly match) while only the *fourth* was reported by
bats as the failing line — meaning the first three ran to completion despite
failing, rather than aborting the test body immediately. Confirmed on Linux
that an empty `$block` reported at the *first* assertion under bash 5.x/bats
1.11, so this is not how the suite behaves elsewhere — it is specific to
whatever combination of bash 3.2 and the macOS runner's bats build is in
play. Net effect: a bats test on macOS can under-report which of several
assertions actually failed, and — worse — can report a false "ok" if the
*last* assertion in the chain happens to be a negative check. Confirmed via
an independent `grep -qF` re-check (bypassing bash's glob matching and
`task_block`'s awk entirely) that the underlying data was genuinely absent,
not a glob-matching quirk — so the masking is about `set -e` propagation,
not string matching. Worth generalizing into a rule (e.g., "wrap
multi-assertion bats checks in `run` + explicit exit-status checks, or use
`assert_*` helpers, rather than bare chained `[[ ]]`") once confirmed this
is really the mechanism and not merely correlated with the fix above.
