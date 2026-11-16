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

Milestones 1 and 2 are done: `workspaces/_places/runpod`, `tests/ws-place-runpod.bats` (10 tests, all pass) and the recipe `docs/workspaces/place-runpod.md`. The recipe holds each gotcha.

## Next action

1. `c722f9d` holds the review-1 fixes for findings 1–3 (the session hit the spend limit before its commit). Add bats tests: create plus list failing leaves `id=pending` and `limit=0`; a killed `up` leaves `id=pending` for `tick`; a failed `down` sets `limit=0`; `pull` drops a symlink that points out of the tree.
2. The user's answer to finding 4: bound the pull on the `tick` path at 5 min, plus `rsync --timeout` for a dead link. `vibe ws stop` keeps the full pull. Add a test; update the recipe.
3. The end action of `SPEC.md` (milestone 3) — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`. Move each spec decision to `pr.md`, then `git rm SPEC.md HANDOFF.md` in one commit.

## Blockers

None. The `$WS_STATE/in/` source is `ws-surface`'s `tool_run` (`bin/vibe` on `origin/ws-surface`): it copies `in/brief.md`, `in/args` and clones the worktree into `in/repo`.
