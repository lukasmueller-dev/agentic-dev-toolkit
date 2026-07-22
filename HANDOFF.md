# Handoff — agentic-dev-toolkit / review3-followups

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `review3-followups`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/review3-followups
- **Last updated:** 2026-07-22 16:45 UTC · server (srv1841294)

## State

Not started. Review round three (PR #41, merged) left two scriptability
gaps as owner decisions, recorded under "Open questions" in
`PROJECT_STATUS.md` — this task decides and implements them, then
replaces those two entries with the outcome.

1. **Foreground `vibe loop` exits 0 on every outcome.** `run_loop` in
   `bin/vibe` never returns non-zero, so a local
   `vibe loop … && next-step` cannot distinguish success from
   stalled/maxed/timeup. The state file (`.vibe-loop.state` STATUS) and
   ntfy already carry the outcome. Options: map non-success statuses to
   a non-zero exit in `cmd_loop`'s local (foreground) branch, or
   document the zero-exit contract in `docs/vibe-loop.md`. The exit
   code is only meaningful in the foreground path — on the server the
   loop is detached in tmux and the runner's exit status is invisible.
   If the mapping is implemented: several tests in
   `tests/vibe-loop.bats` assert `[ "$status" -eq 0 ]` for
   maxed/stalled/timeup runs and must be flipped deliberately, and
   `docs/vibe-loop.md` needs the contract stated either way.
2. **Server `vibe start` without a tty exits 1 after doing its work.**
   `open_session`'s server branch ends in `tmux_attach_or_switch`,
   which fails headless (no client/tty) after the session and agent
   are already up. Add `--no-attach` to `vibe start`, mirroring
   `vibe loop`'s flag: server-only refusal wording, and the
   "watch it: vibe attach <task>" hint on success. Touch points:
   `cmd_start`/`open_session` in `bin/vibe`, the header comment and
   `cmd_help` entry, both completions (`completions/vibe.bash`,
   `completions/_vibe`), and a bats test mirroring "loop: on the
   server a fresh loop starts detached" (assert against
   `$VIBE_TEST_TMUX_LOG`: session created, no
   `attach-session`/`switch-client`).

## Next action

Implement point 2 first — it is uncontroversial and self-contained
(one commit: flag, help, completions, test). Then point 1: read
`run_loop`'s tail and `cmd_loop`'s foreground branch, pick the
exit-code mapping (recommended: non-zero for stalled/maxed/timeup/
stopped in the foreground path only), implement it with the test flips
as their own deliberate commit, and record the decision in the commit
body plus a one-liner replacing the two Open-questions entries in
`PROJECT_STATUS.md`.

## Blockers

_What is stopping progress, and what would unblock it._

## Gotchas (unpromoted)

- Repo gate before committing: `shfmt -f . | xargs shellcheck`,
  `shfmt -d -i 2 -ci .`, `bats tests/`, `./install.sh doctor`; bash 3.2
  and BSD/GNU portability rules are in `CLAUDE.md`. CI is opt-in per
  PR: `gh pr edit <n> --add-label run-ci`.
- If point 1 lands as an exit-code change, it changes behavior for
  anything scripting `vibe loop` — say so in the PR description.
