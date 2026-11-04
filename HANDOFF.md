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

M1–M3 of `SPEC.md` are done. Routes in `bin/vibe-web`: `pause`, `resume`, `unlimit`, `conf`, `restart`; per job `now`, `noreview`, `cancel`, `stop`, `retry`, `hold`, `archive`, `answer`, `fix`; `merge-order`, `feature-ready`, `feature-archive`. Table: `docs/vibe-queue.md` step 3.

## Next action

M4 of `SPEC.md`: new work and recurring jobs (rows 24–29, 31).
Done when bats tests pass for `vibe queue new` (no `<…>` slot left in `prompt.md`; refuses no done-when and a queued branch), the roadmap route (items of a fixture repo's `origin`, with their line), `vibe job reset <repo> <job>` (removes `fails`), the run, triage and opt-in routes; and `grep -q 'claude.ai/code' templates/queue-page.html`.

## Blockers

None.

## Gotchas (unpromoted)

- A new route: one line in `ROUTES` (`bin/vibe-web`); a body arg is a `"{name}"` slot plus a pattern in `ARGS`. Absent or bad → 400.
- A button: `<button data-act="<route>" [data-confirm] [data-ask="<arg>" title="<question>"]>` inside a `<div class="jacts" data-<arg>="…">`. page.js sends every `data-*` of the nearest `.jacts` (`id`, `pr`, `repo`, `feature`) plus the asked arg.
- Job buttons: `job_buttons` in `bin/vibe`; repo header (`merge-order`) and feature card buttons: `status_card`.
- `branch_idle JOB` dies while a job on the branch is queued or running; `follow_dir JOB` copies `job` and `prompt.md`; `task_append PROMPT LINE…` ends the `## Task` section. Reuse them for `vibe queue new`.
- The row list (2026-11-04) is not in the repo. Check M4 rows against the done-when only.
- The poll skips its swap while a `#queue` button is armed, and asks `whoami` again until it gets a login.
- `bin/vibe-web` kills a command after 120 s (`VIBE_WEB_TIMEOUT`; the tests use 3 s).
- The page CSP allows only `/queue/page.js` (`templates/queue-page.js`): no inline `<script>` or `onclick`. It acts only on buttons inside `#queue`.
- `tests/vibe-web.bats`: `act ROUTE BODY` posts a JSON body; `qjob ID STATUS` makes a job dir; stub `systemctl` logs to `$STUBS/systemctl.log`; stub `gh` logs to `$STUBS/gh.log` and prints `$STUBS/{state,checks,files}[-<pr number>]`, `$STUBS/prs`. Do not pass `-d` twice: curl joins them with `&`.
- `agent_exec` runs the agent in the background and keeps its pid in `<job>/agent-pid`: the runner TERMs it on a `stop` file.
