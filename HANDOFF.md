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
- **Last updated:** 2026-11-19 · turing (milestone 5 done)

## State

Milestones 1–5 are done. `research_line` in `bin/vibe` builds the state line;
`research_progress` reads the run's `PROGRESS` lines (else `Step:`) for its steps and ETA.
`R_PILL` holds the state word, and `research_look` maps the word to the CSS state.
tray-noise reads `drained · stop now · on vast` at `$0.24 of $35`.

## Next action

Milestone 6: the head budget and the drained buttons (see `SPEC.md` Decisions).
The head reads `0 of 3 workers` from `workers=` until the first worker job exists.
A drained question loses Stop question, keeps Stop now while a run lives, and gains Archive.

Done when a drained question shows Archive and no Stop question.

## Blockers

None.

## Gotchas (unpromoted)

`failed: smoke`, `Step:` and `Average time:` are safety-critic's own log words.
They appear nowhere else in the toolkit. Keep them inside shortcuts; the `PROGRESS` contract is the real source.

A run from before milestone 2 has no `run/started` or `run/limit`: the card shows no box time for it.

A job with a `stop` file (`vibe queue stop <id>`) needs no answer: `research_row` treats it as `stopped`.

The ETA shows only for a live run; an ended run keeps its steps from `run/log`.
