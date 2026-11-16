# Handoff — agentic-dev-toolkit / queue-redesign

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `queue-redesign`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/queue-redesign
- **Last updated:** 2026-11-16 · turing

## State

Milestones 1 (Shell), 2 (Panel and Config), 3 (Workspaces and tools) and 4 (Docs) are done and ticked in `SPEC.md`.

- Page docs: `docs/vibe-queue.md` sections 3. Page, Tool jobs (page line) and Page actions; `docs/workspaces.md` Commands and State.
- The place recipes start with `--place`; `templates/README.md` lists `<wsrail>` and `<workspaces>`.

## Next action

Milestone 5, End action: `git rm` `SPEC.md`, `HANDOFF.md` and `design/queue-a/`. Done when those three are gone from the branch.

- Move each `SPEC.md` decision into `pr.md` (`<details>`), one line each.
- Promote the gotchas below that still hold to `CLAUDE.md`; add a one-line decision to `PROJECT_STATUS.md` with a PR pointer.

## Blockers

None.

## Gotchas (unpromoted)

- The boards are `.dc.html` design files: they load `./support.js` and Google Fonts, so they do not render alone. Read them for layout, sizes and colors.
- Screenshot → serve a dir with a `queue` copy of `web/` (`python3 -m http.server`), same Bash call. The headless shell: `~/.cache/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-linux64/chrome-headless-shell`.
- Clicks and keys → `tests/page_check.py` drives page.js over `--remote-debugging-pipe`. Full Chrome does not start in the agent sandbox (the test skips): set `VIBE_TEST_BROWSER` to the headless shell.
- In a fetched page, page.js finds a node only by a path from `body` (`body > main > #queue`): a `.md` can hold any class.
- A phase span has class `x`: the panel's Close button is `.close`.
- A block is one line (`page_row` drops newlines): a `<pre>` in it needs `&#10;` (see the `tool.log` tail).
- `bats` hangs on a bare `wait` in `tests/vibe-web.bats`: setup's vibe-web is a background job too. Wait on a pid.
- `vibe-ws.bats` "a gpu=yes start that fails after the wait for the lock" fails under `-j 8` load: the lock takes over 3 s, so `start` prints `waits for the GPU`. Run that file alone.
