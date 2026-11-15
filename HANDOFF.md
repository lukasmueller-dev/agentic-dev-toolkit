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

Milestones 1 and 2 of `SPEC.md` are done. `workspaces/_places/turing` is the Docker place. `bin/vibe` has `ws build|start|stop|tick` and a hidden `ws hold`; the runner pass runs `ws_tick_bg`. `tests/vibe-ws.bats` has 19 tests.

## Next action

The next open milestone of `SPEC.md`: the queue hook — code — done when `bats tests/vibe-queue.bats -f tool` passes with a stub tool: a branch result ends as commits on the job's branch and a `pr.md`; a folder result ends as a report job; `vibe queue stop` calls `stop`, then `down`; `vibe queue steer` hands its text to `steer`; exit 3 from `steer` prints `not supported`.

## Blockers

None.

## Gotchas (unpromoted)

- Reuse `ws_dir` (conf check), `ws_secrets`, `ws_place` (env and place script) and `ws_up` in `bin/vibe` for the queue hook.
- `ws_place` sets `WS_HOURS` from the conf `hours` → a run needs the job's `hours=` there: add an override.
- `ws_name` finds the workspace of `<name>-<job id>` by the longest name that exists → write `place` into the state dir before the first `ws_place` call.
- The turing place mounts `$WS_STATE/in` at `/ws/in`, and runpod copies it → the hook fills `$WS_STATE/in` (`repo/`, `brief.md`, `args`) before `up`.
- `pull` copies `/ws/out` to `$WS_STATE/out` → the hook copies that to the job's `out/`.
- A `gpu=yes` run on turing needs the lock for the whole `run` → wrap the run in `gpu-queue lock`; `ws hold` keys on `id` and fits services only.
- Each place removes `id` in `down` (turing, runpod, vast) → `vibe` never removes `id` itself.
- `shfmt -f .` in a sandboxed job fails on `.claude/` placeholders (`permission denied`) → lint in a `git clone` under `$TMPDIR`.
