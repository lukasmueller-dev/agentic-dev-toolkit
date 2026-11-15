# Handoff — agentic-dev-toolkit / ws-place-vast

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-place-vast`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-place-vast
- **Last updated:** 2026-11-15 · turing

## State

Milestones 1 and 2 are done: `workspaces/_places/vast`, `tests/ws-place-vast.bats` (7 tests) and the recipe `docs/workspaces/place-vast.md`. The gotchas of the last handoff are now requirements and traps in the recipe.

## Next action

The end action of `SPEC.md`: move each decision of `SPEC.md` to the PR body, then `git rm SPEC.md HANDOFF.md`. Done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## Blockers

None.

## For the PR body

- `/ws/in` comes from `$WS_STATE/in`, in the vast and the turing place alike. The contract names no source, so `ws-surface` must fill it for a queue job.
- No real Vast instance has run the script. The `vastai` facts come from the 1.11.0 source.
