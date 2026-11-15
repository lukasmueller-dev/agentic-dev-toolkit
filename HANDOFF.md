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

Nothing is built. `SPEC.md` holds the plan. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The first open milestone of `SPEC.md`: Reader and docs: `docs/workspaces.md` (the contract), `workspaces/README.md`, `vibe ws list` and `status` — code — done when `bats tests/vibe-ws.bats -f list` passes and `shfmt -f . | xargs shellcheck` prints nothing.

## Blockers

None.

## Gotchas (unpromoted)

None.
