# Handoff — agentic-dev-toolkit / fresh-review-4

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fresh-review-4`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fresh-review-4
- **Last updated:** 2026-07-22 22:05 UTC · server (srv1841294)

## State

**Round four is complete and the report is the PR body — read it there, not
here.** 24 findings across the surface that landed after round three.

Five are fixed on this branch, one commit each: the SOTA digest's cwd bug
(it had never once run, and exited 0 every week), the neutrality guard's
`\bmac\b` blind spot, the vacuous memory-guard bats mirror, a `CLAUDE.md`
list, and four new entries in the review-dimensions catalog.

Gate is clean: shellcheck, `shfmt -d`, 322 bats (was 321), skill-lint
`--strict` on both skill trees.

**Nothing else is fixed, by design** — the rest are high blast radius and
need the owner's decision. They are ranked in the PR body.

## Next action

Owner triage, in this order — these are the three that need a decision
before anyone writes code:

1. **The read-only reviewer hook is bypassable** (`claude/hooks/readonly-bash.sh`).
   `<(…)` and `awk … | getline` both execute; proven by writing files
   through the guard. Fix is to mark `<(`/`>(` in the awk pre-pass and deny
   `getline` from a pipe. Permission-guard change → needs go-ahead.
2. **Everything `repo-scaffold` emits hardcodes `main`** — the pre-push hook
   (proven no-op on a `trunk` repo) and all five `templates/ci/*.yml`. These
   land in other people's repos, so the fix shape is a decision: substitute
   the detected default branch at scaffold time, or make the hook read it
   from git.
3. **`sota-weekly.sh` hardcodes `--no-attach`**, so the whole watch is
   server-only and dies instantly anywhere else, contradicting both its own
   comment and `docs/sota-watch.md:42`. Decide whether local runs are
   supposed to work; if not, the doc and the comment are what change.

Then work down tiers 2 and 3 in the PR body. Several are cheap and
independent (the `run-ci` label, `disable-model-invocation` on
`sota-digest`, `test -f` coverage for the scaffold's ten template paths).

## Blockers

None. The PR carries `run-ci` — CI is opt-in here, and an unlabelled PR
shows no checks while GitHub's merge box reads a skipped job as passing.
The macOS leg is the only place bash 3.2 and BSD userland are exercised,
and finding 4 touched a grep pattern, so that leg matters this time.

## Gotchas (unpromoted)

None. The durable lessons from this round are already promoted: the four
new review dimensions are in
`skills/review-brief/references/review-dimensions.md`, and each fix carries
its failure scenario in its own commit body.

**Delete this file before `vibe done`** — the round's remaining work lives
in the PR, not in a baton.
