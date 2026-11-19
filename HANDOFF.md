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
- **Last updated:** 2026-11-19 · turing (milestone 3 done)

## State

Milestones 1–3 are done. `research_line` in `bin/vibe` builds the state line;
`research_row` puts it in the last field of `R_HEAD`. tray-noise reads
`drained · stop now · on vast`; its pill still reads `done`.

## Next action

Milestone 4: split the pill label from the CSS state (see `SPEC.md` Decisions).
`R_PILL` still holds the old four values; the state word is the first field of the line.

Done when the pill reads the state word and a live run still renders `s-gpu`.

## Blockers

None.

## Gotchas (unpromoted)

`failed: smoke`, `Step:` and `Average time:` are safety-critic's own log words.
They appear nowhere else in the toolkit. Keep them inside shortcuts; the `PROGRESS` contract is the real source.

A run from before milestone 2 has no `run/started` or `run/limit`: the card shows no box time for it.

A job with a `stop` file (`vibe queue stop <id>`) needs no answer: `research_row` treats it as `stopped`.

