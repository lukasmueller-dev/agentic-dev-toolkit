# Handoff — agentic-dev-toolkit / vibe-refactor

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and clear this file back to its headings: a finished task hands
> nothing off.

- **Repo:** agentic-dev-toolkit
- **Branch:** `vibe-refactor`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/vibe-refactor
- **Last updated:** 2026-07-21 · server (srv1841294)

## State

Not started. A review of `bin/vibe` (1681 lines) concluded the script is
structurally sound — small functions, why-comments, guarded destructive
paths — but carries real duplication. Six behavior-preserving cleanups were
agreed, in priority order:

1. Unify the ahead/behind/diverged upstream comparison, written four times:
   `loop_push` (bin/vibe:510), `attach_ff` (bin/vibe:919), `sync_dir`
   (bin/vibe:1301), `ff_worktree` (bin/vibe:1331). Extract a helper, e.g.
   `upstream_state DIR` printing `insync|ahead|behind|diverged|no-upstream`.
   Unify only the state *computation* — each caller keeps its own policy
   (attach never refuses, sync dies, loop stops, resume can rebase). Note
   `loop_push` treats a failed fetch as non-fatal while `sync_dir` and
   `ff_worktree` let it die — preserve that difference.
2. `loop_write_state` takes 11 positional args (bin/vibe:482). Change to
   `KEY VALUE` pairs, same pattern `render_template` (bin/vibe:180) uses.
3. `cmd_attach` (bin/vibe:968) and `cmd_rc` (bin/vibe:1406) re-derive
   repo/branch/dir by hand instead of calling `resolve_by_task`
   (bin/vibe:285). `cmd_rc` currently skips the is-it-really-a-worktree
   verification; using the resolver fixes that.
4. The tmux create/send-keys/attach-or-switch block is duplicated in
   `cmd_loop` (bin/vibe:778) and `open_session` (bin/vibe:884). Extract one
   helper covering both, including the `--no-attach` and switch-vs-attach
   variants.
5. The handoff scaffolding-only regex is written twice: inside
   `handoff_carries_content` (bin/vibe:850) and literally again in
   `cmd_done` (bin/vibe:1215). Hoist into one shared variable.
6. Split `cmd_loop` (~150 lines, bin/vibe:657) into flag parsing,
   effective-settings resolution (the resume-vs-fresh block), and dispatch.

Rejected alternatives: no rewrite in another language (bash 3.2 +
symlink-install constraints are the point), and no split into sourced
`lib/*.sh` files yet — single file stays until it outgrows ~2k lines.

## Next action

Run the bats suite to record a green baseline, then do item 1 alone: add
`upstream_state`, convert `ff_worktree` first (it has the most direct test
coverage via `vibe resume`), then the other three call sites, one commit per
converted caller. Items 2–6 follow as separate commits in the listed order.

## Blockers

_What is stopping progress, and what would unblock it._

## Gotchas (unpromoted)

- On the VPS, run bats with
  `env -u SSH_CONNECTION -u SSH_TTY -u VIBE_SERVER_HOSTNAME bats tests/` —
  otherwise ~30 tests fail from server-detection leaking in.
- Every change must survive `shfmt -f . | xargs shellcheck`,
  `shfmt -d -i 2 -ci .`, bash 3.2, and BSD userland (repo CLAUDE.md "Shell"
  section).
- `ensure_worktree` is kept in lockstep with `skills/loop-brief/brief.sh` —
  if refactoring drifts near it, mirror the change.
- Direct push to main is blocked by `.githooks/pre-push`; work lands via PR.
- A stale `HANDOFF.md` (metadata from `fix-skill-lint-sigpipe-race`) is
  committed on main at the repo root — it leaked via a PR, same failure mode
  as the LOOP.md removed in 569b4b0. Remove it from main in a separate PR so
  it stops seeding every new branch.
