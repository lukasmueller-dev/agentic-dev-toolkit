# Handoff — agentic-dev-toolkit / queue-page-actions

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `queue-page-actions`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/queue-page-actions
- **Last updated:** 2026-11-04 · turing

## State

M1 and M2 of `SPEC.md` are done. Routes in `bin/vibe-web`: `pause`, `resume`, `unlimit`, `conf`, `restart`; per job `now`, `noreview`, `cancel`, `stop`, `retry`, `hold`, `archive`. Table: `docs/vibe-queue.md` step 3.

## Next action

M3 of `SPEC.md`: review and feature actions (rows 10, 18, 20, 21, 22).
Done when bats tests with a stub `gh` pass for `vibe queue answer` (answer in `HANDOFF.md`, commit, push, follow-up queued, original archived; lane side job → `-retry` branch rules), `vibe queue fix` (refuses a queued or running branch), `vibe queue ready` (refuses a failing check, and `SPEC.md` or `HANDOFF.md` in the diff), `vibe queue merge-order <repo>`, and the feature archive route (refuses an open member PR).

## Blockers

None.

## Gotchas (unpromoted)

- A new route: one line in `ROUTES` (`bin/vibe-web`); a body arg is a `"{name}"` slot plus a pattern in `ARGS`. Absent or bad → 400.
- A button: `<button data-act="<route>" [data-confirm] [data-ask="<arg>" title="<question>"]>`. Job buttons sit in `<div class="jacts" data-id="<id>">` (`job_buttons` in `bin/vibe`); page.js sends the nearest `data-id` as `id`.
- The row list (2026-11-04) is not in the repo. M2 rows were mapped by the done-when; check M3 rows against the done-when only.
- `.acts` is swapped by innerHTML compare against the live DOM: an armed confirm button there un-arms on the next poll. Job buttons sit in the jobs part, which compares against the last fetch.
- The page CSP allows only `/queue/page.js` (`templates/queue-page.js`): no inline `<script>` or `onclick`. It acts only on buttons inside `#queue`.
- `tests/vibe-web.bats`: `act ROUTE BODY` posts a JSON body; `qjob ID STATUS` makes a job dir; a stub `systemctl` logs to `$STUBS/systemctl.log`. Do not pass `-d` twice: curl joins them with `&`.
- `agent_exec` runs the agent in the background and keeps its pid in `<job>/agent-pid`: the runner TERMs it on a `stop` file.
