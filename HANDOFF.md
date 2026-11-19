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
- **Last updated:** 2026-11-19 · turing (milestone 7 done)

## State

Milestones 1–7 are done. `docs/vibe-queue.md` §Research card names the state line, steps, ETA, reasons and buttons.
`tests/page_check.py` checks a live card (`lv`) and a drained card (`dq`): pill, look, live spend, buttons, the line wrap on a phone.
tray-noise reads `$0.24 of $35` and `drained · stop now · on vast` in `vibe queue status`.

## Next action

End action of `SPEC.md`: `delete`. Move each decision of `SPEC.md` to `pr.md`, then `git rm SPEC.md HANDOFF.md`.
Put the open human decision below (the run/ mirror) into the PR body first.

## Blockers

None.

## Gotchas (unpromoted)

Review 2 asks again to delete the `run/started` and `run/limit` mirror; SPEC.md keeps it. The human decides.

`failed: smoke`, `Step:` and `Average time:` are safety-critic's own log words.
They appear nowhere else in the toolkit. Keep them inside shortcuts; the `PROGRESS` contract is the real source.

No code reads `run/started` or `run/limit`: an ended run shows no box time. A review asks to delete the mirror; `SPEC.md` keeps it, so the human decides.

A job with a `stop` file (`vibe queue stop <id>`) needs no answer: `research_row` treats it as `stopped`.

The ETA shows only for a live run; an ended run keeps its steps from `run/log`.
