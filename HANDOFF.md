# Handoff — agentic-dev-toolkit / ws-surface

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-surface`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-surface
- **Last updated:** 2026-11-15 · turing

## State

Milestone 1 of `SPEC.md` is done: `docs/workspaces.md` (the contract), `workspaces/README.md`, `vibe ws list|status` in `bin/vibe`, `tests/vibe-ws.bats`.

## Next action

The next open milestone of `SPEC.md`: the `turing` place, `vibe ws build|start|stop`, `tick` in the runner pass — code — done when `bats tests/vibe-ws.bats` passes with stub `docker` and `gpu-queue`: start refuses a missing secret and an env file that others can read; a `gpu=yes` service holds the lock until stop; `tick` removes a container past its limit; a failed `up` leaves no container.

## Blockers

None.

## Gotchas (unpromoted)

- `vibe ws status` reads an `id` file as up → `stop` and `tick` remove `id` after `down`, else status keeps `up` or `past limit`.
- `ws_state` has no state for a start that waits on the GPU lock → add one (a state file `vibe ws start` writes) with `waits for the GPU`.
- `ws_check` in `bin/vibe` is the conf reader → reuse it in `start` and the queue hook; it accepts no unknown key.
- `shfmt -f .` in a sandboxed job fails on `.claude/` placeholders (`permission denied`) → lint in a `git clone` under `$TMPDIR`.
