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

M1–M5 of `SPEC.md` are done. Routes in `bin/vibe-web`: `pause`, `resume`, `unlimit`, `conf`, `restart`, `triage`, `sync`, `servers`, `server-restart`, `update-toolkit`; per job `now`, `noreview`, `cancel`, `stop`, `retry`, `hold`, `archive`, `answer`, `fix`, `gpu-cancel`; `merge-order`, `feature-ready`, `feature-archive`; per repo `new`, `roadmap`, `roadmap-new`, `opt-in`, `worktrees`, `worktree-remove`; per recurring job `run`, `reset`; `GET job/<id>/<file>`. Table: `docs/vibe-queue.md` step 3.

## Next action

M6 of `SPEC.md`: the end action.
Done when `test ! -f SPEC.md`, `docs/vibe-queue.md` has a `## Page actions` table (row → route → command), the `PROJECT_STATUS.md` line "the queue has a read-only phone page" names the write endpoint, and shellcheck, shfmt and `bats tests/` pass.
Move each `SPEC.md` decision to `pr.md`; delete `HANDOFF.md`.

## Blockers

None.

## Gotchas (unpromoted)

- A new route: one line in `ROUTES` (`bin/vibe-web`); a body arg is a `"{name}"` slot at an arg's end (`claude-rc@{server}`) plus a pattern in `ARGS`. Absent or bad → 400. `TOOLS` maps argv[0] to an argv prefix (`cleanup.sh` runs with `bash`: no exec bit).
- vibe-web gives its commands `VIBE_WEB=1`: `vibe update-toolkit` then skips the vibe-web restart; vibe-web re-execs itself after the reply.
- `tests/vibe-web.bats`: `web_start` restarts the server with the current env (pid in `web.pid`); `get PATH` is a read by the right login.
- A button: `<button data-act="<route>" [data-confirm] [data-ask="<arg> …" title="<question>|…"]>` inside a `<div class="jacts" data-<arg>="…">`. page.js sends every `data-*` of the nearest `.jacts` (`id`, `pr`, `repo`, `feature`, `job`) plus one prompt per asked arg.
- Job buttons: `job_buttons` in `bin/vibe`; repo header (`merge-order`) and feature card buttons: `status_card`; queue-wide: `page_buttons`; per repo: `new_work` (repos from `page_repos`).
- A `<details>` inside `#queue` needs a `.repo h2` and a `.job b` above it: page.js keys open state on them.
- The row list (2026-11-04) is not in the repo. Check M5 rows against the done-when only.
- The poll skips its swap while a `#queue` button is armed, and asks `whoami` again until it gets a login.
- `bin/vibe-web` kills a command after 120 s (`VIBE_WEB_TIMEOUT`; the tests use 3 s).
- The page CSP allows only `/queue/page.js` (`templates/queue-page.js`): no inline `<script>` or `onclick`. It acts only on buttons inside `#queue`.
- `tests/vibe-web.bats`: `act ROUTE BODY` posts a JSON body; `qjob ID STATUS` makes a job dir; `qnew` is the one queue dir; `VIBE_ROOT` is the test dir; stub `systemctl` logs to `$STUBS/systemctl.log`; stub `gh` logs to `$STUBS/gh.log` and prints `$STUBS/{state,checks,files}[-<pr number>]`, `$STUBS/prs`. Do not pass `-d` twice: curl joins them with `&`.
- `agent_exec` runs the agent in the background and keeps its pid in `<job>/agent-pid`: the runner TERMs it on a `stop` file.
- `git add -A` fails in a sandboxed job (`.bash_profile` placeholders): stage with `git add -u` or by path.
