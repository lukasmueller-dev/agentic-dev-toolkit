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
- **Last updated:** 2026-11-19 · turing

## State

Nothing is implemented. `SPEC.md` holds the design, confirmed in a grilling
session on 2026-11-19. Work its first open milestone.

The live example is the `tray-noise` question of safety-critic. Its card reads
`/bin/bash.00 of 5` and `waits for coordinator`, and names neither its run nor the
two vast boxes that ran.

## Next action

Milestone 1: spend counts the coordinator chain. `research_row` in `bin/vibe`
sums `cost` from worker job dirs only, so a coordinator's box money is never
read. Add the coordinator chain's `cost` files. For a box that is still up,
use `price × (now − started)` in place of the gate's full-hours reservation.

Done when `vibe queue status` prints a non-zero spend for tray-noise. Its two
coordinator jobs hold `cost=0.19` and `cost=0.05`.

## Blockers

None.

## Gotchas (unpromoted)

`failed: smoke`, `Step:` and `Average time:` are safety-critic's own log words.
They appear nowhere in the toolkit. Keep them inside the `Step:` fallback and
mark it a shortcut; the `PROGRESS` contract is the real source.
