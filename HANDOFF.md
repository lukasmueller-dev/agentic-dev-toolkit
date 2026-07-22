# Handoff — agentic-dev-toolkit / fix-vibe-done-bug

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fix-vibe-done-bug`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fix-vibe-done-bug
- **Last updated:** 2026-07-22 19:44 UTC · server (srv1841294)

## State

Not started. The bug is diagnosed and reproduced; no code has been changed.

`vibe done` kills the task's tmux session *before* it removes the worktree, so
running it from inside that task's own session kills `vibe` itself mid-command
and the removal never runs.

In `bin/vibe`, `done_one` does the kill at ~line 2012
(`tmux kill-session -t "$sess"`) and the removal at ~line 2028 (`cd "$main"`,
then `git worktree remove`). On the server, `vibe start` puts you *inside*
the task's own `vibe-`-prefixed session, so `$sess` (built by
`tmux_session_name`) names the session hosting the running `vibe`
process. It gets SIGHUP'd and dies before reaching the removal.

Reproduced in a throwaway repo: a real tmux session named `vibe-myrepo-mytask`
with cwd in the worktree, running `vibe done --force` with stdout+stderr
redirected to a file. Result: session gone, **log file empty** (vibe died
before printing anything), worktree directory still present and still in
`git worktree list` — hence still listed by `vibe status`.

The same ordering also swallows the *refusal* messages: the dirty-tree /
unpushed / `HANDOFF.md` / `LOOP.md` guards all `die` after the kill, so a
`vibe done` that correctly refuses inside its own session leaves the user with
no message at all.

Not affected: `vibe done <task>` run from the main checkout or any other
session — the removal succeeds there (verified). Cwd-based inference itself is
fine; `done_one` already `cd`s to the main repo before removing. The shell
being left in a deleted directory afterwards is expected and separate.

Rejected: doing nothing and documenting it — the failure is silent, which is
exactly the class of bug this repo's guards exist to prevent.

## Next action

In `bin/vibe`, reorder `done_one` so the worktree removal happens **before**
the tmux kill, and move the kill to the end of the function. Additionally,
when the session about to be killed is our own — `$TMUX` is set and
`tmux display-message -p '#{session_name}'` equals `$sess` — print the
"removed worktree" result *before* issuing the kill, so the outcome is not
lost with the pane.

Then add a bats test in `tests/` asserting the worktree is removed even when
`vibe done` runs inside the doomed session. The suite's stub `tmux`
(`tests/helper.bash`) means the test asserts against `$VIBE_TEST_TMUX_LOG`,
never a live tmux server — so the test must verify **ordering** in the log
(removal before kill) rather than relying on a real SIGHUP.

## Blockers

None.

## Gotchas (unpromoted)

- The guard paths (`die` on dirty tree / unpushed commits / `HANDOFF.md` /
  `LOOP.md`) must keep firing *before* anything destructive — reordering must
  not move the kill or the removal above them.
- `vibe done` in multi-task mode runs each `done_one` in a subshell as the
  tested condition of an `if`, which switches errexit off for the whole
  subshell. The existing explicit `|| die` on `git worktree remove` is what
  keeps that real — preserve it when reordering (see `CLAUDE.md`).
- Detecting "our own session" needs the `$TMUX`-unset case to be a clean
  no-op, since `vibe done` is also run outside tmux entirely.
