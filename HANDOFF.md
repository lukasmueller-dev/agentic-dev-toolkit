# Handoff — agentic-dev-toolkit / ws-autoresearchclaw

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-autoresearchclaw`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-autoresearchclaw
- **Last updated:** 2026-11-16 · turing

## State

Milestones 1 and 2 are done: the workspace, its 28 tests, and the recipe `docs/workspaces/autoresearchclaw.md`. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The end action of `SPEC.md` (`delete`), done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.
- Move each decision of `SPEC.md` into the PR body (`pr.md`).
- Then `git rm SPEC.md HANDOFF.md` and commit.

## Blockers

None.

## Gotchas (unpromoted)

None.
