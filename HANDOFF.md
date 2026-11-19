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
- **Last updated:** 2026-11-19 · turing (milestone 2 done)

## State

Milestones 1 and 2 are done. Card spend sums the coordinator chain and live boxes
(`research_cost` in `bin/vibe`); tray-noise reads `$0.24 of $35`. After up,
`place_run` mirrors the instance's `started` and `limit` into `queue/<id>/run/`.

## Next action

Milestone 3: the state line, its precedence and the drained reason (see `SPEC.md`
Decisions). `research_row` in `bin/vibe` builds the line today.

Done when the tray-noise card line matches the order in `SPEC.md`.

## Blockers

None.

## Gotchas (unpromoted)

`failed: smoke`, `Step:` and `Average time:` are safety-critic's own log words.
They appear nowhere in the toolkit. Keep them inside the `Step:` fallback and
mark it a shortcut; the `PROGRESS` contract is the real source.

A run from before milestone 2 has no `run/started` or `run/limit`: the card must
show no box time for it, not fail.
