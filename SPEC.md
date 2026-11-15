# Spec — agentic-dev-toolkit / ws-surface

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-surface`
- **Written:** 2026-11-15

## Goal

`vibe ws` reads `workspaces/`, launches a tool on turing in Docker, and the queue runs a `kind=run` tool as a job with stop, steer and a checked result.
Feature: ~/.local/state/vibe/features/workspaces.md

## Non-goals

- See the feature file.
- No folder of another member: only `workspaces/README.md`, `workspaces/_places/turing` and a stub tool under `tests/`.

## Decisions

- See the feature file.
- `VIBE_WORKSPACES` overrides the folder: tests need a temp one.
- `vibe ws start` on turing with `gpu=yes` starts under `gpu-queue lock`, detached, and prints `waits for the GPU` or `up`.
- A `tool=` job reuses the job pipeline (worktree, timeout, stop, review, gate, PR). The tool's `run` takes the place of the agent; then the agent session closes the run, with `skills/fill-queue/references/tool-run.md` at the prompt's end.
- `hours=` limits the tool; `timeout=` limits the closing session.
- `result=folder` makes a report job; the files stay in the job dir.
- The page list reads state files only: no `docker exec` per runner pass.
- Steer for plain jobs sits behind `steer=1` in `queue.conf`, default off: it changes how each job starts (`--input-format stream-json` on a FIFO).

## Milestones

- [x] Reader and docs: `docs/workspaces.md` (the contract), `workspaces/README.md`, `vibe ws list` and `status` — code — done when `bats tests/vibe-ws.bats -f list` passes and `shfmt -f . | xargs shellcheck` prints nothing.
- [ ] The `turing` place, `vibe ws build|start|stop`, `tick` in the runner pass — code — done when `bats tests/vibe-ws.bats` passes with stub `docker` and `gpu-queue`: start refuses a missing secret and an env file that others can read; a `gpu=yes` service holds the lock until stop; `tick` removes a container past its limit; a failed `up` leaves no container.
- [ ] The queue hook — code — done when `bats tests/vibe-queue.bats -f tool` passes with a stub tool: a branch result ends as commits on the job's branch and a `pr.md`; a folder result ends as a report job; `vibe queue stop` calls `stop`, then `down`; `vibe queue steer` hands its text to `steer`; exit 3 from `steer` prints `not supported`.
- [ ] The "tool run" route of `/enqueue`, the page list, the docs, the layout row in `CLAUDE.md`, the completion — code — done when `./bin/skill-lint --strict skills` and `bats tests/vibe-web.bats tests/vibe-queue.bats` pass and `grep -c 'workspaces/' CLAUDE.md` prints 1 or more.
- [ ] Steer for plain jobs — code — done when `bats tests/vibe-queue.bats -f steer` passes: with `steer=` unset the agent's argv is unchanged; with `steer=1` the stub agent receives the text of `vibe queue steer`.
- [ ] End action: one line in `PROJECT_STATUS.md`, decisions into `pr.md` — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md` and `grep -c workspaces PROJECT_STATUS.md` prints 1 or more.

## End action

`delete`. Each decision moves to the PR body.
