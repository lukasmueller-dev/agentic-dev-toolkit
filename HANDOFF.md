# Handoff — agentic-dev-toolkit / ws-hypothesisloop

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-hypothesisloop`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-hypothesisloop
- **Last updated:** 2026-11-15 · turing

## State

Nothing is built. `SPEC.md` holds the plan. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The first open milestone of `SPEC.md`: Conf and the three scripts against a stub `docker` — code — done when `bats tests/ws-hypothesisloop.bats` passes: `start` refuses an unset `CLOUD_COMPUTE_PROVIDERS` and each missing key by name; `start` and `stop` call compose on the file under `HLOOP_REPO`; `status` prints `up` or `down`.

## Blockers

None.

## Gotchas (unpromoted)

None.
