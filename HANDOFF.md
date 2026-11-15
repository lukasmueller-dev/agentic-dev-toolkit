# Handoff — agentic-dev-toolkit / ws-autoresearch

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-autoresearch`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-autoresearch
- **Last updated:** 2026-11-15 · turing

## State

Nothing is built. `SPEC.md` holds the plan. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The first open milestone of `SPEC.md`: Conf, Dockerfile and the three scripts against a stub supervisor — code — done when `bats tests/ws-autoresearch.bats` passes: `run` hands over the idea and the project root, copies the six result paths, and writes `failed:` when the supervisor exits non-zero; `grep -rc run_pending_forge workspaces/autoresearch` prints only zeros.

## Blockers

None.

## Gotchas (unpromoted)

None.
