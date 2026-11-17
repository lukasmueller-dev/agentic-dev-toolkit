# Handoff — agentic-dev-toolkit / research-run

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-run`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/research-run
- **Last updated:** 2026-11-17 · turing

## State

Milestone 1 of `SPEC.md` is done: `vibe queue gpu --place runpod|vast`, `run-result`, `infra`.
Member of the feature `parallel-research` with `research-card` (this repo) and `research-setup` (safety-critic).

## Next action

Milestone 2 of `SPEC.md`: place verb `price`, the `usd=` gate, the runner writes `cost` per worker.
Done when `bats tests/vibe-queue.bats tests/ws-place-runpod.bats tests/ws-place-vast.bats` pass with a gate test and a `price` test per place.

## Blockers

None.

## Gotchas (unpromoted)

- A place run: `vibe queue gpu --place` writes `<job>/run/` (place, commit, cmd); the runner's `place_pass` starts `place_run` in the background.
- `place_run` uses instance `research-<job id>`; its `dir` file points `ws_place` at the clone's `.claude/research/`. The tests use stub places `runpod` and `vast` (`places` in `tests/vibe-queue.bats`).
- `mkjob` in `tests/vibe-queue.bats` loops with a global `l`: a test variable `l` gets overwritten. Use another name.
- A place script runs a workspace folder, not a bare command: the command reaches the container as `/ws/in/cmd` (feature contract).
- `git branch research/<slug>/<hid>` fails when a branch `research` or `research/<slug>` exists → refuse that research branch name with one line.
- `research-card` reads the job keys and the job dir files of the contract; a change to one needs the user.
