# Handoff — agentic-dev-toolkit / ws-place-runpod

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-place-runpod`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-place-runpod
- **Last updated:** 2026-11-15 · turing

## State

Nothing is built. `SPEC.md` holds the plan. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The first open milestone of `SPEC.md`: The place script against stub `runpodctl`, `ssh` and `rsync` — code — done when `bats tests/ws-place-runpod.bats` passes: a failed `up` deletes the pod; `down` deletes after a failed `pull`; `tick` past `limit` deletes; `tick` pulls when `pulled` is 10 min old or more; no secret value is in any stub's argv.

## Blockers

None.

## Gotchas (unpromoted)

None.
