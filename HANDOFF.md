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
- **Last updated:** 2026-11-19 · turing (milestone 6 done)

## State

Milestones 1–6 are done. `research_line` in `bin/vibe` builds the state line;
`research_progress` reads the run's `PROGRESS` lines (else `Step:`) for its steps and ETA.
`R_PILL` holds the state word, and `research_look` maps the word to the CSS state.
`research_card` gives a drained question Stop now while a run lives, and Archive once each job has settled.
Before the first worker job, `R_PROGRESS` is `0 of <workers=> workers`; `group_prog` passes it as it is.
tray-noise reads `tray-noise · 0 of 3 workers · drained` and `drained · stop now · on vast` at `$0.24 of $35`.

## Next action

Milestone 7: docs and tests (see `SPEC.md`).
Make `docs/vibe-queue.md` §Research card match the state line, the pill, the head and the buttons.
Add a `tests/page_check.py` case for each new branch.

Done when `docs/vibe-queue.md` §Research card matches and `page_check.py` covers each new branch.

## Blockers

None.

## Gotchas (unpromoted)

Open review finding: `research_why` takes its reason from the newest ended run of any job.
After `vibe queue stop <coordinator>`, an old worker's exit 124 reads `run at its limit`.
A `stopped` reason before the exit codes makes the smoke, limit, usd and deadline reasons unreachable: only a `stop` file reaches drained with no drain file. The human decides.

`failed: smoke`, `Step:` and `Average time:` are safety-critic's own log words.
They appear nowhere else in the toolkit. Keep them inside shortcuts; the `PROGRESS` contract is the real source.

No code reads `run/started` or `run/limit`: an ended run shows no box time. A review asks to delete the mirror; `SPEC.md` keeps it, so the human decides.

A job with a `stop` file (`vibe queue stop <id>`) needs no answer: `research_row` treats it as `stopped`.

The ETA shows only for a live run; an ended run keeps its steps from `run/log`.
