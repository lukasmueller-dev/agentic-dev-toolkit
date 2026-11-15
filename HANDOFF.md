# Handoff — agentic-dev-toolkit / ws-deepscientist

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-deepscientist`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-deepscientist
- **Last updated:** 2026-11-15 · turing

## State

Nothing is built. `SPEC.md` holds the plan. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The first open milestone of `SPEC.md`: Conf, Dockerfile and the three scripts against a stub `ds` and a stub health endpoint — code — done when `bats tests/ws-deepscientist.bats` passes: the `start` argv holds `--auth true` and `--host 0.0.0.0`; `status` prints `up` on a healthy answer and `down` on none; the token is in `status` output and in no file under `/ws/out`.

## Blockers

None.

## Gotchas (unpromoted)

None.
