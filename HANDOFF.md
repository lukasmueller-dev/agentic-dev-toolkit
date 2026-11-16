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

Milestones 1 (Shell), 2 (Panel and Config) and 3 (Workspaces and tools) are done and ticked in `SPEC.md`.

- A row links to `#job-<key>`; `page_row` prints the row, then `blk<TAB><block>`; `queue_web` puts the blocks in `#panel > .pblocks`.
- Fields (`ask` in `bin/vibe`) replace every `prompt()`; New job is the block `#new`; Config is `config_page`.
- Workspaces page `#workspaces` and rail `.wsl`: `ws_page`. GPU holder: `gpu_holder`, shown only while the lock is held.
- `vibe ws start --place --hours`; under `VIBE_WEB` it detaches as `ws hold`; new state `starts`.
- Routes `ws-start`, `ws-stop`, `steer`; `GET job/<id>/tool.log`, `out/report.md`, `out/files` (a file list).

## Next action

Milestone 4, Docs: `docs/vibe-queue.md` (Phone page → Page, Page actions table) and `docs/workspaces.md` match the code. Done when `grep -c "Sessions ↗\|chips" docs/vibe-queue.md` prints 0 and the full lint, format and bats gate of `CLAUDE.md` passes.

- `docs/workspaces.md` still says "The queue page lists the lines of `status` under `Tools`": the Workspaces page replaces it.
- Its Commands block needs `--place P --hours N`, the `starts` state, and the detached page start.
- `docs/vibe-queue.md` line 70 names `Tools` and repo groups; Page actions needs `ws-start`, `ws-stop`, `steer` and the served files.
- `docs/workspaces/place-vast.md` and `place-runpod.md` show `vibe ws start <name>`: add `--place`.

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
