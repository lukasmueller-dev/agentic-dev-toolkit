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

Milestones 1 and 2 are done: `workspaces/autoresearch/`, `tests/ws-autoresearch.bats` and the recipe `docs/workspaces/autoresearch.md` (6 `## ` headings). The image is unbuilt and no real run happened. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The last milestone of `SPEC.md`: the end action `delete` — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

- Move each decision of `SPEC.md` to `pr.md`.
- Delete `SPEC.md` and `HANDOFF.md` (`git rm`, commit).
- The recipe links `docs/workspaces.md`: it exists on `ws-surface` only, so the link is dead until that PR merges.
- The places write `limit` before the image pull and the ssh wait, and the container gets no limit epoch. `run` leaves a 30 min margin (`AR_LIMIT_MARGIN`). A limit epoch in the container is a contract change: it needs the user.
- The recipe names no queue command: `ws-surface` ships `vibe ws list` and `status` only. Add the command when it lands.

## Blockers

None.

## Gotchas (unpromoted)

None.
