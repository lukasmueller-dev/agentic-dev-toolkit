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

The end action of `SPEC.md` (milestone 3) — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`. Move each spec decision and the open question below to `pr.md`, then `git rm SPEC.md HANDOFF.md` in one commit.

## Blockers

None.

## Gotchas (unpromoted)

- Open for the user (review 2, finding 4): at the limit, `down` pulls with no time bound before the delete. A bound trades the last data for money and frees the runner pass.
- Open in the contract: no member names the source of `$WS_STATE/in/`; `ws-surface` does not write it yet.
