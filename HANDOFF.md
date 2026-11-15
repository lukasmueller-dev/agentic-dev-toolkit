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

Milestones 1 and 2 are done: `workspaces/hypothesisloop/`, `tests/ws-hypothesisloop.bats` (13 tests, green) and the recipe `docs/workspaces/hypothesisloop.md`. Reasons: the commit bodies.

## Next action

The end action of `SPEC.md`: delete `SPEC.md` and `HANDOFF.md`, and move each spec decision to `pr.md` — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## Blockers

None.

## Gotchas (unpromoted)

- The recipe's first objective does not run from `vibe ws start` alone: no sandbox section and no cluster (recipe step 5). The PR body must name it.
