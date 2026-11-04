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

M1 of `SPEC.md` is done: `bin/vibe-web` (routes `pause`, `resume`), `vibe queue page`, `actions.log` on the Config tab, `vibe-web.service`, page buttons after `whoami`, `data-confirm` second tap.

## Next action

M2 of `SPEC.md`: queue control and job cards (rows 2–9, 11, 12, 14).
Done when bats tests pass for `vibe queue conf` (refuses an unknown key and a bad value), `unlimit`, `set <id> now=1|after=` (queued jobs only), `retry`, `cancel` (queued only), `stop` (runner ends it `failed`, no requeue), and one route test per row (3: stub `systemctl` gets `restart vibe-queue`).

## Blockers

None.

## Gotchas (unpromoted)

- A new route: add one line to `ROUTES` in `bin/vibe-web`; a button is `<button data-act="<route>" [data-confirm] [data-args='{…}']>`. The route gets no body args yet: M2 adds them (`<id>`), check each against a fixed pattern.
- `.acts` is swapped by innerHTML compare against the live DOM: an armed confirm button there un-arms on the next poll. Job-card buttons (M2) sit in the jobs part, which compares against the last fetch.
- The page CSP allows only `/queue/page.js` (`templates/queue-page.js`): no inline `<script>` or `onclick`; use `data-*` attributes and the delegated click handler.
- `tests/vibe-web.bats` starts the server per test on a free port; curl sends both headers when a test repeats `-H Origin`, and the server treats a repeated header as absent.
