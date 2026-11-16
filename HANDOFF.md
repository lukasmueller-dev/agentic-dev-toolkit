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

Milestones 1 (Shell) and 2 (Panel and Config) are done and ticked in `SPEC.md`.

- A row links to `#job-<key>`; `page_row` prints the row, then `blk<TAB><block>`; `queue_web` puts the blocks in `#panel > .pblocks`.
- Fields (`ask` in `bin/vibe`) replace every `prompt()`; New job is the block `#new`; Config is `config_page`.

## Next action

Milestone 3, Workspaces and tools: `vibe ws start --place --hours`, routes `ws-start`, `ws-stop`, `steer`, `tool.log` served, tool panel, Workspaces page and rail, GPU holder, outside GPU rows. Done when `bats tests/vibe-ws.bats tests/vibe-web.bats tests/vibe-queue.bats` passes with tests for each new route, flag and holder case.

- The tool panel goes in the job's block: `status_card` job, or a `pre` part in `page_row` as the lane Fix field does.

## Blockers

None.

## Gotchas (unpromoted)

- The boards are `.dc.html` design files: they load `./support.js` and Google Fonts, so they do not render alone. Read them for layout, sizes and colors.
- Screenshot → serve a dir with a `queue` copy of `web/` (`python3 -m http.server`), same Bash call. The headless shell: `~/.cache/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-linux64/chrome-headless-shell`.
- Clicks and keys → drive that shell with `--remote-debugging-pipe` from Python (no WebSocket library here); keep fds 3 and 4 in `pass_fds`.
- In a fetched page, page.js finds a node only by a path from `body` (`body > main > #queue`): a `.md` can hold any class.
- A phase span has class `x`: the panel's Close button is `.close`.
