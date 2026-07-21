# Handoff — agentic-dev-toolkit / test-suite-tmux-isolation

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `test-suite-tmux-isolation`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/test-suite-tmux-isolation
- **Last updated:** 2026-07-21 16:06 UTC · server (srv1841294)

## State

Not started.

The bats suite leaks real tmux sessions and real agent processes when it runs
on the server. On 2026-07-21 a `vibe loop` stop check (`shfmt … && bats
tests/`) left 34 stray `vibe-proj-*` tmux sessions and three orphaned headless
`claude -p` processes behind. Those were killed by hand; the cause is unfixed.

Two distinct defects, both in the test harness — not in `vibe` itself:

1. **The suite takes the server path.** `detect_env()` (`bin/vibe:263`) returns
   `server` whenever `SSH_CONNECTION`/`SSH_TTY` is set or the hostname matches
   `VIBE_SERVER_HOSTNAME`. Under SSH, every `run_vibe start` / `vibe loop` in
   the suite creates a *real* tmux session against the live tmux server,
   outside `$BATS_TEST_TMPDIR`, so bats' cleanup cannot reclaim it.
2. **The stub agent does not survive the tmux hop.** `run_vibe()`
   (`tests/helper.bash:50`) exports `VIBE_AGENT_CMD`, but `tmux new-session`
   gives the new session the *tmux server's* environment, not the caller's. The
   in-tmux `vibe __loop-run` therefore re-resolves the agent to the default
   `claude` and launches the real thing — e.g. `tests/loop-brief.bats:190`,
   which stubs the agent and then calls `vibe loop`. Those agents outlive the
   test, running against `/tmp/bats-run-*` worktrees bats has already deleted.

The current mitigation is a per-invocation shell scrub (`env -u SSH_CONNECTION
-u SSH_TTY -u SSH_CLIENT -u VIBE_SERVER_HOSTNAME bats tests/`). That is a
habit, not a guard: any agent or CI job that runs `bats tests/` plainly
re-leaks. The fix belongs inside the suite so it cannot be forgotten.

Rejected: making `vibe` itself refuse tmux under test. That puts test-only
knowledge in production code, and the layout contract keeps `tests/`
responsible for its own isolation.

## Next action

In `tests/helper.bash`, force the local path for every test and make the real
tmux unreachable:

1. Neutralise environment detection suite-wide — unset `SSH_CONNECTION`,
   `SSH_TTY`, `SSH_CLIENT` and point `VIBE_SERVER_HOSTNAME` at a value that
   cannot match `hostname`. The suite has no `setup_file`/global hook today, so
   this needs a helper the `.bats` files already source (`helper.bash` is
   loaded by all of them).
2. Put a stub `tmux` early on `PATH` (under `$BATS_TEST_TMPDIR/bin`) that logs
   its argv and exits 0, so a test that *does* exercise the server path asserts
   against the log instead of the live tmux server. This is the belt to (1)'s
   braces — it is what stops a future server-path test leaking again.
3. Add a regression test: run a server-path command with the SSH vars
   deliberately set and assert no session was created on the real tmux server
   (i.e. the stub was hit).

Verify with the full gate from `CLAUDE.md`: `shfmt -f . | xargs shellcheck`,
`shfmt -d -i 2 -ci .`, `bats tests/`, `./install.sh doctor` — then re-run
`bats tests/` **without** the `env -u` scrub and confirm `tmux ls` is
unchanged. That last check is the real acceptance criterion.

## Blockers

None.

## Gotchas (unpromoted)

- **Branch overlap.** `tests/vibe-loop.bats` and `bin/vibe` are also edited,
  uncommitted, in the `ralphify-vibe-loop-per-the-project_status.md-roadmap-item`
  worktree, whose loop was killed mid-round on 2026-07-21 (its state reads
  `STATUS=stopped`). Expect a conflict there.
- **bash 3.2 + BSD/GNU userland.** Same constraints as the rest of the repo —
  no associative arrays, no `readlink -f`.
- The stub `tmux` must not shadow tmux for anything bats itself needs. If a
  global `PATH` prepend causes trouble, scope it to the `run_vibe`-style
  invocations.
