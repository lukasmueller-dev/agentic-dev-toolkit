# Handoff — agentic-dev-toolkit / research-card-status

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-card-status`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/research-card-status
- **Last updated:** 2026-11-19 · turing (milestone 1 done)

## State

Milestone 1 is done: the card spend sums the coordinator chain, and a box that is up
counts `price × (now − started)` (`research_cost` in `bin/vibe`). tray-noise reads
`$0.24 of $35`. Work the next open milestone of `SPEC.md`.

## Next action

Milestone 2: `place_run` mirrors `started` and `limit` into `queue/<id>/run/` at
start, beside the `price` mirror. The instance dir goes when the box goes.

Done when a new run's `queue/<id>/run/started` holds an epoch.

## Blockers

None.

## Gotchas (unpromoted)

`failed: smoke`, `Step:` and `Average time:` are safety-critic's own log words.
They appear nowhere in the toolkit. Keep them inside the `Step:` fallback and
mark it a shortcut; the `PROGRESS` contract is the real source.
